import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/notification_item.dart';
import '../providers/dashboard_providers.dart';

class NotificationCentreScreen extends ConsumerWidget {
  const NotificationCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgPage,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPage,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(markAllNotificationsReadProvider.notifier).markAll(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Could not load notifications.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyState();
          }
          return _NotificationList(notifications: notifications);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NotificationList extends ConsumerWidget {
  final List<NotificationItem> notifications;
  const _NotificationList({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by date label
    final Map<String, List<NotificationItem>> grouped = {};
    for (final n in notifications) {
      final label = n.dateGroupLabel;
      grouped.putIfAbsent(label, () => []).add(n);
    }

    // Ordered group keys
    final orderedKeys = <String>[];
    for (final key in ['Today', 'Yesterday', 'Earlier']) {
      if (grouped.containsKey(key)) orderedKeys.add(key);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: orderedKeys.fold<int>(
        0,
        (sum, key) => sum + 1 + grouped[key]!.length,
      ),
      itemBuilder: (context, rawIndex) {
        // Flatten grouped structure into a sequential list
        int cursor = 0;
        for (final key in orderedKeys) {
          if (rawIndex == cursor) {
            return _GroupHeader(label: key);
          }
          cursor++;
          final items = grouped[key]!;
          if (rawIndex < cursor + items.length) {
            final item = items[rawIndex - cursor];
            return _NotificationRow(
              notification: item,
              onTap: () => _handleTap(context, ref, item),
            );
          }
          cursor += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    NotificationItem n,
  ) {
    // Mark as read
    if (!n.isRead) {
      ref.read(markNotificationReadProvider.notifier).mark(n.id);
    }

    // Set deep-link target so the dashboard can scroll to the relevant card.
    final incidentId = n.data['incident_id'] as String?;
    final tenancyId = n.data['tenancy_id'] as String?;

    if (incidentId != null) {
      ref.read(deepLinkIncidentIdProvider.notifier).state = incidentId;
    } else if (tenancyId != null) {
      ref.read(deepLinkTenancyIdProvider.notifier).state = tenancyId;
    } else if (n.type == 'new_application') {
      // new_application carries property_id which equals tenancy_id
      final propertyId = n.data['property_id'] as String?;
      if (propertyId != null) {
        ref.read(deepLinkTenancyIdProvider.notifier).state = propertyId;
      }
    }

    Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------

class _NotificationRow extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final color = n.iconColor(context);
    final isUnread = !n.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppTheme.bgSurface : AppTheme.bgPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? color.withValues(alpha: 0.2)
                : AppTheme.border,
            width: isUnread ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(n.icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        n.timeFormatted,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Unread dot
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: const Icon(
                  Icons.notifications_none_outlined,
                  size: 34,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'All caught up',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'New notifications will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
}
