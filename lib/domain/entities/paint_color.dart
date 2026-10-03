import 'package:flutter/material.dart';

class PaintColor {
  const PaintColor({required this.name, required this.hex});

  final String name;
  final String hex;

  Color get color {
    final value = hex.replaceFirst('#', '');
    final normalized = value.length == 6 ? 'FF$value' : value;
    return Color(int.parse(normalized, radix: 16));
  }

  factory PaintColor.fromJson(Map<String, dynamic> json) =>
      PaintColor(name: json['name'] as String, hex: json['hex'] as String);
}
