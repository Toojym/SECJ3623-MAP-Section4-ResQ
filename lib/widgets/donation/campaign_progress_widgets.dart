// SIGAP-40 — Donation Progress Visualization Widgets
// Reusable widgets for campaign progress display across citizen and officer screens.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

// ─── Colour palette for fund allocation categories ────────────────────────────
const List<Color> kAllocationColors = [
  Color(0xFF3B6DD4), // primary blue
  Color(0xFF10B981), // emerald
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
  Color(0xFFEC4899), // pink
];

// ─── Animated Circular Progress Ring ─────────────────────────────────────────
class CampaignProgressRing extends StatelessWidget {
  final double fraction; // 0.0 – 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? child;

  const CampaignProgressRing({
    super.key,
    required this.fraction,
    this.size = 120,
    this.strokeWidth = 10,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? AppColors.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: strokeWidth,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                strokeCap: StrokeCap.round,
              ),
              if (child != null) child!,
            ],
          ),
        );
      },
    );
  }
}

// ─── Animated Linear Progress Bar ────────────────────────────────────────────
class CampaignProgressBar extends StatelessWidget {
  final double fraction; // 0.0 – 1.0
  final double height;
  final Color? color;

  const CampaignProgressBar({
    super.key,
    required this.fraction,
    this.height = 10,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: value,
            minHeight: height,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        );
      },
    );
  }
}

// ─── Fund Allocation Legend ───────────────────────────────────────────────────
class FundAllocationLegend extends StatelessWidget {
  final Map<String, double> allocations;

  const FundAllocationLegend({super.key, required this.allocations});

  @override
  Widget build(BuildContext context) {
    if (allocations.isEmpty) {
      return Text(
        'Tiada maklumat peruntukan.',
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
      );
    }
    final entries = allocations.entries.toList();
    return Column(
      children: [
        // Stacked allocation bar
        _AllocationStackedBar(entries: entries),
        const SizedBox(height: 16),
        // Legend list
        ...entries.asMap().entries.map((e) {
          final color = kAllocationColors[e.key % kAllocationColors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.value.key,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  '${e.value.value.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// Internal: a stacked horizontal bar for allocation breakdown
class _AllocationStackedBar extends StatelessWidget {
  final List<MapEntry<String, double>> entries;

  const _AllocationStackedBar({required this.entries});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold(0.0, (s, e) => s + e.value);
    if (total <= 0) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(
              children: entries.asMap().entries.map((e) {
                final color = kAllocationColors[e.key % kAllocationColors.length];
                final flex = ((e.value.value / total) * 1000 * anim).round();
                return Expanded(
                  flex: flex == 0 ? 1 : flex,
                  child: Container(color: color),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─── Compact allocation chip row (for cards) ──────────────────────────────────
class AllocationChipRow extends StatelessWidget {
  final Map<String, double> allocations;
  final int maxVisible;

  const AllocationChipRow({
    super.key,
    required this.allocations,
    this.maxVisible = 3,
  });

  @override
  Widget build(BuildContext context) {
    final entries = allocations.entries.toList();
    final visible = entries.take(maxVisible).toList();
    final remaining = entries.length - maxVisible;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visible.asMap().entries.map((e) {
          final color = kAllocationColors[e.key % kAllocationColors.length];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${e.value.key} ${e.value.value.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          );
        }),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$remaining lagi',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
