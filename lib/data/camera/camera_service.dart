import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraController? get controller => _controller;

  Future<CameraController> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException(
        'no_camera',
        'Nenhuma câmera disponível neste aparelho.',
      );
    }
    final camera = cameras.firstWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      _controller = null;
      await controller.dispose();
      rethrow;
    }
    return controller;
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller?.value.isStreamingImages ?? false) {
      try {
        await controller!.stopImageStream();
      } catch (_) {
        // The platform may already have stopped the stream during app pause.
      }
    }
    await controller?.dispose();
  }

  Future<void> startImageStream(
    void Function(CameraImage image) onFrame,
  ) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('A câmera ainda não foi inicializada.');
    }
    if (!controller.value.isStreamingImages) {
      await controller.startImageStream(onFrame);
    }
  }

  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller?.value.isStreamingImages ?? false) {
      await controller!.stopImageStream();
    }
  }
}
