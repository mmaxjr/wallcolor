import 'dart:typed_data';

import '../../domain/entities/wall_mask.dart';

class MaskPostprocessor {
  MaskPostprocessor({required this.wallClassIndex, this.smoothing = 0.65}) {
    if (smoothing < 0 || smoothing > 1) {
      throw ArgumentError.value(smoothing, 'smoothing', 'Must be in [0, 1].');
    }
  }

  final int wallClassIndex;
  final double smoothing;
  Float32List? _previous;

  WallMask process(
    Float32List logits, {
    required int width,
    required int height,
    required int classes,
    Uint8List? classMap,
  }) {
    if (classMap != null && classMap.length != width * height) {
      throw ArgumentError('O mapa de classes não corresponde às dimensões.');
    }
    if (classMap == null && logits.length != width * height * classes) {
      throw ArgumentError('Os logits não correspondem às dimensões e classes.');
    }
    final mask = Float32List(width * height);
    for (var pixel = 0; pixel < width * height; pixel++) {
      final bestClass = classMap == null
          ? () {
              var best = 0;
              var bestScore = double.negativeInfinity;
              for (var classIndex = 0; classIndex < classes; classIndex++) {
                final score = logits[pixel * classes + classIndex];
                if (score > bestScore) {
                  bestScore = score;
                  best = classIndex;
                }
              }
              return best;
            }()
          : classMap[pixel];
      final current = bestClass == wallClassIndex ? 1.0 : 0.0;
      mask[pixel] = _previous == null || _previous!.length != mask.length
          ? current
          : smoothing * _previous![pixel] + (1 - smoothing) * current;
    }
    _previous = Float32List.fromList(mask);
    return WallMask(width: width, height: height, values: mask);
  }

  void reset() => _previous = null;
}
