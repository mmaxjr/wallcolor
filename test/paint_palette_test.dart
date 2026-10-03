import 'package:flutter_test/flutter_test.dart';
import 'package:tinta_ar/domain/entities/paint_palette.dart';

void main() {
  test('parses a JSON palette', () {
    final palette = PaintPalette.fromJsonString(
      '[{"name":"Linho","hex":"#E8DFCC"}]',
    );
    expect(palette.colors, hasLength(1));
    expect(palette.colors.single.name, 'Linho');
    expect(palette.colors.single.color.toARGB32(), 0xFFE8DFCC);
  });
}
