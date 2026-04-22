import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../edit/alternating_rule.dart';
import '../models/clip_ref.dart';
import '../models/edit_plan.dart';
import 'preview_screen.dart';

class ClipPickerScreen extends StatefulWidget {
  const ClipPickerScreen({super.key});

  @override
  State<ClipPickerScreen> createState() => _ClipPickerScreenState();
}

class _ClipPickerScreenState extends State<ClipPickerScreen> {
  static const int _perSide = 3;

  bool _loading = true;
  String? _error;
  List<AssetEntity> _videos = const <AssetEntity>[];
  final List<AssetEntity> _pickedA = <AssetEntity>[];
  final List<AssetEntity> _pickedB = <AssetEntity>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      setState(() {
        _loading = false;
        _error = 'Photo library permission is required.';
      });
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
    );
    if (albums.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No videos found on device.';
      });
      return;
    }

    final AssetPathEntity all = albums.first;
    final int count = await all.assetCountAsync;
    final List<AssetEntity> videos =
        await all.getAssetListRange(start: 0, end: count);
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _loading = false;
    });
  }

  bool _isPicked(AssetEntity asset) =>
      _pickedA.contains(asset) || _pickedB.contains(asset);

  String _tagOf(AssetEntity asset) {
    if (_pickedA.contains(asset)) return 'A${_pickedA.indexOf(asset) + 1}';
    if (_pickedB.contains(asset)) return 'B${_pickedB.indexOf(asset) + 1}';
    return '';
  }

  bool get _pickingA => _pickedA.length < _perSide;
  bool get _isComplete =>
      _pickedA.length == _perSide && _pickedB.length == _perSide;

  void _onTap(AssetEntity asset) {
    setState(() {
      if (_isPicked(asset)) {
        _pickedA.remove(asset);
        _pickedB.remove(asset);
        return;
      }
      if (_pickingA) {
        _pickedA.add(asset);
      } else if (_pickedB.length < _perSide) {
        _pickedB.add(asset);
      }
    });
  }

  Future<List<ClipRef>> _toRefs(List<AssetEntity> assets, String tag) async {
    final List<ClipRef> out = <ClipRef>[];
    for (final AssetEntity a in assets) {
      final file = await a.file;
      if (file == null) continue;
      out.add(ClipRef(
        sourcePath: file.path,
        userTag: tag,
        durationMs: a.duration * 1000,
      ));
    }
    return out;
  }

  Future<void> _onContinue() async {
    final List<ClipRef> aRefs = await _toRefs(_pickedA, 'A');
    final List<ClipRef> bRefs = await _toRefs(_pickedB, 'B');
    if (!mounted) return;

    if (aRefs.length < _perSide || bRefs.length < _perSide) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve file paths for all clips.'),
        ),
      );
      return;
    }

    final EditPlan plan = buildAlternatingPlan(
      clipsA: aRefs,
      clipsB: bRefs,
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
      appBar: AppBar(title: Text(_headerTitle())),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _isComplete ? _onContinue : null,
            child: Text(_ctaLabel()),
          ),
        ),
      ),
    );
  }

  String _headerTitle() {
    if (_isComplete) return 'Ready (3/3 · 3/3)';
    return _pickingA
        ? 'Picking A (${_pickedA.length}/$_perSide)'
        : 'Picking B (${_pickedB.length}/$_perSide)';
  }

  String _ctaLabel() {
    if (_isComplete) return 'Continue → Render';
    final int remainA = _perSide - _pickedA.length;
    final int remainB = _perSide - _pickedB.length;
    return 'Pick $remainA more A, $remainB more B';
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(_error!)),
      );
    }
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos.'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: _videos.length,
      itemBuilder: (BuildContext context, int i) {
        final AssetEntity asset = _videos[i];
        final bool picked = _isPicked(asset);
        return GestureDetector(
          onTap: () => _onTap(asset),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              FutureBuilder<Uint8List?>(
                future: asset.thumbnailDataWithSize(
                  const ThumbnailSize(300, 500),
                ),
                builder: (_, AsyncSnapshot<Uint8List?> snap) {
                  final Uint8List? data = snap.data;
                  if (data == null) {
                    return Container(color: Colors.black12);
                  }
                  return Image.memory(data, fit: BoxFit.cover);
                },
              ),
              if (picked)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.indigo.withValues(alpha: 0.25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _tagOf(asset),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  color: Colors.black54,
                  child: Text(
                    '${asset.duration}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
