import 'dart:async';
import 'dart:ffi';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Window argument that tells `main()` to run the drive-away overlay.
const driveAwayWindowArgument = 'drive_away';

/// Height of the overlay, in logical pixels (96 dpi).
const driveAwayWindowHeight = 140.0;

const _windowClass = 'FLUTTER_MULTI_WINDOW_WIN32_WINDOW';
const _readyTimeout = Duration(seconds: 8);
const _playTimeout = Duration(seconds: 8);

/// The wide, transparent strip Zip drives across after Done. It is a second
/// native window with its own Flutter engine (desktop_multi_window), styled
/// through Win32 so it is frameless, always on top, click-through, never
/// takes focus and has no taskbar button or Alt+Tab entry.
///
/// The engine is only alive between [prepare] and [release]/[play]: it is
/// started while a pop-up is on screen so Done can drive off immediately.
class DriveAwayWindow {
  Future<WindowController?>? _starting;

  /// Starts the overlay in the background (hidden). Safe to call repeatedly.
  void prepare() => _starting ??= _start();

  /// Closes a prepared overlay that is not going to be used.
  Future<void> release() async {
    final starting = _starting;
    if (starting == null) return;
    _starting = null;
    if (await starting != null) _close();
  }

  /// Shows the overlay, runs the animation and closes it. Completes with
  /// false when the overlay could not run, so the caller can fall back.
  ///
  /// [beforeShow] runs once the overlay is ready, just before it appears.
  Future<bool> play({Future<void> Function()? beforeShow}) async {
    prepare();
    final starting = _starting!;
    _starting = null;
    final controller = await starting;
    if (controller == null) return false;
    try {
      final hwnd = _findWindow();
      if (hwnd == 0) return false;
      await beforeShow?.call();
      _showAtBottom(hwnd);
      await controller.invokeMethod<void>('drive').timeout(_playTimeout);
      return true;
    } catch (e) {
      debugPrint('[Zip] drive-away failed: $e');
      return false;
    } finally {
      _close();
    }
  }

  Future<WindowController?> _start() async {
    try {
      final controller = await WindowController.create(
        const WindowConfiguration(
          arguments: driveAwayWindowArgument,
          hiddenAtLaunch: true,
        ),
      );
      final hwnd = _findWindow();
      if (hwnd == 0) throw StateError('overlay window not found');
      _applyOverlayStyle(hwnd);
      await _waitUntilReady(controller);
      return controller;
    } catch (e) {
      debugPrint('[Zip] could not start the drive-away window: $e');
      _close();
      return null;
    }
  }

  /// The overlay's Dart side registers its handler a moment after the
  /// engine boots; poll until it answers.
  Future<void> _waitUntilReady(WindowController controller) async {
    final deadline = DateTime.now().add(_readyTimeout);
    while (true) {
      try {
        await controller.invokeMethod<void>('ping');
        return;
      } catch (_) {
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  int _findWindow() {
    final name = _windowClass.toNativeUtf16();
    try {
      return FindWindow(name, nullptr);
    } finally {
      calloc.free(name);
    }
  }

  void _close() {
    final hwnd = _findWindow();
    if (hwnd != 0) PostMessage(hwnd, WM_CLOSE, 0, 0);
  }

  /// Frameless tool window: topmost, transparent, click-through, no focus.
  void _applyOverlayStyle(int hwnd) {
    SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP);
    SetWindowLongPtr(
      hwnd,
      GWL_EXSTYLE,
      WS_EX_LAYERED |
          WS_EX_TRANSPARENT |
          WS_EX_NOACTIVATE |
          WS_EX_TOOLWINDOW |
          WS_EX_TOPMOST,
    );
    SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
    _makeBackgroundTransparent(hwnd);
  }

  /// Positions the strip along the bottom of the work area (above the
  /// taskbar) and shows it without activating it.
  void _showAtBottom(int hwnd) {
    final rect = calloc<RECT>();
    try {
      SystemParametersInfo(SPI_GETWORKAREA, 0, rect, 0);
      final height = (driveAwayWindowHeight * GetDpiForWindow(hwnd) / 96)
          .round();
      final x = rect.ref.left;
      final y = rect.ref.bottom - height;
      final width = rect.ref.right - rect.ref.left;
      const flags = SWP_NOACTIVATE | SWP_FRAMECHANGED;
      SetWindowPos(hwnd, HWND_TOPMOST, x, y, width, height, flags);
      ShowWindow(hwnd, SW_SHOWNOACTIVATE);
      // A window resized while hidden keeps a stale render surface; a 1px
      // nudge after showing makes Flutter rebuild it (same trick as the
      // pop-up).
      SetWindowPos(hwnd, HWND_TOPMOST, x, y, width + 1, height, flags);
      SetWindowPos(hwnd, HWND_TOPMOST, x, y, width, height, flags);
    } finally {
      calloc.free(rect);
    }
  }
}

final class _AccentPolicy extends Struct {
  @Int32()
  external int accentState;
  @Int32()
  external int flags;
  @Int32()
  external int color;
  @Int32()
  external int animationId;
}

final class _CompositionAttributeData extends Struct {
  @Int32()
  external int attribute;
  external Pointer<Void> data;
  @Uint32()
  external int size;
}

typedef _SetCompositionAttributeNative =
    Int32 Function(IntPtr, Pointer<_CompositionAttributeData>);
typedef _SetCompositionAttribute =
    int Function(int, Pointer<_CompositionAttributeData>);

/// The same undocumented call window_manager uses to make the pop-up window
/// transparent: ACCENT_ENABLE_TRANSPARENTGRADIENT with no tint.
void _makeBackgroundTransparent(int hwnd) {
  const wcaAccentPolicy = 19;
  const accentEnableTransparentGradient = 2;
  final policy = calloc<_AccentPolicy>();
  final data = calloc<_CompositionAttributeData>();
  try {
    final setAttribute = DynamicLibrary.open('user32.dll')
        .lookupFunction<
          _SetCompositionAttributeNative,
          _SetCompositionAttribute
        >('SetWindowCompositionAttribute');
    policy.ref
      ..accentState = accentEnableTransparentGradient
      ..flags = 2
      ..color = 0
      ..animationId = 0;
    data.ref
      ..attribute = wcaAccentPolicy
      ..data = policy.cast()
      ..size = sizeOf<_AccentPolicy>();
    setAttribute(hwnd, data);
  } finally {
    calloc.free(policy);
    calloc.free(data);
  }
}
