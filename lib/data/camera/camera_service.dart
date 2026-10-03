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
    await controller.initialize();
    return controller;
  }

  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
