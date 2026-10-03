import 'dart:typed_data';

class SegmentationOutput {
  const SegmentationOutput({
    required this.width,
    required this.height,
    required this.classes,
    required this.logits,
  });

  final int width;
  final int height;
  final int classes;
  final Float32List logits;
}
