import 'dart:async';

import 'package:android_video_player_mvp/ui/features/player/views/player_seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wide touch area previews locally and seeks once on release', (
    tester,
  ) async {
    final seeks = <Duration>[];
    final pending = Completer<void>();
    var parentBuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              parentBuilds++;
              return PlayerSeekBar(
                position: const Duration(seconds: 10),
                duration: const Duration(seconds: 100),
                enabled: true,
                onSeek: (position) {
                  seeks.add(position);
                  return pending.future;
                },
              );
            },
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(Slider));
    // Begin well above the visible track, then move across its full width.
    final pointer = await tester.startGesture(
      Offset(rect.left + rect.width * 0.25, rect.top + 5),
    );
    for (var step = 0; step < 5; step++) {
      await pointer.moveBy(const Offset(60, 0));
      await tester.pump();
    }
    expect(seeks, isEmpty);
    expect(parentBuilds, 1);
    final preview = tester.widget<Slider>(find.byType(Slider)).value;
    expect(preview, greaterThan(50000));
    await pointer.up();
    await tester.pump();
    expect(seeks, hasLength(1));
    expect(seeks.single.inMilliseconds, preview.round());
    // Keep the destination visible while the seek command is in progress.
    expect(tester.widget<Slider>(find.byType(Slider)).value, preview);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tap near the bottom of the seek area works; disabled cannot seek',
    (tester) async {
      final seeks = <Duration>[];
      Future<void> build(bool enabled) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerSeekBar(
              position: Duration.zero,
              duration: const Duration(seconds: 100),
              enabled: enabled,
              onSeek: (position) async => seeks.add(position),
            ),
          ),
        ),
      );
      await build(true);
      final rect = tester.getRect(find.byType(Slider));
      final target = Offset(rect.center.dx, rect.bottom - 5);
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(seeks.single.inSeconds, closeTo(50, 1));
      await build(false);
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(seeks, hasLength(1));
    },
  );
}
