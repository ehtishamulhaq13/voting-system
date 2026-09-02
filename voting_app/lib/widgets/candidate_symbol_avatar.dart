import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../utils/data_uri_image.dart';

/// Candidate symbol: data-URI or plain base64 → [MemoryImage]; else default icon.
class CandidateSymbolAvatar extends StatelessWidget {
  const CandidateSymbolAvatar({
    super.key,
    required this.heroTag,
    required this.symbol,
    this.radius = 40,
  });

  final Object heroTag;
  final String? symbol;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final mem = memoryImageFromSymbol(symbol);

    return Hero(
      tag: heroTag,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentPrimary.withValues(alpha: mem != null ? 0.5 : 0.2),
              blurRadius: mem != null ? 20 : 10,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: AppColors.accentSecondary.withValues(alpha: 0.2),
              blurRadius: 14,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.bgSecondary.withValues(alpha: 0.9),
          backgroundImage: mem,
          child: mem == null
              ? Icon(
                  Icons.person_rounded,
                  size: radius * 0.95,
                  color: AppColors.textSecondary,
                )
              : null,
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.88, 0.88),
          end: const Offset(1, 1),
          duration: 550.ms,
          curve: Curves.elasticOut,
        );
  }
}
