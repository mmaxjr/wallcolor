import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/data/ml/mask_postprocessor.dart';

void main() {
  test('selects wall class from per-pixel argmax', () {
    final processor = MaskPostprocessor(wallClassIndex: 1);
    final result = processor.process(
      Float32List.fromList([0, 4, 3, 1]),
      width: 2,
      height: 1,
      classes: 2,
    );
    expect(result.values, [1, 0]);
  });

  test('stabilizes transitions without fractional edge bleed', () {
    final processor = MaskPostprocessor(wallClassIndex: 1, smoothing: 0.5);
    processor.process(
      Float32List.fromList([1, 0]),
      width: 1,
      height: 1,
      classes: 2,
    );
    final result = processor.process(
      Float32List.fromList([0, 1]),
      width: 1,
      height: 1,
      classes: 2,
    );
    expect(result.values.single, 1);
    final next = processor.process(
      Float32List.fromList([1, 0]),
      width: 1,
      height: 1,
      classes: 2,
    );
    expect(next.values.single, 0);
  });

  test('selects wall from a quantized model class map', () {
    final processor = MaskPostprocessor(wallClassIndex: 1);
    final result = processor.process(
      Float32List(0),
      width: 3,
      height: 1,
      classes: 32,
      classMap: Uint8List.fromList([0, 3, 1]),
    );
    expect(result.values, [0, 0, 1]);
  });
}
