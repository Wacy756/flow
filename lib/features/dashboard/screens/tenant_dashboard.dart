import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/notifications/push_service.dart';
import '../widgets/create_incident_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/stat_card.dart';
import '../widgets/tenancy_card.dart';

class TenantDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const TenantDashboard({super.key, required this.profile});

  @override
  ConsumerState<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends ConsumerState<TenantDashboard> {
  bool _showArchive = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _incidentKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final incidentId = PushDeepLink.incidentId;
      if (incidentId != null) {
        PushDeepLink.incidentId = null;
        ref.read(deepLinkIncidentIdProvider.notifier).state = incidentId;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    final incidentsAsync = ref.watch(tenantIncidentsProvider);
    final userId = ref.read(currentProfileProvider).valueOrNull?.id ?? '';

    // Deep-link listener — incident notifications
    ref.listen(deepLinkIncidentIdProvider, (_, id) {
      if (id == null) return;
      // Ensure active tab shows (not archive)
      if (_showArchive) setState(() => _showArchive = false);
      final key = _incidentKeys[id];
      if (key != null) _scrollToKey(key);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          ref.read(deepLinkIncidentIdProvider.notifier).state = null;
        }
      });
    });

    return RefreshIndicator(
      color: AppTheme.green,
      onRefresh: () async {
        ref.invalidate(tenantTenanciesProvider);
        ref.invalidate(tenantIncidentsProvider);
        ref.invalidate(tenantEndedTenanciesProvider);
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.bgPage,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                const FlowLogo(size: 26),
                const SizedBox(width: 10),
                const Text('Flow'),
              ],
            ),
            actions: [
              const NotificationBell(),
              profileAvatarButton(context, widget.profile),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _WelcomeHeader(profile: widget.profile),
                const SizedBox(height: 16),

                // Stats — visible immediately
                _statsRow(tenanciesAsync, incidentsAsync),
                const SizedBox(height: 28),

                // Pending invitations (conditional)
                tenanciesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tenancies) {
                    final pending = tenancies
                        .where((t) => t.status == 'pending')
                        .toList();
                    if (pending.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeaderTitle(
                          icon: Icons.mail_outline_rounded,
                          title: 'Pending Invitations',
                        ),
                        const SizedBox(height: 10),
                        ...pending.map((t) => _InvitationCard(tenancy: t)),
                        const SizedBox(height: 28),
                      ],
                    );
                  },
                ),

                // Incidents
                _incidentsSection(incidentsAsync, userId),
                const SizedBox(height: 28),

                // Properties
                const _SectionHeaderTitle(
                  icon: Icons.home_outlined,
                  title: 'My Properties',
                ),
                const SizedBox(height: 12),
                tenanciesAsync.when(
                  loading: () => const _LoadingState(),
                  error: (e, _) => const _EmptyState(
                    icon: Icons.error_outline,
                    message: 'Failed to load properties.',
                  ),
                  data: (tenancies) {
                    final active = tenancies
                        .where((t) => t.status == 'active')
                        .toList();
                    if (active.isEmpty) {
                      return const TenantOnboardingCard();
                    }
                    return Column(
                      children: active
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TenancyCard(tenancy: t),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Previous tenancies
                const _PreviousTenanciesSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _incidentsSection(
    AsyncValue<List<Incident>> incidentsAsync,
    String userId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeaderTitle(
              icon: Icons.warning_amber_rounded,
              title: 'Incidents',
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Report button — only when active tenancies exist
                ref.watch(tenantTenanciesProvider).whenOrNull(
                      data: (tenancies) {
                        final active = tenancies
                            .where((t) => t.status == 'active')
                            .toList();
                        if (active.isEmpty) return null;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton.icon(
                            onPressed: () => showCreateIncidentSheet(
                                context,
                                activeTenancies: active),
                            icon: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                            label: const Text('Report',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.green,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                          ),
                        );
                      },
                    ) ??
                    const SizedBox.shrink(),
                _ToggleRow(
                  leftLabel: 'Active',
                  rightLabel: 'Previous',
                  showRight: _showArchive,
                  onToggle: (v) => setState(() => _showArchive = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        incidentsAsync.when(
          loading: () => const _LoadingState(),
          error: (_, __) => const _EmptyState(
            icon: Icons.error_outline,
            message: 'Failed to load incidents.',
          ),
          data: (incidents) {
            final filtered = incidents
                .where((i) => _showArchive
                    ? i.status == 'completed'
                    : i.status != 'completed')
                .toList();
            if (filtered.isEmpty) {
              return _EmptyState(
                icon: _showArchive
                    ? Icons.history_outlined
                    : Icons.check_circle_outline,
                message: _showArchive
                    ? 'No previous incidents.'
                    : 'No open incidents.',
              );
            }
            final deepId =
                ref.watch(deepLinkIncidentIdProvider);
            return Column(
              children: filtered
                  .map((incident) {
                    final key = _incidentKeys.putIfAbsent(
                        incident.id, () => GlobalKey());
                    return Padding(
                      key: key,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: IncidentCard(
                        incident: incident,
                        role: 'tenant',
                        currentUserId: userId,
                        isHighlighted: deepId == incident.id,
                        onAction: (action) =>
                            _handleTenantAction(incident.id, action),
                      ),
                    );
                  })
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleTenantAction(String incidentId, String action) async {
    if (action == 'tenant_complete') {
      final ok = await ref
          .read(tenantMarkCompleteProvider.notifier)
          .markComplete(incidentId);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark incident complete.'),
            backgroundColor: AppTheme.darkBg,
          ),
        );
      }
    }
  }

  Widget _statsRow(
    AsyncValue<List<Tenancy>> tenanciesAsync,
    AsyncValue<List<Incident>> incidentsAsync,
  ) {
    final active = (tenanciesAsync.valueOrNull ?? [])
        .where((t) => t.status == 'active')
        .length;
    final openIncidents = (incidentsAsync.valueOrNull ?? [])
        .where((i) => i.status != 'completed')
        .length;
    final pending = (tenanciesAsync.valueOrNull ?? [])
        .where((t) => t.status == 'pending')
        .length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            value: '$active',
            label: 'Properties',
            description: 'Active',
            color: AppTheme.tenantGlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$openIncidents',
            label: 'Incidents',
            description: 'Open',
            color: AppTheme.contractorGlow,
          ),
        ),
        if (pending > 0) ...[
          const SizedBox(width: 10),
          Expanded(
            child: StatCard(
              value: '$pending',
              label: 'Invites',
              description: 'Pending',
              color: AppTheme.landlordGlow,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header components (shared within file)

class _SectionHeaderTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeaderTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppTheme.textSecondary),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final bool showRight;
  final void Function(bool) onToggle;

  const _ToggleRow({
    required this.leftLabel,
    required this.rightLabel,
    required this.showRight,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            label: leftLabel,
            active: !showRight,
            onTap: () => onToggle(false),
          ),
          _Pill(
            label: rightLabel,
            active: showRight,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              active ? Border.all(color: AppTheme.border, width: 0.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.green),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Welcome header

class _WelcomeHeader extends StatelessWidget {
  final UserProfile profile;
  const _WelcomeHeader({required this.profile});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final initial = profile.fullName.isNotEmpty
        ? profile.fullName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.tenantBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.tenantBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invitation card

class _InvitationCard extends ConsumerWidget {
  final Tenancy tenancy;
  const _InvitationCard({required this.tenancy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acceptState = ref.watch(acceptInvitationProvider);
    final isLoading = acceptState.isLoading;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.greenBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.home_outlined,
                size: 20, color: AppTheme.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenancy.shortAddress,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (tenancy.landlord?.fullName != null)
                  Text(
                    'From ${tenancy.landlord!.fullName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final ok = await ref
                        .read(acceptInvitationProvider.notifier)
                        .accept(tenancy.id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to accept invitation.'),
                          backgroundColor: AppTheme.darkBg,
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.green,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Accept',
                    style:
                        TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  Color get _bg => switch (status) {
        'active' => AppTheme.greenBg,
        'notice_given' => const Color(0xFFFFFBEB),
        'ended' => AppTheme.bgPage,
        _ => const Color(0xFFFFF3E0),
      };

  Color get _fg => switch (status) {
        'active' => AppTheme.green,
        'notice_given' => const Color(0xFFD97706),
        'ended' => AppTheme.textMuted,
        _ => const Color(0xFFE65100),
      };

  String get _label => switch (status) {
        'notice_given' => 'NOTICE',
        _ => status.replaceAll('_', ' ').toUpperCase(),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        _label,
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

// ---------------------------------------------------------------------------
// Previous Tenancies section

class _PreviousTenanciesSection extends ConsumerStatefulWidget {
  const _PreviousTenanciesSection();

  @override
  ConsumerState<_PreviousTenanciesSection> createState() =>
      _PreviousTenanciesSectionState();
}

class _PreviousTenanciesSectionState
    extends ConsumerState<_PreviousTenanciesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final endedAsync = ref.watch(tenantEndedTenanciesProvider);

    return endedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tenancies) {
        if (tenancies.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header with expand toggle
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 17,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Previous Tenancies (${tenancies.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppTheme.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Animated list
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Column(
                      children: tenancies
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _EndedTenancyCard(tenancy: t),
                            ),
                          )
                          .toList(),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _EndedTenancyCard extends StatelessWidget {
  final Tenancy tenancy;
  const _EndedTenancyCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.bgPage,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: const Icon(Icons.home_outlined,
                    color: AppTheme.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenancy.addressLine1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      tenancy.postcode,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: tenancy.status),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (tenancy.landlord?.fullName != null)
                _InfoChip(
                  icon: Icons.person_outline,
                  label: tenancy.landlord!.fullName!,
                ),
              if (tenancy.monthlyRent != null)
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: '£${tenancy.monthlyRent!.toStringAsFixed(0)}/mo',
                ),
              if (tenancy.endOfTenancyDate != null)
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ended ${_formatDateStr(tenancy.endOfTenancyDate!)}',
                ),
              if (tenancy.numBedrooms != null)
                _InfoChip(
                  icon: Icons.bed_outlined,
                  label: '${tenancy.numBedrooms} bed',
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateStr(String s) {
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
