import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';

/// Role-aware incident card — shows different action buttons per role.
class IncidentCard extends StatelessWidget {
  final Incident incident;
  final String role;

  /// The current user's ID — used by contractor view to check job ownership.
  final String? currentUserId;
  final VoidCallback? onTap;
  final void Function(String action)? onAction;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.role,
    this.currentUserId,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + category + date row
                  Row(
                    children: [
                      _StatusBadge(status: incident.status),
                      if (incident.category != null) ...[
                        const SizedBox(width: 6),
                        _CategoryBadge(label: incident.category!),
                      ],
                      const Spacer(),
                      Text(
                        _formatDate(incident.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Title
                  Text(
                    incident.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    incident.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Media thumbnails
                  if (incident.mediaUrls.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: incident.mediaUrls.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            incident.mediaUrls[i],
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: AppTheme.primarySurface,
                              child: const Icon(Icons.image, size: 20,
                                  color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Footer: reporter / property
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (incident.tenantName != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reported by',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(incident.tenantName!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      if (incident.propertyPostcode != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (incident.distanceMeters != null)
                              Text(
                                '${(incident.distanceMeters! / 1609.34).toStringAsFixed(1)} mi away',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.contractorColor,
                                ),
                              ),
                            Text('Location',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(incident.propertyPostcode!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action footer (only for active incidents)
            if (incident.isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                child: _ActionFooter(
                  incident: incident,
                  role: role,
                  currentUserId: currentUserId,
                  onAction: onAction,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

// ---------------------------------------------------------------------------

class _ActionFooter extends StatelessWidget {
  final Incident incident;
  final String role;
  final String? currentUserId;
  final void Function(String)? onAction;

  const _ActionFooter({
    required this.incident,
    required this.role,
    this.currentUserId,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    switch (role) {
      case 'landlord':
        if (incident.status == 'reported') {
          return _ActionButton(
            label: 'Approve Incident',
            color: const Color(0xFF2563EB),
            onTap: () => onAction?.call('approve_incident'),
          );
        }
        if (incident.status == 'quoted') {
          return _ActionButton(
            label:
                'Approve Quote: £${incident.quoteAmount?.toStringAsFixed(2) ?? '—'}',
            color: AppTheme.primaryDark,
            onTap: () => onAction?.call('approve_quote'),
          );
        }
        return _StatusLabel(incident.displayStatus);

      case 'tenant':
        if (incident.status == 'in_progress') {
          if (incident.isTenantCompleted) {
            return _StatusLabel('Waiting for contractor...');
          }
          return _ActionButton(
            label: 'Mark as Finished',
            color: AppTheme.primary,
            onTap: () => onAction?.call('tenant_complete'),
          );
        }
        return _StatusLabel(incident.displayStatus);

      case 'contractor':
        if (incident.status == 'approved' &&
            (incident.contractorId == null ||
                incident.contractorId == currentUserId)) {
          return _ActionButton(
            label: 'Submit Quote',
            color: const Color(0xFF7C3AED),
            onTap: () => onAction?.call('submit_quote'),
          );
        }
        if (incident.status == 'quoted' &&
            incident.contractorId == currentUserId) {
          return _StatusLabel(
              'Quote Sent: £${incident.quoteAmount?.toStringAsFixed(2) ?? '—'}');
        }
        if (incident.status == 'in_progress' &&
            incident.contractorId == currentUserId) {
          if (incident.isContractorCompleted) {
            return _StatusLabel('Waiting for tenant...');
          }
          return _ActionButton(
            label: 'Mark as Finished',
            color: AppTheme.primary,
            onTap: () => onAction?.call('contractor_complete'),
          );
        }
        return _StatusLabel(incident.displayStatus);

      default:
        return _StatusLabel(incident.displayStatus);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String label;
  const _StatusLabel(this.label);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _bg {
    switch (status) {
      case 'reported':
        return const Color(0xFFFFF7ED);
      case 'approved':
        return const Color(0xFFEFF6FF);
      case 'quoted':
        return const Color(0xFFF5F3FF);
      case 'in_progress':
        return const Color(0xFFECFDF5);
      case 'completed':
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFF9FAFB);
    }
  }

  Color get _fg {
    switch (status) {
      case 'reported':
        return const Color(0xFFEA580C);
      case 'approved':
        return const Color(0xFF2563EB);
      case 'quoted':
        return const Color(0xFF7C3AED);
      case 'in_progress':
        return const Color(0xFF059669);
      case 'completed':
        return const Color(0xFF16A34A);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _fg,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;
  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      );
}
