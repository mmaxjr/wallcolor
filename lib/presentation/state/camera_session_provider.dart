import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_config.dart';
import '../../data/camera/camera_service.dart';
import '../../data/ml/tflite_segmentation_model.dart';
import '../../data/ml/wall_segmentation_service.dart';
import '../../data/ml/yuv420_frame.dart';
import '../../domain/entities/paint_color.dart';
import '../../domain/entities/paint_palette.dart';
import '../../domain/entities/wall_mask.dart';

final cameraSessionProvider =
    NotifierProvider<CameraSessionController, CameraSessionState>(
      CameraSessionController.new,
    );

class CameraSessionState {
  const CameraSessionState({
    this.camera,
    this.cameraLoading = true,
    this.cameraError,
    this.modelError,
    this.modelLoaded = false,
    this.wallMask,
    this.palette = _defaultPalette,
    this.selectedColor = 1,
    this.debugMask = false,
  });

  static const _defaultPalette = <PaintColor>[
    PaintColor(name: 'Linho', hex: '#E8DFCC'),
    PaintColor(name: 'Sálvia', hex: '#A8B6A0'),
    PaintColor(name: 'Folha', hex: '#708A78'),
    PaintColor(name: 'Argila', hex: '#C98F72'),
    PaintColor(name: 'Névoa', hex: '#7589A0'),
    PaintColor(name: 'Palha', hex: '#D5C66C'),
  ];

  final CameraController? camera;
  final bool cameraLoading;
  final String? cameraError;
  final String? modelError;
  final bool modelLoaded;
  final WallMask? wallMask;
  final List<PaintColor> palette;
  final int selectedColor;
  final bool debugMask;

  Color get selectedPaintColor => palette[selectedColor].color;

  CameraSessionState copyWith({
    CameraController? camera,
    bool clearCamera = false,
    bool? cameraLoading,
    String? cameraError,
    bool clearCameraError = false,
    String? modelError,
    bool clearModelError = false,
    bool? modelLoaded,
    WallMask? wallMask,
    bool clearWallMask = false,
    List<PaintColor>? palette,
    int? selectedColor,
    bool? debugMask,
  }) => CameraSessionState(
    camera: clearCamera ? null : camera ?? this.camera,
    cameraLoading: cameraLoading ?? this.cameraLoading,
    cameraError: clearCameraError ? null : cameraError ?? this.cameraError,
    modelError: clearModelError ? null : modelError ?? this.modelError,
    modelLoaded: modelLoaded ?? this.modelLoaded,
    wallMask: clearWallMask ? null : wallMask ?? this.wallMask,
    palette: palette ?? this.palette,
    selectedColor: selectedColor ?? this.selectedColor,
    debugMask: debugMask ?? this.debugMask,
  );
}

class CameraSessionController extends Notifier<CameraSessionState> {
  final CameraService _cameraService = CameraService();
  final WallSegmentationService _segmentationService = WallSegmentationService(
    model: TfliteSegmentationModel(),
    // The TensorFlow ADE20K checkpoint includes class 0 as `ignore`;
    // `wall` is the next label in its model output map.
    wallClassIndex: 1,
    targetInferenceFps: AppConfig.inferenceFps,
    smoothing: AppConfig.maskSmoothing,
  );
  bool _initializingCamera = false;
  bool _modelAttempted = false;
  bool _disposed = false;
  int _sessionGeneration = 0;

  @override
  CameraSessionState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_disposeResources());
    });
    unawaited(_loadPalette());
    Future<void>.microtask(initializeCamera);
    return const CameraSessionState();
  }

  Future<void> _loadPalette() async {
    try {
      final source = await rootBundle.loadString(
        'assets/palettes/starter.json',
      );
      final palette = PaintPalette.fromJsonString(source);
      if (!_disposed && palette.colors.isNotEmpty) {
        state = state.copyWith(
          palette: palette.colors,
          selectedColor: state.selectedColor.clamp(
            0,
            palette.colors.length - 1,
          ),
        );
      }
    } catch (_) {
      // The app has embedded fallback swatches.
    }
  }

  Future<void> initializeCamera() async {
    if (_initializingCamera || _disposed) return;
    _initializingCamera = true;
    final generation = ++_sessionGeneration;
    state = state.copyWith(cameraLoading: true, clearCameraError: true);
    try {
      final permission = await Permission.camera.request();
      if (_disposed) return;
      if (!permission.isGranted) {
        state = state.copyWith(
          cameraLoading: false,
          cameraError: permission.isPermanentlyDenied
              ? 'A permissão da câmera está bloqueada. Ative-a nas configurações do Android.'
              : 'A permissão da câmera é necessária para visualizar a parede.',
        );
        return;
      }
      final camera = await _cameraService.initialize();
      if (_disposed) {
        await camera.dispose();
        return;
      }
      state = state.copyWith(
        camera: camera,
        cameraLoading: false,
        clearCameraError: true,
        clearWallMask: true,
      );
      await _startSegmentation(camera, generation);
    } on CameraException catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          cameraLoading: false,
          cameraError:
              'Não foi possível iniciar a câmera: ${error.description ?? error.code}',
        );
      }
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          cameraLoading: false,
          cameraError: 'Falha ao abrir a câmera: $error',
        );
      }
    } finally {
      _initializingCamera = false;
    }
  }

  Future<void> _startSegmentation(
    CameraController camera,
    int generation,
  ) async {
    if (!_modelAttempted) {
      _modelAttempted = true;
      try {
        await _segmentationService.load();
        if (_disposed) return;
        state = state.copyWith(modelLoaded: true, clearModelError: true);
      } catch (error) {
        if (!_disposed) {
          state = state.copyWith(
            modelError: 'Modelo de parede indisponível: $error',
          );
        }
        debugPrint('WallColor model load failed: $error');
        return;
      }
    }
    if (_disposed ||
        generation != _sessionGeneration ||
        !state.modelLoaded ||
        !identical(state.camera, camera)) {
      return;
    }
    try {
      await _cameraService.startImageStream(
        (image) => _onCameraFrame(image, generation),
      );
    } catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          modelError: 'Não foi possível iniciar a segmentação: $error',
        );
      }
    }
  }

  Future<void> _onCameraFrame(CameraImage image, int generation) async {
    try {
      final mask = await _segmentationService.process(
        Yuv420Frame.fromCameraImage(image),
      );
      if (mask != null && !_disposed && generation == _sessionGeneration) {
        state = state.copyWith(wallMask: mask);
      }
    } catch (error) {
      if (!_disposed && generation == _sessionGeneration) {
        state = state.copyWith(
          modelError: 'Falha ao segmentar a parede: $error',
        );
        debugPrint('WallColor inference failed: $error');
        unawaited(_cameraService.stopImageStream());
      }
    }
  }

  Future<void> pause() async {
    _sessionGeneration++;
    await _cameraService.dispose();
    _segmentationService.resetTemporalState();
    if (!_disposed) {
      state = state.copyWith(clearCamera: true, clearWallMask: true);
    }
  }

  Future<void> resume() => initializeCamera();

  Future<void> openCameraSettings() => openAppSettings();

  void selectColor(int index) => state = state.copyWith(selectedColor: index);

  void toggleDebugMask() => state = state.copyWith(debugMask: !state.debugMask);

  Future<void> _disposeResources() async {
    await _cameraService.dispose();
    await _segmentationService.close();
  }
}
