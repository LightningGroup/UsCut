import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../edit/alternating_rule.dart';
import '../models/clip_ref.dart';
import '../services/capture_service.dart';
import 'preview_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  static const int _perSide = 3;
  static const List<int> _durationOptions = [500, 1000, 2000];
  // Pass max possible capture duration so alternating_rule never clamps clips.
  static const int _maxDurationMs = 2000;

  final CaptureService _capture = CaptureService();
  final List<ClipRef> _clipsA = <ClipRef>[];
  final List<ClipRef> _clipsB = <ClipRef>[];

  int _selectedDurationMs = 1000;
  bool _initializing = true;
  String? _error;
  bool _recording = false;
  double _recordProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capture.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _capture.dispose();
    } else if (state == AppLifecycleState.resumed &&
        !_capture.isInitialized) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera found.');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _capture.initialize(back);
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = e.toString();
        });
      }
    }
  }

  String get _activeTag => _clipsA.length < _perSide ? 'A' : 'B';
  bool get _canContinue =>
      _clipsA.length == _perSide && _clipsB.length == _perSide;
  bool get _canRecord =>
      !_recording && !_canContinue && _capture.isInitialized;

  Future<void> _record() async {
    if (!_canRecord) return;
    setState(() {
      _recording = true;
      _recordProgress = 0;
    });

    try {
      final clipFuture = _capture.captureClip(
        userTag: _activeTag,
        durationMs: _selectedDurationMs,
      );

      // Animate progress bar in parallel with the recording timer.
      const int stepMs = 50;
      final int steps = _selectedDurationMs ~/ stepMs;
      for (var i = 1; i <= steps; i++) {
        await Future<void>.delayed(const Duration(milliseconds: stepMs));
        if (!mounted) return;
        setState(() => _recordProgress = i / steps);
      }

      final clip = await clipFuture;
      if (!mounted) return;
      setState(() {
        if (clip.userTag == 'A') {
          _clipsA.add(clip);
        } else {
          _clipsB.add(clip);
        }
        _recording = false;
        _recordProgress = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e')),
      );
    }
  }

  void _undo() {
    setState(() {
      if (_clipsB.isNotEmpty) {
        _clipsB.removeLast();
      } else if (_clipsA.isNotEmpty) {
        _clipsA.removeLast();
      }
    });
  }

  void _onContinue() {
    if (!_canContinue) return;
    final plan = buildAlternatingPlan(
      clipsA: _clipsA,
      clipsB: _clipsB,
      defaultClipDurationMs: _maxDurationMs,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PreviewScreen(plan: plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_headerTitle()),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: _buildControls(),
      ),
    );
  }

  String _headerTitle() {
    if (_canContinue) return 'Ready (3/3 · 3/3)';
    final tag = _activeTag;
    final count = tag == 'A' ? _clipsA.length : _clipsB.length;
    return 'Shooting $tag ($count/$_perSide)';
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _initCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _capture.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Aspect-fill camera preview: swap width/height because previewSize
        // is reported in landscape orientation on iOS.
        OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 1,
              height: controller.value.previewSize?.width ?? 1,
              child: CameraPreview(controller),
            ),
          ),
        ),
        // Clip dot indicators overlaid bottom-left.
        Positioned(
          left: 16,
          bottom: 16,
          child: _ClipDots(
            clipsA: _clipsA.length,
            clipsB: _clipsB.length,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Duration selector chips.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _durationOptions.map((ms) {
                final label = ms < 1000 ? '${ms}ms' : '${ms ~/ 1000}s';
                final selected = ms == _selectedDurationMs;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: _recording
                        ? null
                        : (_) =>
                            setState(() => _selectedDurationMs = ms),
                    selectedColor: Colors.indigo,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                    ),
                    backgroundColor: Colors.white12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Undo · Record · Continue row.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white70),
                  iconSize: 28,
                  onPressed:
                      (_recording || (_clipsA.isEmpty && _clipsB.isEmpty))
                          ? null
                          : _undo,
                  tooltip: 'Undo last clip',
                ),
                GestureDetector(
                  onTap: _canRecord ? _record : null,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        CircularProgressIndicator(
                          value: _recording ? _recordProgress : 0,
                          strokeWidth: 4,
                          color: _activeTagColor,
                          backgroundColor: Colors.white24,
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _canRecord
                                ? _activeTagColor
                                : Colors.white24,
                          ),
                          child: _recording
                              ? null
                              : const Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.white,
                                  size: 32,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: _canContinue ? _onContinue : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _activeTagColor =>
      _activeTag == 'A' ? Colors.indigo : Colors.deepOrange;
}

class _ClipDots extends StatelessWidget {
  final int clipsA;
  final int clipsB;

  const _ClipDots({required this.clipsA, required this.clipsB});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _DotRow(tag: 'A', count: clipsA, color: Colors.indigo),
        const SizedBox(height: 4),
        _DotRow(tag: 'B', count: clipsB, color: Colors.deepOrange),
      ],
    );
  }
}

class _DotRow extends StatelessWidget {
  final String tag;
  final int count;
  final Color color;

  const _DotRow({
    required this.tag,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$tag: ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: <Shadow>[Shadow(blurRadius: 4)],
          ),
        ),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < count ? color : Colors.white30,
                boxShadow: const <BoxShadow>[
                  BoxShadow(blurRadius: 2, color: Colors.black54),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
