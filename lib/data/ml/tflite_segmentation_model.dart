import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../domain/entities/segmentation_output.dart';
import 'segmentation_model.dart';
import 'tflite_tensor_codec.dart';

class TfliteSegmentationModel implements SegmentationModel {
  TfliteSegmentationModel({
    this.assetPath = 'assets/models/wall_segmentation.tflite',
  });

  final String assetPath;
  Isolate? _worker;
  SendPort? _sendPort;
  final ReceivePort _responses = ReceivePort();
  StreamSubscription<Object?>? _responseSubscription;
  final Map<int, Completer<Object?>> _pending = {};
  int _requestId = 0;
  Completer<SendPort>? _ready;
  Completer<void>? _closed;
  int _inputWidth = 256;
  int _inputHeight = 256;
  TensorType? _inputType;

  @override
  int get inputWidth => _inputWidth;

  @override
  int get inputHeight => _inputHeight;

  @override
  Future<void> load() async {
    try {
      final rootToken = RootIsolateToken.instance!;
      _ready = Completer<SendPort>();
      _responseSubscription = _responses.listen(_handleResponse);
      _worker = await Isolate.spawn(
        _modelWorker,
        _WorkerInit(_responses.sendPort, rootToken, assetPath),
        errorsAreFatal: false,
      );
      _sendPort = await _ready!.future.timeout(const Duration(seconds: 30));
      final metadata = await _send<Map<Object?, Object?>>('metadata', null);
      _inputWidth = metadata['width']! as int;
      _inputHeight = metadata['height']! as int;
      _inputType = TensorType.values.byName(metadata['inputType']! as String);
    } catch (error) {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      await _responseSubscription?.cancel();
      _responseSubscription = null;
      _responses.close();
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
    if (_sendPort == null) {
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
    return _send<SegmentationOutput>(
      'infer',
      _InferenceRequest(input: input, width: width, height: height),
    );
  }

  @override
  Future<void> close() async {
    if (_sendPort case final port?) {
      _closed = Completer<void>();
      port.send({'type': 'close'});
      await _closed!.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    }
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _sendPort = null;
    await _responseSubscription?.cancel();
    _responses.close();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(
          StateError('O isolate de inferência foi encerrado.'),
        );
      }
    }
    _pending.clear();
  }

  Future<T> _send<T>(String type, Object? payload) {
    final id = ++_requestId;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _sendPort!.send({'type': type, 'id': id, 'payload': payload});
    return completer.future
        .timeout(const Duration(seconds: 30))
        .then((v) => v as T);
  }

  void _handleResponse(Object? message) {
    if (message is SendPort) {
      if (!(_ready?.isCompleted ?? true)) _ready!.complete(message);
      return;
    }
    if (message is! Map) return;
    final id = message['id'] as int?;
    if (id == -1 && message['type'] == 'error') {
      if (!(_ready?.isCompleted ?? true)) {
        _ready!.completeError(StateError(message['error'] as String));
      }
      return;
    }
    if (id == null) return;
    if (message['type'] == 'closed') {
      if (!(_closed?.isCompleted ?? true)) _closed!.complete();
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (message['type'] == 'error') {
      completer.completeError(StateError(message['error'] as String));
    } else {
      completer.complete(message['result']);
    }
  }
}

class _WorkerInit {
  const _WorkerInit(this.replyPort, this.rootToken, this.assetPath);
  final SendPort replyPort;
  final RootIsolateToken rootToken;
  final String assetPath;
}

class _InferenceRequest {
  const _InferenceRequest({
    required this.input,
    required this.width,
    required this.height,
  });
  final Uint8List input;
  final int width;
  final int height;
}

@pragma('vm:entry-point')
Future<void> _modelWorker(_WorkerInit init) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(init.rootToken);
  final commands = ReceivePort();
  Interpreter? interpreter;
  GpuDelegateV2? gpuDelegate;
  try {
    if (Platform.isAndroid) {
      final gpuOptions = InterpreterOptions()..threads = 4;
      try {
        gpuDelegate = GpuDelegateV2();
        gpuOptions.addDelegate(gpuDelegate);
        interpreter = await Interpreter.fromAsset(
          init.assetPath,
          options: gpuOptions,
        );
        gpuOptions.delete();
      } catch (_) {
        gpuOptions.delete();
        gpuDelegate?.delete();
        gpuDelegate = null;
      }
    }
    if (interpreter == null) {
      final cpuOptions = InterpreterOptions()..threads = 4;
      interpreter = await Interpreter.fromAsset(
        init.assetPath,
        options: cpuOptions,
      );
      cpuOptions.delete();
    }
    final input = interpreter.getInputTensor(0);
    init.replyPort.send(commands.sendPort);
    commands.listen((raw) async {
      if (raw is! Map) return;
      final type = raw['type'];
      if (type == 'close') {
        interpreter?.close();
        gpuDelegate?.delete();
        init.replyPort.send({'type': 'closed'});
        commands.close();
        return;
      }
      final id = raw['id'] as int;
      try {
        if (type == 'metadata') {
          init.replyPort.send({
            'type': 'result',
            'id': id,
            'result': {
              'width': input.shape[2],
              'height': input.shape[1],
              'inputType': input.type.name,
            },
          });
        } else {
          final request = raw['payload'] as _InferenceRequest;
          SegmentationOutput result;
          try {
            result = _inferClassMap(interpreter!, request.input);
          } catch (_) {
            if (gpuDelegate == null) rethrow;
            interpreter!.close();
            gpuDelegate!.delete();
            gpuDelegate = null;
            final cpuOptions = InterpreterOptions()..threads = 4;
            interpreter = await Interpreter.fromAsset(
              init.assetPath,
              options: cpuOptions,
            );
            cpuOptions.delete();
            result = _inferClassMap(interpreter!, request.input);
          }
          init.replyPort.send({'type': 'result', 'id': id, 'result': result});
        }
      } catch (error, stack) {
        init.replyPort.send({
          'type': 'error',
          'id': id,
          'error': '$error\n$stack',
        });
      }
    });
  } catch (error, stack) {
    init.replyPort.send({'type': 'error', 'id': -1, 'error': '$error\n$stack'});
  }
}

SegmentationOutput _inferClassMap(Interpreter interpreter, Uint8List input) {
  final output = interpreter.getOutputTensor(0);
  final shape = output.shape;
  final isMap = shape.length == 3 || (shape.length == 4 && shape[3] == 1);
  if (!isMap ||
      (output.type != TensorType.uint8 && output.type != TensorType.int32)) {
    throw StateError('Formato de saída não suportado: ${output.type} $shape');
  }
  final pixels = shape[1] * shape[2];
  final Uint8List classMap;
  if (output.type == TensorType.uint8) {
    classMap = Uint8List(pixels);
    interpreter.run(input, classMap);
  } else {
    final bytes = Uint8List(pixels * 4);
    interpreter.run(input, bytes);
    classMap = TfliteTensorCodec.int32ClassMap(bytes, pixels: pixels);
  }
  final maxClass = classMap.reduce((a, b) => a > b ? a : b);
  return SegmentationOutput(
    width: shape[2],
    height: shape[1],
    classes: maxClass + 1,
    logits: Float32List(0),
    classMap: classMap,
  );
}
