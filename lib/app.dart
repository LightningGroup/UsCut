import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

class UsCutApp extends StatelessWidget {
  const UsCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UsCut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
