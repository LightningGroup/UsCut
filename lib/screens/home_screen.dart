import 'package:flutter/material.dart';

import 'clip_picker_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UsCut'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Stage 1 Prototype',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pick 3 clips as "A" and 3 clips as "B".\n'
                'UsCut interleaves them into a 9:16 mp4.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.movie_filter),
                label: const Text('Pick Clips'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ClipPickerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
