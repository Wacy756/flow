import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';
import '../providers/dashboard_providers.dart';
import 'incident_comments_thread.dart';
import 'rate_contractor_dialog.dart';

/// Role-aware incident card — shows different action buttons per role.
class IncidentCard extends ConsumerStatefulWidget {
  final Incident incident;
  final String role;

  /// The current user's ID — used by contractor view and for own-message detection.
  final String? currentUserId;
  final VoidCallback? onTap;
  final void Function(String action)? onAction;

  /// When true the card renders with a glowing green highlight border
  /// (used for notification deep-linking).
  final bool isHighlighted;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.role,
    this.currentUserId,
    this.onTap,
    this.onAction,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends ConsumerState<IncidentCard> {
  bool _commentsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final incident = widget.incident;

    // Comment count badge
    final commentsAsync =
        ref.watch(incidentCommentsProvider(incident.id));
    final commentCount = commentsAsync.valueOrNull?.length ?? 0;

    final borderColor = widget.isHighlighted
        ? AppTheme.green
        : AppTheme.border;
    final borderWidth = widget.isHighlighted ? 1.5 : 0.5;
    final bgColor = widget.isHighlighted
        ? AppTheme.greenBg.withValues(alpha: 0.4)
        : AppTheme.bgSurface;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: widget.isHighlighted
              ? [
                  BoxShadow(
                    color: AppTheme.green.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    incident.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.5,
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
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 6),
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
                              color: AppTheme.greenBg,
                              child: const Icon(Icons.image,
                                  size: 20, color: AppTheme.green),
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
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('Reported by',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                            Text(
                              incident.tenantName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
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
                                  color: AppTheme.contractorGlow,
                                ),
                              ),
                            Text('Location',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                            Text(
                              incident.propertyPostcode!,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action footer (active incidents)
            if (incident.isActive)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgPage,
                  border: Border(
                    top: BorderSide(
                        color: AppTheme.border, width: 0.5),
                  ),
                ),
                child: _ActionFooter(
                  incident: incident,
                  role: widget.role,
                  currentUserId: widget.currentUserId,
                  onAction: widget.onAction,
                ),
              ),

            // Rating footer (completed tenant jobs with a contractor)
            if (!incident.isActive &&
                widget.role == 'tenant' &&
                incident.contractorId != null)
              _RatingFooter(
                incident: incident,
                onRateTap: () => showRateContractorDialog(
                  context,
                  incidentId: incident.id,
                  incidentTitle: incident.title,
                  contractorId: incident.contractorId!,
                ),
              ),

            // Comments toggle
            _CommentsToggle(
              incidentId: incident.id,
              commentCount: commentCount,
              expanded: _commentsExpanded,
              onToggle: () =>
                  setState(() => _commentsExpanded = !_commentsExpanded),
              isLast: true,
            ),

            // Comments thread (animated)
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: _commentsExpanded
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: IncidentCommentsThread(
                        incidentId: incident.id,
                        currentUserId: widget.currentUserId ??
                            supabase.auth.currentUser?.id ??
                            '',
                        currentUserRole: widget.role,
                      ),
                    )
                  : const SizedBox.shrink(),
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
// Comments toggle bar

class _CommentsToggle extends StatelessWidget {
  final String incidentId;
  final int commentCount;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isLast;

  const _CommentsToggle({
    required this.incidentId,
    required this.commentCount,
    required this.expanded,
    required this.onToggle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: expanded
          ? BorderRadius.zero
          : const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: expanded ? AppTheme.bgSurface : AppTheme.bgPage,
          borderRadius: expanded
              ? BorderRadius.zero
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 14,
              color: expanded ? AppTheme.green : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              commentCount == 0
                  ? 'Comments'
                  : 'Comments ($commentCount)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: expanded ? AppTheme.green : AppTheme.textMuted,
              ),
            ),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: expanded ? AppTheme.green : AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
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
            onTap: () => onAction?.call('approve_incident'),
          );
        }
        if (incident.status == 'quoted') {
          return _ActionButton(
            label:
                'Approve Quote: £${incident.quoteAmount?.toStringAsFixed(2) ?? '—'}',
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
            onTap: () => onAction?.call('tenant_complete'),
          );
        }
        return _StatusLabel(incident.displayStatus);

      case 'contractor':
        if (incident.status == 'approved' &&
            (incident.contractorId == null ||
                incident.contractorId == currentUserId)) {
          return Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Submit Quote',
                  onTap: () => onAction?.call('submit_quote'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => onAction?.call('decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(
                      color: AppTheme.border, width: 0.5),
                  minimumSize: const Size(0, 40),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Pass',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
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
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.green,
          side: const BorderSide(color: AppTheme.green, width: 1.5),
          minimumSize: const Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
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
      case 'open':
        return const Color(0xFFFFF3E0);
      case 'approved':
      case 'in_progress':
        return const Color(0xFFEEF2FF);
      case 'quoted':
      case 'pending_approval':
        return const Color(0xFFF5F3FF);
      case 'completed':
        return AppTheme.greenBg;
      default:
        return AppTheme.bgPage;
    }
  }

  Color get _fg {
    switch (status) {
      case 'reported':
      case 'open':
        return const Color(0xFFE65100);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF4338CA);
      case 'quoted':
      case 'pending_approval':
        return const Color(0xFF7C3AED);
      case 'completed':
        return AppTheme.green;
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
          color: AppTheme.bgPage,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border, width: 0.5),
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

// ---------------------------------------------------------------------------
// Rating footer — shown on completed jobs for tenant role

class _RatingFooter extends ConsumerWidget {
  final Incident incident;
  final VoidCallback onRateTap;

  const _RatingFooter({
    required this.incident,
    required this.onRateTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(incidentRatingProvider(incident.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: ratingAsync.when(
        loading: () => const SizedBox(
          height: 20,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.green),
            ),
          ),
        ),
        error: (_, __) => _rateButton(),
        data: (existing) {
          if (existing != null) {
            // Already rated — show stars read-only
            return GestureDetector(
              onTap: onRateTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) {
                    return Icon(
                      i < existing.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 18,
                      color: i < existing.rating
                          ? const Color(0xFFF59E0B)
                          : AppTheme.textMuted,
                    );
                  }),
                  const SizedBox(width: 6),
                  const Text(
                    'Your rating',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return _rateButton();
        },
      ),
    );
  }

  Widget _rateButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onRateTap,
          icon: const Icon(Icons.star_outline_rounded,
              size: 15, color: Color(0xFFF59E0B)),
          label: const Text('Rate Contractor',
              style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF59E0B),
            side: const BorderSide(
                color: Color(0xFFF59E0B), width: 1.0),
            minimumSize: const Size(double.infinity, 40),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}
