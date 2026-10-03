import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/camera_page/camera_page.dart';

class WallColorApp extends StatelessWidget {
  const WallColorApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    child: MaterialApp(
      title: 'WallColor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF466B59),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CameraPage(),
    ),
  );
}
