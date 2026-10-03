import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/data/ml/wall_segmentation_service.dart';
import 'package:tinta_ar/data/ml/yuv420_frame.dart';
import 'package:tinta_ar/data/ml/segmentation_model.dart';
import 'package:tinta_ar/domain/entities/segmentation_output.dart';

void main() {
  test('drops incoming frames while inference is busy', () async {
    final model = _FakeModel();
    final service = WallSegmentationService(
      model: model,
      targetInferenceFps: 1000,
    );
    await service.load();
    final frame = _testFrame();

    final inFlight = service.process(frame);
    final dropped = await service.process(frame);

    expect(dropped, isNull);
    expect(model.runCount, 1);
    model.result.complete(_wallOutput());
    expect((await inFlight)!.values, [1, 1, 1, 1]);
    await service.close();
  });
}

Yuv420Frame _testFrame() => Yuv420Frame(
  width: 2,
  height: 2,
  y: Uint8List.fromList([235, 235, 235, 235]),
  u: Uint8List.fromList([128]),
  v: Uint8List.fromList([128]),
  yRowStride: 2,
  uvRowStride: 1,
  uvPixelStride: 1,
);

SegmentationOutput _wallOutput() => SegmentationOutput(
  width: 2,
  height: 2,
  classes: 2,
  logits: Float32List.fromList([1, 0, 1, 0, 1, 0, 1, 0]),
);

class _FakeModel implements SegmentationModel {
  final Completer<SegmentationOutput> result = Completer<SegmentationOutput>();
  int runCount = 0;

  @override
  int get inputWidth => 2;

  @override
  int get inputHeight => 2;

  @override
  Future<void> load() async {}

  @override
  Future<SegmentationOutput> run(
    Float32List normalizedRgb, {
    required int width,
    required int height,
  }) {
    runCount++;
    return result.future;
  }

  @override
  Future<void> close() async {}
}
