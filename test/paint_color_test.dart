import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/domain/entities/paint_color.dart';

void main() {
  test('parses paint name and hexadecimal color from JSON', () {
    final paint = PaintColor.fromJson({'name': 'Sálvia', 'hex': '#A8B6A0'});
    expect(paint.name, 'Sálvia');
    expect(paint.color.toARGB32(), 0xFFA8B6A0);
  });
}
