import 'dart:math' as math;
import 'dart:typed_data';

import 'yuv420_frame.dart';

class ImagePreprocessor {
  const ImagePreprocessor._();

  /// Samples YUV420 directly at the model resolution and emits RGB floats [0,1].
  /// This avoids allocating a full-resolution intermediate RGB image per frame.
  static Float32List convertYuv420ToRgb(
    Yuv420Frame frame, {
    required int targetWidth,
    required int targetHeight,
    Float32List? output,
  }) {
    if (targetWidth <= 0 ||
        targetHeight <= 0 ||
        frame.width <= 0 ||
        frame.height <= 0) {
      throw ArgumentError(
        'As dimensões do frame e do modelo devem ser positivas.',
      );
    }
    if (frame.uvPixelStride <= 0 || frame.yRowStride < frame.width) {
      throw ArgumentError('Strides inválidos no frame YUV420.');
    }

    final outputLength = targetWidth * targetHeight * 3;
    final rgb = output != null && output.length == outputLength
        ? output
        : Float32List(outputLength);
    var outputIndex = 0;
    for (var targetY = 0; targetY < targetHeight; targetY++) {
      final sourceY = targetY * frame.height ~/ targetHeight;
      for (var targetX = 0; targetX < targetWidth; targetX++) {
        final sourceX = targetX * frame.width ~/ targetWidth;
        final yIndex = sourceY * frame.yRowStride + sourceX;
        final uvIndex =
            (sourceY ~/ 2) * frame.uvRowStride +
            (sourceX ~/ 2) * frame.uvPixelStride;
        if (yIndex >= frame.y.length ||
            uvIndex >= frame.u.length ||
            uvIndex >= frame.v.length) {
          throw ArgumentError(
            'Os planos YUV420 não correspondem aos strides e dimensões informados.',
          );
        }

        final luminance = math.max(0, frame.y[yIndex] - 16);
        final blueChroma = frame.u[uvIndex] - 128;
        final redChroma = frame.v[uvIndex] - 128;
        final red = (298 * luminance + 409 * redChroma + 128) >> 8;
        final green =
            (298 * luminance - 100 * blueChroma - 208 * redChroma + 128) >> 8;
        final blue = (298 * luminance + 516 * blueChroma + 128) >> 8;
        rgb[outputIndex++] = red.clamp(0, 255) / 255;
        rgb[outputIndex++] = green.clamp(0, 255) / 255;
        rgb[outputIndex++] = blue.clamp(0, 255) / 255;
      }
    }
    return rgb;
  }
}
