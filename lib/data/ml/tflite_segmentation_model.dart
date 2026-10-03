import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'segmentation_model.dart';

class TfliteSegmentationModel implements SegmentationModel {
  TfliteSegmentationModel({
    this.assetPath = 'assets/models/wall_segmentation.tflite',
  });

  final String assetPath;
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;

  @override
  Future<void> load() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      try {
        options.addDelegate(GpuDelegateV2());
        _interpreter = await Interpreter.fromAsset(assetPath, options: options);
      } catch (_) {
        options.delete();
        _interpreter = await Interpreter.fromAsset(
          assetPath,
          options: InterpreterOptions()..threads = 2,
        );
      }
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );
    } catch (error) {
      throw StateError(
        'Não foi possível carregar $assetPath. Confira se o modelo existe e se os tensores são compatíveis. $error',
      );
    }
  }

  @override
  Future<Float32List> run(
    Float32List normalizedRgb, {
    required int width,
    required int height,
  }) async {
    final interpreter = _interpreter;
    final worker = _isolateInterpreter;
    if (interpreter == null || worker == null) {
      throw StateError('O modelo ainda não foi carregado.');
    }
    final input = normalizedRgb.reshape([1, height, width, 3]);
    final outputShape = interpreter.getOutputTensor(0).shape;
    final output = List.generate(
      outputShape[0],
      (_) => List.generate(
        outputShape[1],
        (_) => List.filled(outputShape[2], List.filled(outputShape[3], 0.0)),
      ),
    );
    await worker.run(input, output);
    return Float32List.fromList(
      output
          .expand(
            (batch) => batch.expand((row) => row.expand((pixel) => pixel)),
          )
          .toList(),
    );
  }

  @override
  Future<void> close() async {
    await _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
  }
}
