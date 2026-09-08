import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../domain/fish_stock.dart';

class FishArtworkView extends StatelessWidget {
  const FishArtworkView({
    required this.kind,
    this.customBytes,
    this.fit = BoxFit.contain,
    super.key,
  });

  final FishArtworkKind kind;
  final Uint8List? customBytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (kind == FishArtworkKind.custom && customBytes != null) {
      return Image.memory(
        customBytes!,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    }
    return Image.asset(
      builtinFishSpeciesFor(kind).asset,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Icon(Icons.set_meal_outlined),
    );
  }
}
