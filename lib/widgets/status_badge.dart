import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case InvoiceStatus.paid:
        badgeColor = AppColors.paid.withValues(alpha: 0.12);
        textColor = AppColors.paid; // #16A34A
        label = 'Paid';
        icon = Icons.check_circle_rounded;
        break;
      case InvoiceStatus.pending:
        badgeColor = AppColors.pending.withValues(alpha: 0.15);
        textColor = AppColors.pending; // #F59E0B
        label = 'Pending';
        icon = Icons.hourglass_top_rounded;
        break;
      case InvoiceStatus.overdue:
        badgeColor = AppColors.dueOverdue.withValues(alpha: 0.12);
        textColor = AppColors.dueOverdue; // #DC2626
        label = 'Due / Overdue';
        icon = Icons.warning_amber_rounded;
        break;
      case InvoiceStatus.quotation:
        badgeColor = Colors.purple.withValues(alpha: 0.15);
        textColor = Colors.purple.shade700;
        label = 'Quotation';
        icon = Icons.request_quote_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTheme.timesFont(
                fontSize: isCompact ? 11 : 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
