import 'dart:typed_data';

abstract interface class SegmentationModel {
  Future<void> load();

  Future<Float32List> run(
    Float32List normalizedRgb, {
    required int width,
    required int height,
  });

  Future<void> close();
}
