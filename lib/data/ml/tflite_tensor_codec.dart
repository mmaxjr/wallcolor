import 'dart:typed_data';

class TfliteTensorCodec {
  const TfliteTensorCodec._();

  static Uint8List normalizedRgbToUint8(Float32List rgb) => Uint8List.fromList(
    rgb.map((value) => (value * 255).round().clamp(0, 255)).toList(),
  );

  static Uint8List int32ClassMap(Uint8List bytes, {required int pixels}) {
    if (bytes.length != pixels * 4) {
      throw ArgumentError(
        'O tensor int32 não corresponde ao número de pixels.',
      );
    }
    final data = ByteData.sublistView(bytes);
    final classes = Uint8List(pixels);
    for (var pixel = 0; pixel < pixels; pixel++) {
      final classId = data.getInt32(pixel * 4, Endian.little);
      if (classId < 0 || classId > 255) {
        throw FormatException('Índice de classe fora do intervalo: $classId.');
      }
      classes[pixel] = classId;
    }
    return classes;
  }
}
