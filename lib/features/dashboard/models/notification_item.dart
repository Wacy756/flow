import 'package:flutter/material.dart';

class NotificationItem {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  IconData get icon {
    switch (type) {
      case 'new_application':
        return Icons.person_add_outlined;
      case 'quote_submitted':
        return Icons.request_quote_outlined;
      case 'job_approved':
        return Icons.check_circle_outline;
      case 'incident_status_change':
        return Icons.update_outlined;
      case 'invitation_received':
        return Icons.home_outlined;
      case 'compliance_expiring':
        return Icons.shield_outlined;
      case 'rent_overdue':
        return Icons.warning_amber_rounded;
      case 'rent_discrepancy':
        return Icons.flag_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color iconColor(BuildContext context) {
    switch (type) {
      case 'compliance_expiring':
      case 'rent_overdue':
      case 'rent_discrepancy':
        return const Color(0xFFE65100);
      case 'new_application':
      case 'job_approved':
        return const Color(0xFF22C55E); // AppTheme.green
      case 'quote_submitted':
        return const Color(0xFF7C3AED);
      case 'invitation_received':
        return const Color(0xFF60A5FA);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String get timeFormatted {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${createdAt.day} ${m[createdAt.month - 1]}';
  }

  String get dateGroupLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created =
        DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diff = today.difference(created).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return 'Earlier';
  }

  // ---------------------------------------------------------------------------

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : {},
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
