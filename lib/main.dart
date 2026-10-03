import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(
    fileName: 'assets/config/default.env',
    overrideWithFiles: ['assets/config/.env'],
    isOptional: true,
  );
  runApp(const WallColorApp());
}
