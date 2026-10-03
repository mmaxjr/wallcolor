import 'dart:convert';

import 'paint_color.dart';

class PaintPalette {
  const PaintPalette(this.colors);

  final List<PaintColor> colors;

  factory PaintPalette.fromJsonString(String source) {
    final decoded = jsonDecode(source) as List<dynamic>;
    return PaintPalette(
      decoded
          .map((item) => PaintColor.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
