import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/entities/wall_mask.dart';

/// Draws a translucent paint-color layer only where the wall mask is opaque.
class MaskPaintOverlay extends StatefulWidget {
  const MaskPaintOverlay({
    required this.mask,
    required this.paintColor,
    required this.debugMask,
    super.key,
  });

  final WallMask mask;
  final Color paintColor;
  final bool debugMask;

  @override
  State<MaskPaintOverlay> createState() => _MaskPaintOverlayState();
}

class _MaskPaintOverlayState extends State<MaskPaintOverlay> {
  ui.Image? _maskImage;
  int _decodeSequence = 0;

  @override
  void initState() {
    super.initState();
    _decodeMask();
  }

  @override
  void didUpdateWidget(covariant MaskPaintOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mask != widget.mask ||
        oldWidget.debugMask != widget.debugMask) {
      _decodeMask();
    }
  }

  void _decodeMask() {
    final sequence = ++_decodeSequence;
    final mask = widget.mask;
    final rgba = Uint8List(mask.width * mask.height * 4);
    for (var index = 0; index < mask.values.length; index++) {
      final pixel = index * 4;
      rgba[pixel] = widget.debugMask ? 35 : 255;
      rgba[pixel + 1] = widget.debugMask ? 235 : 255;
      rgba[pixel + 2] = widget.debugMask ? 95 : 255;
      rgba[pixel + 3] = (mask.values[index].clamp(0, 1) * 255).round();
    }
    ui.decodeImageFromPixels(
      rgba,
      mask.width,
      mask.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || sequence != _decodeSequence) {
          image.dispose();
          return;
        }
        setState(() {
          _maskImage?.dispose();
          _maskImage = image;
        });
      },
    );
  }

  @override
  void dispose() {
    _decodeSequence++;
    _maskImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maskImage = _maskImage;
    if (maskImage == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => ui.ImageShader(
          maskImage,
          TileMode.clamp,
          TileMode.clamp,
          Float64List.fromList([
            maskImage.width / bounds.width,
            0,
            0,
            0,
            0,
            maskImage.height / bounds.height,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        ),
        child: ColoredBox(
          color:
              (widget.debugMask ? const Color(0xFF23EB5F) : widget.paintColor)
                  .withValues(alpha: widget.debugMask ? 0.82 : 0.46),
        ),
      ),
    );
  }
}
