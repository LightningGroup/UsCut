import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../models/clip_ref.dart';

/// Stage 2 frozen interface.
///
/// Owns the [CameraController] lifecycle and converts recorded video
/// file paths + durations into [ClipRef] values consumed by the Stage 1
/// render pipeline. Stage 5 will depend on this contract as the clip
/// input source for collaborative sessions.
class CaptureService {
  CameraController? _controller;
  bool _isRecording = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _isRecording;

  Future<void> initialize(CameraDescription camera) async {
    await _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
  }

  /// Records a timed video clip and returns a [ClipRef].
  ///
  /// This is the frozen contract between Stage 2 capture and the Stage 1
  /// render pipeline. [userTag] must be 'A' or 'B'. [durationMs] must be
  /// one of 500, 1000, or 2000.
  Future<ClipRef> captureClip({
    required String userTag,
    required int durationMs,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw StateError('CaptureService not initialized');
    }
    if (_isRecording) throw StateError('Already recording');

    _isRecording = true;
    try {
      await _controller!.startVideoRecording();
      await Future<void>.delayed(Duration(milliseconds: durationMs));
      final xFile = await _controller!.stopVideoRecording();
      return ClipRef(
        sourcePath: xFile.path,
        userTag: userTag,
        durationMs: durationMs,
      );
    } finally {
      _isRecording = false;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isRecording = false;
  }
}
