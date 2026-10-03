import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../domain/entities/wall_mask.dart';
import 'image_preprocessor.dart';
import 'mask_postprocessor.dart';
import 'segmentation_model.dart';
import 'yuv420_frame.dart';

/// Coordinates latest-frame-wins preprocessing, inference and mask smoothing.
class WallSegmentationService {
  WallSegmentationService({
    required this._model,
    this.wallClassIndex = 0,
    this.targetInferenceFps = 12,
    double smoothing = 0.65,
  }) : _postprocessor = MaskPostprocessor(
         wallClassIndex: wallClassIndex,
         smoothing: smoothing,
       );

  final SegmentationModel _model;
  final int wallClassIndex;
  final int targetInferenceFps;
  final MaskPostprocessor _postprocessor;
  bool _loaded = false;
  bool _busy = false;
  bool _disabled = false;
  bool _closed = false;
  DateTime? _lastInference;
  Float32List? _inputBuffer;
  Completer<void>? _inferenceFinished;
  Future<void>? _loadTask;

  int get inputWidth => _model.inputWidth;
  int get inputHeight => _model.inputHeight;

  Future<void> load() => _loadTask ??= _load();

  Future<void> _load() async {
    if (_closed) throw StateError('O serviço de segmentação já foi encerrado.');
    await _model.load();
    _loaded = true;
    if (_closed) {
      await _model.close();
      _loaded = false;
    }
  }

  Future<WallMask?> process(Yuv420Frame frame) async {
    if (!_loaded || _disabled || _busy) return null;
    final now = DateTime.now();
    final minInterval = Duration(
      microseconds: 1000000 ~/ math.max(1, targetInferenceFps),
    );
    if (_lastInference != null &&
        now.difference(_lastInference!) < minInterval) {
      return null;
    }

    _busy = true;
    _inferenceFinished = Completer<void>();
    _lastInference = now;
    try {
      final input = ImagePreprocessor.convertYuv420ToRgb(
        frame,
        targetWidth: inputWidth,
        targetHeight: inputHeight,
        output: _inputBuffer,
      );
      _inputBuffer = input;
      final output = await _model.run(
        input,
        width: inputWidth,
        height: inputHeight,
      );
      return _postprocessor.process(
        output.logits,
        width: output.width,
        height: output.height,
        classes: output.classes,
      );
    } catch (_) {
      _disabled = true;
      rethrow;
    } finally {
      _busy = false;
      _inferenceFinished?.complete();
      _inferenceFinished = null;
    }
  }

  Future<void> close() async {
    _closed = true;
    _disabled = true;
    try {
      await _loadTask;
    } catch (_) {
      // A failed model load is already reported by the presentation layer.
    }
    if (_busy) await _inferenceFinished?.future;
    if (_loaded) await _model.close();
    _loaded = false;
  }

  void resetTemporalState() {
    _postprocessor.reset();
    _lastInference = null;
  }
}
