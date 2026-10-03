import 'dart:typed_data';

import '../../domain/entities/segmentation_output.dart';

abstract interface class SegmentationModel {
  int get inputWidth;

  int get inputHeight;

  Future<void> load();

  Future<SegmentationOutput> run(
    Float32List normalizedRgb, {
    required int width,
    required int height,
  });

  Future<void> close();
}
