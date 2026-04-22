class EditPlanClip {
  final int index;
  final String sourcePath;
  final int startMs;
  final int durationMs;
  final String userTag;

  const EditPlanClip({
    required this.index,
    required this.sourcePath,
    required this.startMs,
    required this.durationMs,
    required this.userTag,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'sourcePath': sourcePath,
        'startMs': startMs,
        'durationMs': durationMs,
        'userTag': userTag,
      };
}

class EditPlan {
  final List<EditPlanClip> clips;

  const EditPlan(this.clips);

  int get totalDurationMs =>
      clips.fold(0, (int sum, EditPlanClip c) => sum + c.durationMs);
}
