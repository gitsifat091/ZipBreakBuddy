import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/ui/drive_away_view.dart';

void main() {
  testWidgets('draws at every stage of the drive without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 140);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final progress = ValueNotifier<double>(0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: DriveAwayView(progress: _Notifier(progress)),
        ),
      ),
    );

    for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      progress.value = t;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at progress $t');
    }
  });
}

/// Adapts a [ValueNotifier] to the [Animation] the view expects.
class _Notifier extends Animation<double> {
  _Notifier(this._source);

  final ValueNotifier<double> _source;

  @override
  double get value => _source.value;

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}

  @override
  AnimationStatus get status => AnimationStatus.forward;
}
