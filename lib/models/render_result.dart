class RenderResult {
  final String requestId;
  final String outputPath;
  final int durationMs;
  final int width;
  final int height;
  final int fileSizeBytes;

  const RenderResult({
    required this.requestId,
    required this.outputPath,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
  });

  factory RenderResult.fromMap(Map<String, dynamic> map) => RenderResult(
        requestId: map['requestId'] as String,
        outputPath: map['outputPath'] as String,
        durationMs: (map['durationMs'] as num).toInt(),
        width: (map['width'] as num).toInt(),
        height: (map['height'] as num).toInt(),
        fileSizeBytes: (map['fileSizeBytes'] as num).toInt(),
      );
}

class RenderException implements Exception {
  final String code;
  final String message;
  final Object? details;

  const RenderException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'RenderException($code): $message';
}
