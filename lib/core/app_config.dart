import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static int get inferenceFps =>
      int.tryParse(dotenv.env['INFERENCE_FPS'] ?? '') ?? 12;

  static double get maskSmoothing =>
      double.tryParse(dotenv.env['MASK_SMOOTHING'] ?? '')
          ?.clamp(0, 1)
          .toDouble() ??
      0.65;
}
