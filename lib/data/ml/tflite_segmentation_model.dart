import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/entities/segmentation_output.dart';
import 'segmentation_model.dart';

class TfliteSegmentationModel implements SegmentationModel {
  TfliteSegmentationModel({
    this.assetPath = 'assets/models/wall_segmentation.tflite',
  });

  final String assetPath;
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  int _inputWidth = 256;
  int _inputHeight = 256;
  Uint8List? _outputBuffer;

  @override
  int get inputWidth => _inputWidth;

  @override
  int get inputHeight => _inputHeight;

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
      final inputShape = _interpreter!.getInputTensor(0).shape;
      if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
        throw StateError(
          'Formato de entrada incompatível: $inputShape. Esperado [1, altura, largura, 3].',
        );
      }
      if (_interpreter!.getInputTensor(0).type != TensorType.float32) {
        throw StateError('O modelo precisa aceitar pixels RGB em float32.');
      }
      _inputHeight = inputShape[1];
      _inputWidth = inputShape[2];
      _isolateInterpreter = await IsolateInterpreter.create(
        address: _interpreter!.address,
      );
    } catch (error) {
      await _isolateInterpreter?.close();
      _isolateInterpreter = null;
      _interpreter?.close();
      _interpreter = null;
      throw StateError(
        'Não foi possível carregar $assetPath. Confira se o modelo existe e se os tensores são compatíveis. $error',
      );
    }
  }

  @override
  Future<SegmentationOutput> run(
    Float32List normalizedRgb, {
    required int width,
    required int height,
  }) async {
    final interpreter = _interpreter;
    final worker = _isolateInterpreter;
    if (interpreter == null || worker == null) {
      throw StateError('O modelo ainda não foi carregado.');
    }
    if (width != inputWidth ||
        height != inputHeight ||
        normalizedRgb.length != width * height * 3) {
      throw ArgumentError(
        'O frame de entrada não corresponde ao tensor do modelo.',
      );
    }
    final input = Uint8List.view(
      normalizedRgb.buffer,
      normalizedRgb.offsetInBytes,
      normalizedRgb.lengthInBytes,
    );
    final outputShape = interpreter.getOutputTensor(0).shape;
    if (outputShape.length != 4 ||
        outputShape[0] != 1 ||
        interpreter.getOutputTensor(0).type != TensorType.float32) {
      throw StateError(
        'Formato de saída incompatível: $outputShape. Esperado [1, altura, largura, classes].',
      );
    }
    final classes = outputShape[3];
    final outputLength = outputShape.reduce((a, b) => a * b);
    if (classes < 2) {
      throw StateError(
        'O modelo retornou logits incompatíveis com uma segmentação semântica.',
      );
    }
    final outputBuffer = _outputBuffer;
    final rawOutput =
        outputBuffer != null && outputBuffer.length == outputLength * 4
        ? outputBuffer
        : Uint8List(outputLength * 4);
    _outputBuffer = rawOutput;
    await worker.run(input, rawOutput);
    return SegmentationOutput(
      width: outputShape[2],
      height: outputShape[1],
      classes: classes,
      logits: Float32List.view(
        rawOutput.buffer,
        rawOutput.offsetInBytes,
        outputLength,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _isolateInterpreter?.close();
    _isolateInterpreter = null;
    _interpreter?.close();
    _interpreter = null;
    _outputBuffer = null;
  }
}
