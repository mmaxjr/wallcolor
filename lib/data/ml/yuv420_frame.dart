import 'dart:typed_data';

import 'package:camera/camera.dart';

class Yuv420Frame {
  const Yuv420Frame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
  });

  factory Yuv420Frame.fromCameraImage(CameraImage image) {
    if (image.planes.length < 3) {
      throw ArgumentError('A câmera não entregou três planos YUV420.');
    }
    final planes = image.planes;
    return Yuv420Frame(
      width: image.width,
      height: image.height,
      y: planes[0].bytes,
      u: planes[1].bytes,
      v: planes[2].bytes,
      yRowStride: planes[0].bytesPerRow,
      uvRowStride: planes[1].bytesPerRow,
      uvPixelStride: planes[1].bytesPerPixel ?? 1,
    );
  }

  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;
}
