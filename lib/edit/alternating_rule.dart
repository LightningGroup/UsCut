import '../models/clip_ref.dart';
import '../models/edit_plan.dart';

EditPlan buildAlternatingPlan({
  required List<ClipRef> clipsA,
  required List<ClipRef> clipsB,
  int defaultClipDurationMs = 1000,
}) {
  final List<EditPlanClip> result = <EditPlanClip>[];
  final int minLen =
      clipsA.length < clipsB.length ? clipsA.length : clipsB.length;

  int index = 0;
  for (int k = 0; k < minLen; k++) {
    final int durA = _pickDuration(defaultClipDurationMs, clipsA[k].durationMs);
    final int durB = _pickDuration(defaultClipDurationMs, clipsB[k].durationMs);
    if (durA <= 0 || durB <= 0) continue;

    result.add(
      EditPlanClip(
        index: index++,
        sourcePath: clipsA[k].sourcePath,
        startMs: 0,
        durationMs: durA,
        userTag: 'A',
      ),
    );
    result.add(
      EditPlanClip(
        index: index++,
        sourcePath: clipsB[k].sourcePath,
        startMs: 0,
        durationMs: durB,
        userTag: 'B',
      ),
    );
  }

  return EditPlan(result);
}

int _pickDuration(int defaultMs, int sourceMs) {
  if (sourceMs <= 0) return 0;
  return defaultMs < sourceMs ? defaultMs : sourceMs;
}
