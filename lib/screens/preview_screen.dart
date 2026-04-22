import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/edit_plan.dart';
import '../models/render_result.dart';
import '../services/render_service.dart';

class PreviewScreen extends StatefulWidget {
  final EditPlan plan;
  const PreviewScreen({super.key, required this.plan});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final RenderService _service = RenderService();

  Future<RenderResult>? _renderFuture;
  VideoPlayerController? _controller;
  int _renderGeneration = 0;
  bool _saving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _startRender();
  }

  void _startRender() {
    _renderGeneration += 1;
    setState(() {
      _saveMessage = null;
      _renderFuture = _runRender(_renderGeneration);
    });
  }

  Future<RenderResult> _runRender(int generation) async {
    final Directory tmp = await getTemporaryDirectory();
    final RenderResult result = await _service.renderAlternating(
      plan: widget.plan,
      outputDir: tmp.path,
    );

    final VideoPlayerController next =
        VideoPlayerController.file(File(result.outputPath));
    await next.initialize();
    await next.setLooping(true);

    // Concurrent retry guard: if a newer render started while we were
    // awaiting the native channel, discard this result.
    if (generation != _renderGeneration || !mounted) {
      await next.dispose();
      throw const _StaleRenderSignal();
    }

    _controller?.dispose();
    _controller = next;
    await next.play();
    return result;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onSave(RenderResult result) async {
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    try {
      final bool access = await Gal.hasAccess();
      if (!access) {
        final bool granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Photo library access denied.');
        }
      }
      await Gal.putVideo(result.outputPath, album: 'UsCut');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Saved to Photos → "UsCut" album.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveMessage = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: FutureBuilder<RenderResult>(
        future: _renderFuture,
        builder: (BuildContext context, AsyncSnapshot<RenderResult> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Rendering...'),
                ],
              ),
            );
          }
          if (snap.hasError) {
            if (snap.error is _StaleRenderSignal) {
              // Superseded by a newer render; UI will refresh via the new Future.
              return const Center(child: CircularProgressIndicator());
            }
            return _ErrorView(
              error: snap.error!,
              onRetry: _startRender,
            );
          }
          final RenderResult result = snap.data!;
          return _PreviewBody(
            controller: _controller,
            result: result,
            saving: _saving,
            saveMessage: _saveMessage,
            onSave: () => _onSave(result),
          );
        },
      ),
    );
  }
}

class _StaleRenderSignal implements Exception {
  const _StaleRenderSignal();
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  final VideoPlayerController? controller;
  final RenderResult result;
  final bool saving;
  final String? saveMessage;
  final VoidCallback onSave;

  const _PreviewBody({
    required this.controller,
    required this.result,
    required this.saving,
    required this.saveMessage,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = controller;
    return Column(
      children: <Widget>[
        Expanded(
          child: Center(
            child: c == null || !c.value.isInitialized
                ? const CircularProgressIndicator()
                : AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: GestureDetector(
                      onTap: () {
                        c.value.isPlaying ? c.pause() : c.play();
                      },
                      child: VideoPlayer(c),
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${result.width}×${result.height} · '
                '${(result.durationMs / 1000).toStringAsFixed(1)}s · '
                '${(result.fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_alt),
                  label: const Text('Save to Photos'),
                  onPressed: saving ? null : onSave,
                ),
              ),
              if (saveMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  saveMessage!,
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
