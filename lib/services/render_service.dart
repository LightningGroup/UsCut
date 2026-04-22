import 'dart:io';

import 'package:flutter/services.dart';

import '../models/edit_plan.dart';
import '../models/render_result.dart';

class RenderService {
  static const MethodChannel _channel = MethodChannel('com.uscut/render');

  Future<RenderResult> renderAlternating({
    required EditPlan plan,
    required String outputDir,
    int frameRate = 30,
    int renderWidth = 1080,
    int renderHeight = 1920,
  }) async {
    if (plan.clips.isEmpty) {
      throw const RenderException(
        code: 'CLIP_COUNT_INVALID',
        message: 'EditPlan has zero clips.',
      );
    }

    await _cleanupOldOutputs(outputDir);

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> request = <String, dynamic>{
      'requestId': 'stage1-$nowMs',
      'outputDir': outputDir,
      'outputFilename': 'uscut_$nowMs.mp4',
      'renderSize': <String, int>{
        'width': renderWidth,
        'height': renderHeight,
      },
      'frameRate': frameRate,
      'clips': plan.clips.map((EditPlanClip c) => c.toJson()).toList(),
    };

    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        'renderAlternating',
        request,
      );
      if (raw == null) {
        throw const RenderException(
          code: 'UNKNOWN',
          message: 'Null response from native render.',
        );
      }
      return RenderResult.fromMap(raw.cast<String, dynamic>());
    } on PlatformException catch (e) {
      throw RenderException(
        code: e.code,
        message: e.message ?? '',
        details: e.details,
      );
    }
  }

  Future<void> _cleanupOldOutputs(String outputDir) async {
    final Directory dir = Directory(outputDir);
    if (!dir.existsSync()) return;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is File &&
          f.path.contains('uscut_') &&
          f.path.endsWith('.mp4')) {
        try {
          await f.delete();
        } catch (_) {
          // best-effort cleanup
        }
      }
    }
  }
}
