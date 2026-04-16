import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/flow_logo.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../../../core/notifications/push_service.dart';
import '../widgets/add_tenancy_sheet.dart';
import '../widgets/applications_panel.dart';
import '../widgets/incident_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/onboarding_card.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/stat_card.dart';
import '../widgets/tenancy_card.dart';

class LandlordDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const LandlordDashboard({super.key, required this.profile});

  @override
  ConsumerState<LandlordDashboard> createState() =>
      _LandlordDashboardState();
}

class _LandlordDashboardState extends ConsumerState<LandlordDashboard> {
  bool _showArchive = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _incidentKeys = {};
  final Map<String, GlobalKey> _tenancyKeys = {};

  @override
  void initState() {
    super.initState();
    // Consume any deep-link that arrived via OS push while app was terminated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final incidentId = PushDeepLink.incidentId;
      final tenancyId  = PushDeepLink.tenancyId;
      if (incidentId != null) {
        PushDeepLink.incidentId = null;
        ref.read(deepLinkIncidentIdProvider.notifier).state = incidentId;
      } else if (tenancyId != null) {
        PushDeepLink.tenancyId = null;
        ref.read(deepLinkTenancyIdProvider.notifier).state = tenancyId;
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
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final incidentsAsync = ref.watch(landlordIncidentsProvider);

    // Deep-link listeners
    ref.listen(deepLinkIncidentIdProvider, (_, id) {
      if (id == null) return;
      // Ensure active tab is showing (not archive)
      if (_showArchive) setState(() => _showArchive = false);
      final key = _incidentKeys[id];
      if (key != null) _scrollToKey(key);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          ref.read(deepLinkIncidentIdProvider.notifier).state = null;
        }
      });
    });

    ref.listen(deepLinkTenancyIdProvider, (_, id) {
      if (id == null) return;
      final key = _tenancyKeys[id];
      if (key != null) _scrollToKey(key);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          ref.read(deepLinkTenancyIdProvider.notifier).state = null;
        }
      });
    });

    return RefreshIndicator(
      color: AppTheme.green,
      onRefresh: () async {
        ref.invalidate(landlordTenanciesProvider);
        ref.invalidate(landlordIncidentsProvider);
        ref.invalidate(endedTenanciesProvider);
        ref.invalidate(complianceSummaryProvider);
        ref.invalidate(landlordApplicationsProvider);
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

                // Stats — visible immediately without scrolling
                _statsRow(tenanciesAsync, incidentsAsync),
                const SizedBox(height: 16),

                // Compliance alert banner
                _ComplianceBanner(summaryAsync: ref.watch(complianceSummaryProvider)),
                const SizedBox(height: 12),

                // Incidents
                _incidentsSection(incidentsAsync),
                const SizedBox(height: 28),

                // Properties
                _SectionHeader(
                  icon: Icons.business_outlined,
                  title: 'Your Properties',
                  action: ElevatedButton.icon(
                    onPressed: () => showAddTenancySheet(context),
                    icon: const Icon(Icons.add, size: 15, color: Colors.white),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _tenanciesList(tenanciesAsync),
                const SizedBox(height: 28),

                // Previous Tenancies
                _PreviousTenanciesSection(profile: widget.profile),
                const SizedBox(height: 28),

                // Applications
                _SectionHeader(
                  icon: Icons.inbox_outlined,
                  title: 'Applications',
                ),
                const SizedBox(height: 12),
                const ApplicationsPanel(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _incidentsSection(AsyncValue<List<Incident>> incidentsAsync) {
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
            _ToggleRow(
              leftLabel: 'Active',
              rightLabel: 'Previous',
              showRight: _showArchive,
              onToggle: (v) => setState(() => _showArchive = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        incidentsAsync.when(
          loading: () => const _LoadingState(),
          error: (e, _) => const _EmptyState(
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
                    : 'No open incidents — all clear!',
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
                        role: 'landlord',
                        currentUserId: widget.profile.id,
                        isHighlighted: deepId == incident.id,
                        onAction: (action) =>
                            _handleAction(incident.id, action),
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

  Future<void> _handleAction(String id, String action) async {
    final notifier = ref.read(incidentActionsProvider.notifier);
    if (action == 'approve_incident') {
      await notifier.approveIncident(id);
    } else if (action == 'approve_quote') {
      await notifier.approveQuote(id);
    }

    final state = ref.read(incidentActionsProvider);
    if (state.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: AppTheme.darkBg,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------

  Widget _tenanciesList(AsyncValue<List<Tenancy>> tenanciesAsync) {
    return tenanciesAsync.when(
      loading: () => const _LoadingState(),
      error: (e, _) => const _EmptyState(
        icon: Icons.error_outline,
        message: 'Failed to load properties.',
      ),
      data: (tenancies) {
        if (tenancies.isEmpty) {
          return LandlordOnboardingCard(
            onAddProperty: () => showAddTenancySheet(context),
          );
        }
        final deepId = ref.watch(deepLinkTenancyIdProvider);
        return Column(
          children: tenancies
              .map((t) {
                final key = _tenancyKeys.putIfAbsent(
                    t.tenancyId, () => GlobalKey());
                return Padding(
                  key: key,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TenancyCard(
                    tenancy: t,
                    canUploadDocs: true,
                    canManageListing: true,
                    landlordProfile: widget.profile,
                    autoExpand: deepId == t.tenancyId,
                    onDelete: () => _deleteTenancy(t.tenancyId),
                  ),
                );
              })
              .toList(),
        );
      },
    );
  }

  Future<void> _deleteTenancy(String tenancyGroupId) async {
    final ok = await ref
        .read(deleteTenancyProvider.notifier)
        .delete(tenancyGroupId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete tenancy.'),
          backgroundColor: AppTheme.darkBg,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------

  Widget _statsRow(
    AsyncValue<List<Tenancy>> tenanciesAsync,
    AsyncValue<List<Incident>> incidentsAsync,
  ) {
    final tenancies = tenanciesAsync.valueOrNull ?? [];
    final totalTenants =
        tenancies.fold<int>(0, (sum, t) => sum + t.tenants.length);
    final openIncidents = (incidentsAsync.valueOrNull ?? [])
        .where((i) => i.status != 'completed')
        .length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            value: '${tenancies.length}',
            label: 'Properties',
            description: 'Managed',
            color: AppTheme.landlordGlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$totalTenants',
            label: 'Tenants',
            description: 'Total',
            color: AppTheme.tenantGlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$openIncidents',
            label: 'Open',
            description: 'Incidents',
            color: AppTheme.contractorGlow,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section components

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? action;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SectionHeaderTitle(icon: icon, title: title),
        if (action != null) ...[
          const Spacer(),
          action!,
        ],
      ],
    );
  }
}

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

// ---------------------------------------------------------------------------
// Pill toggle

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
          _TogglePill(
            label: leftLabel,
            active: !showRight,
            onTap: () => onToggle(false),
          ),
          _TogglePill(
            label: rightLabel,
            active: showRight,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TogglePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

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
          border: active
              ? Border.all(color: AppTheme.border, width: 0.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color:
                active ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading + empty states

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

  const _EmptyState({
    required this.icon,
    required this.message,
  });

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
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Compliance banner

class _ComplianceBanner extends StatelessWidget {
  final AsyncValue<ComplianceSummary> summaryAsync;
  const _ComplianceBanner({required this.summaryAsync});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (!summary.hasAlerts) return const SizedBox.shrink();

        final hasExpired = summary.expired > 0;
        final color = hasExpired ? Colors.red : const Color(0xFFE65100);
        final bg = hasExpired
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF3E0);

        String message;
        if (summary.expired > 0 && summary.expiringSoon > 0) {
          message =
              '${summary.expired} expired · ${summary.expiringSoon} expiring soon';
        } else if (summary.expired > 0) {
          message = summary.expired == 1
              ? '1 compliance document has expired'
              : '${summary.expired} compliance documents have expired';
        } else {
          message = summary.expiringSoon == 1
              ? '1 compliance document expiring within 60 days'
              : '${summary.expiringSoon} compliance documents expiring soon';
        }

        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: color.withValues(alpha: 0.3), width: 1.0),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compliance Alert',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      message,
                      style: TextStyle(
                          fontSize: 12, color: color.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: color),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Previous tenancies section

class _PreviousTenanciesSection extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _PreviousTenanciesSection({required this.profile});

  @override
  ConsumerState<_PreviousTenanciesSection> createState() =>
      _PreviousTenanciesSectionState();
}

class _PreviousTenanciesSectionState
    extends ConsumerState<_PreviousTenanciesSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final endedAsync = ref.watch(endedTenanciesProvider);

    // Hide entire section if no ended tenancies
    if (endedAsync is AsyncData && (endedAsync.value ?? []).isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_outlined,
                    size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Previous Tenancies',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                endedAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => list.isEmpty
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${list.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: endedAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                            color: AppTheme.green),
                      ),
                    ),
                    error: (_, __) => const _EmptyState(
                      icon: Icons.error_outline,
                      message: 'Failed to load previous tenancies.',
                    ),
                    data: (tenancies) {
                      if (tenancies.isEmpty) {
                        return const _EmptyState(
                          icon: Icons.history_outlined,
                          message: 'No previous tenancies.',
                        );
                      }
                      return Column(
                        children: tenancies
                            .map((t) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 12),
                                  child: TenancyCard(
                                    tenancy: t,
                                    canUploadDocs: false,
                                    canManageListing: false,
                                    landlordProfile: widget.profile,
                                    onDelete: null,
                                  ),
                                ))
                            .toList(),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
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
              color: AppTheme.landlordBg,
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
                    color: AppTheme.landlordBg,
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
