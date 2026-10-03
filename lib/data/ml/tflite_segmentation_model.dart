import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/entities/segmentation_output.dart';
import 'segmentation_model.dart';
import 'tflite_tensor_codec.dart';

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
  TensorType? _inputType;

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
      _inputType = _interpreter!.getInputTensor(0).type;
      if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
        throw StateError(
          'Formato de entrada incompatível: $inputShape. Esperado [1, altura, largura, 3].',
        );
      }
      if (_inputType != TensorType.float32 && _inputType != TensorType.uint8) {
        throw StateError(
          'O modelo precisa aceitar pixels RGB float32 ou uint8.',
        );
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
    final Uint8List input;
    if (_inputType == TensorType.uint8) {
      input = TfliteTensorCodec.normalizedRgbToUint8(normalizedRgb);
    } else {
      input = Uint8List.view(
        normalizedRgb.buffer,
        normalizedRgb.offsetInBytes,
        normalizedRgb.lengthInBytes,
      );
    }
    final outputShape = interpreter.getOutputTensor(0).shape;
    final outputIsClassMap =
        (outputShape.length == 3 && outputShape[0] == 1) ||
        (outputShape.length == 4 && outputShape[0] == 1 && outputShape[3] == 1);
    final hasBatchAndSpatialShape =
        outputShape.length == 3 || outputShape.length == 4;
    if (!hasBatchAndSpatialShape ||
        outputShape[0] != 1 ||
        outputShape[1] <= 0 ||
        outputShape[2] <= 0) {
      throw StateError(
        'Formato de saída incompatível: $outputShape. Esperado [1, altura, largura] para mapa de classes ou [1, altura, largura, classes] para logits.',
      );
    }
    final outputType = interpreter.getOutputTensor(0).type;
    final classes = outputShape.length == 4 ? outputShape[3] : 1;
    final isDiscreteMap =
        outputIsClassMap &&
        (outputType == TensorType.uint8 || outputType == TensorType.int32);
    if (outputType != TensorType.float32 && !isDiscreteMap) {
      throw StateError('Tipo de saída incompatível: $outputType $outputShape.');
    }
    if (isDiscreteMap) {
      final mapLength = outputShape[1] * outputShape[2];
      final Uint8List classMap;
      if (outputType == TensorType.uint8) {
        classMap = Uint8List(mapLength);
        await worker.run(input, classMap.buffer);
      } else {
        final rawClassMap = Uint8List(mapLength * 4);
        await worker.run(input, rawClassMap.buffer);
        classMap = TfliteTensorCodec.int32ClassMap(
          rawClassMap,
          pixels: mapLength,
        );
      }
      final maxClass = classMap.reduce((a, b) => a > b ? a : b);
      return SegmentationOutput(
        width: outputShape[2],
        height: outputShape[1],
        classes: maxClass + 1,
        logits: Float32List(0),
        classMap: classMap,
      );
    }
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
    await worker.run(input, rawOutput.buffer);
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
    _inputType = null;
  }
}
