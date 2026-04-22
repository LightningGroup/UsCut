import 'package:flutter_test/flutter_test.dart';
import 'package:uscut/edit/alternating_rule.dart';
import 'package:uscut/models/clip_ref.dart';

ClipRef _ref(String path, int durationMs) =>
    ClipRef(sourcePath: path, userTag: 'X', durationMs: durationMs);

void main() {
  group('buildAlternatingPlan', () {
    test('3 + 3 yields 6 interleaved clips in A,B,A,B,A,B order', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 5000), _ref('a2', 5000), _ref('a3', 5000)],
        clipsB: [_ref('b1', 5000), _ref('b2', 5000), _ref('b3', 5000)],
      );
      expect(plan.clips.length, 6);
      expect(
        plan.clips.map((c) => c.sourcePath).toList(),
        <String>['a1', 'b1', 'a2', 'b2', 'a3', 'b3'],
      );
      expect(
        plan.clips.map((c) => c.userTag).toList(),
        <String>['A', 'B', 'A', 'B', 'A', 'B'],
      );
      expect(plan.clips.map((c) => c.index).toList(), <int>[0, 1, 2, 3, 4, 5]);
      expect(plan.totalDurationMs, 6000);
    });

    test('mismatched lengths truncate to the shorter side', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 5000), _ref('a2', 5000)],
        clipsB: [
          _ref('b1', 5000),
          _ref('b2', 5000),
          _ref('b3', 5000),
        ],
      );
      expect(plan.clips.length, 4);
      expect(
        plan.clips.map((c) => c.sourcePath).toList(),
        <String>['a1', 'b1', 'a2', 'b2'],
      );
    });

    test('empty A yields empty plan', () {
      final plan = buildAlternatingPlan(
        clipsA: const [],
        clipsB: [_ref('b1', 5000)],
      );
      expect(plan.clips, isEmpty);
      expect(plan.totalDurationMs, 0);
    });

    test('clamps durationMs when source is shorter than default', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 500)],
        clipsB: [_ref('b1', 1500)],
      );
      expect(plan.clips.length, 2);
      expect(plan.clips[0].durationMs, 500);
      expect(plan.clips[1].durationMs, 1000);
    });

    test('honors custom defaultClipDurationMs', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 5000)],
        clipsB: [_ref('b1', 5000)],
        defaultClipDurationMs: 500,
      );
      expect(plan.clips[0].durationMs, 500);
      expect(plan.clips[1].durationMs, 500);
      expect(plan.totalDurationMs, 1000);
    });

    test('zero-duration source pair is skipped, not asserted', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 0)],
        clipsB: [_ref('b1', 5000)],
      );
      expect(plan.clips, isEmpty);
    });

    test('asymmetric durations clamp independently per clip', () {
      final plan = buildAlternatingPlan(
        clipsA: [_ref('a1', 800), _ref('a2', 5000), _ref('a3', 1100)],
        clipsB: [_ref('b1', 5000), _ref('b2', 400), _ref('b3', 5000)],
      );
      expect(plan.clips.length, 6);
      expect(
        plan.clips.map((c) => c.durationMs).toList(),
        <int>[800, 1000, 1000, 400, 1000, 1000],
      );
      expect(plan.totalDurationMs, 5200);
    });
  });
}
