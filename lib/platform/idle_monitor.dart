import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Reads keyboard/mouse inactivity via Win32 `GetLastInputInfo`.
class IdleMonitor {
  final Pointer<LASTINPUTINFO> _info = calloc<LASTINPUTINFO>()
    ..ref.cbSize = sizeOf<LASTINPUTINFO>();

  /// Time since the last keyboard or mouse input, system-wide.
  Duration idleTime() {
    if (GetLastInputInfo(_info) == 0) return Duration.zero;
    // Both values are 32-bit tick counts; mask so wraparound (every
    // ~49.7 days) still gives the right difference.
    final ms = (GetTickCount() - _info.ref.dwTime) & 0xFFFFFFFF;
    return Duration(milliseconds: ms);
  }

  void dispose() => calloc.free(_info);
}
