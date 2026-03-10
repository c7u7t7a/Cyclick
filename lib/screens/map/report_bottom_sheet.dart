import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/report_model.dart';

/// Bottom sheet with a 2×2 grid of report type buttons.
/// Opened by the 'Report' FAB on the map.
class ReportBottomSheet extends StatelessWidget {
  final void Function(ReportType) onReportSubmit;

  const ReportBottomSheet({super.key, required this.onReportSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'What do you want to report?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your report helps make Sector 2 safer for everyone.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.subtleText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: ReportType.values
                .map((type) => _ReportTile(
                      type: type,
                      onTap: () {
                        Navigator.pop(context);
                        onReportSubmit(type);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportType type;
  final VoidCallback onTap;

  const _ReportTile({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: type.color.withAlpha(20),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: type.color.withAlpha(80), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: type.color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, color: type.color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                    height: 1.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
