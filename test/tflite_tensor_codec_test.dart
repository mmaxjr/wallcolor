import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/data/ml/tflite_tensor_codec.dart';

void main() {
  test('decodes int32 class IDs without treating each byte as a pixel', () {
    final bytes = Uint8List(12);
    ByteData.sublistView(bytes)
      ..setInt32(0, 0, Endian.little)
      ..setInt32(4, 3, Endian.little)
      ..setInt32(8, 149, Endian.little);

    expect(TfliteTensorCodec.int32ClassMap(bytes, pixels: 3), [0, 3, 149]);
  });

  test('converts normalized RGB pixels into uint8 camera values', () {
    expect(
      TfliteTensorCodec.normalizedRgbToUint8(Float32List.fromList([0, 0.5, 1])),
      [0, 128, 255],
    );
  });
}
