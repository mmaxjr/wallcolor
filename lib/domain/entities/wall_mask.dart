import 'dart:typed_data';

class WallMask {
  const WallMask({
    required this.width,
    required this.height,
    required this.values,
  });

  final int width;
  final int height;
  final Float32List values;

  double at(int x, int y) => values[y * width + x];
}
