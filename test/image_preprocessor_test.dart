import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/data/ml/image_preprocessor.dart';
import 'package:tinta_ar/data/ml/yuv420_frame.dart';

void main() {
  test(
    'converts limited-range black and white YUV pixels to normalized RGB',
    () {
      final frame = Yuv420Frame(
        width: 2,
        height: 2,
        y: Uint8List.fromList([16, 235, 16, 235]),
        u: Uint8List.fromList([128]),
        v: Uint8List.fromList([128]),
        yRowStride: 2,
        uvRowStride: 1,
        uvPixelStride: 1,
      );

      final rgb = ImagePreprocessor.convertYuv420ToRgb(
        frame,
        targetWidth: 2,
        targetHeight: 2,
      );

      expect(rgb.sublist(0, 3), [0, 0, 0]);
      expect(rgb.sublist(3, 6), [1, 1, 1]);
    },
  );

  test('resizes by sampling the source image and respects chroma strides', () {
    final frame = Yuv420Frame(
      width: 4,
      height: 2,
      y: Uint8List.fromList([16, 16, 235, 235, 16, 16, 235, 235]),
      u: Uint8List.fromList([128, 0, 128, 0]),
      v: Uint8List.fromList([128, 0, 128, 0]),
      yRowStride: 4,
      uvRowStride: 4,
      uvPixelStride: 2,
    );

    final rgb = ImagePreprocessor.convertYuv420ToRgb(
      frame,
      targetWidth: 2,
      targetHeight: 1,
    );

    expect(rgb, [0, 0, 0, 1, 1, 1]);
  });
}
