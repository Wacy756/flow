import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/create_incident_sheet.dart';
import '../widgets/incident_card.dart';
import '../widgets/stat_card.dart';

class TenantDashboard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const TenantDashboard({super.key, required this.profile});

  @override
  ConsumerState<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends ConsumerState<TenantDashboard> {
  bool _showArchive = false;

  @override
  Widget build(BuildContext context) {
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    final incidentsAsync = ref.watch(tenantIncidentsProvider);
    final userId = supabase.auth.currentUser?.id ?? '';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(tenantTenanciesProvider);
        ref.invalidate(tenantIncidentsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppTheme.surface,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Center(
                    child: Text('F',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Flow',
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontSize: 20)),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await supabase.auth.signOut();
                  if (context.mounted) context.go(AppRoutes.landing);
                },
                icon: const Icon(Icons.logout_rounded,
                    size: 16, color: AppTheme.textSecondary),
                label: const Text('Sign Out',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Welcome header
                _WelcomeHeader(profile: widget.profile),
                const SizedBox(height: 24),

                // Pending invitations
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
                        _sectionHeader(
                            context,
                            Icons.mail_outline_rounded,
                            'Pending Invitations',
                            const Color(0xFF2563EB)),
                        const SizedBox(height: 8),
                        ...pending.map(
                            (t) => _InvitationCard(tenancy: t)),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),

                // Incidents section
                _incidentsSection(context, incidentsAsync, userId),
                const SizedBox(height: 28),

                // Active properties
                _sectionHeader(
                    context,
                    Icons.home_outlined,
                    'My Properties',
                    AppTheme.tenantColor),
                const SizedBox(height: 12),
                tenanciesAsync.when(
                  loading: () => _loading(),
                  error: (e, _) =>
                      _emptyState('Failed to load properties',
                          icon: Icons.error_outline),
                  data: (tenancies) {
                    final active = tenancies
                        .where((t) => t.status == 'active')
                        .toList();
                    if (active.isEmpty) {
                      return _emptyState(
                          'No active tenancies yet.',
                          icon: Icons.home_outlined);
                    }
                    return Column(
                      children: active
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _TenancyInfoCard(tenancy: t),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Stats
                _statsRow(tenanciesAsync, incidentsAsync),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidentsSection(
      BuildContext context,
      AsyncValue<List<Incident>> incidentsAsync,
      String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader(
                context,
                Icons.warning_amber_rounded,
                _showArchive ? 'Previous Incidents' : 'My Incidents',
                const Color(0xFFF97316)),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _showArchive = !_showArchive),
                  child: Text(
                      _showArchive ? 'View Active' : 'View Previous'),
                ),
                const SizedBox(width: 4),
                // Create incident button
                incidentsAsync.whenOrNull(
                  data: (_) => _tenanciesForCreate(),
                ) ??
                    const SizedBox.shrink(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        incidentsAsync.when(
          loading: () => _loading(),
          error: (_, __) =>
              _emptyState('Failed to load incidents',
                  icon: Icons.error_outline),
          data: (incidents) {
            final filtered = incidents
                .where((i) => _showArchive
                    ? i.status == 'completed'
                    : i.status != 'completed')
                .toList();
            if (filtered.isEmpty) {
              return _emptyState(
                _showArchive
                    ? 'No previous incidents'
                    : 'No open incidents.',
                icon: _showArchive
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
              );
            }
            return Column(
              children: filtered
                  .map((incident) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IncidentCard(
                          incident: incident,
                          role: 'tenant',
                          currentUserId: userId,
                          onAction: (action) =>
                              _handleTenantAction(incident.id, action),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _tenanciesForCreate() {
    final tenanciesAsync = ref.watch(tenantTenanciesProvider);
    final active = tenanciesAsync.valueOrNull
            ?.where((t) => t.status == 'active')
            .toList() ??
        [];
    if (active.isEmpty) return const SizedBox.shrink();
    return ElevatedButton.icon(
      onPressed: () =>
          showCreateIncidentSheet(context, activeTenancies: active),
      icon: const Icon(Icons.add, size: 14, color: Colors.white),
      label: const Text('Report',
          style: TextStyle(color: Colors.white, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF97316),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _statsRow(
      AsyncValue<List<Tenancy>> tenanciesAsync, AsyncValue<List<Incident>> incidentsAsync) {
    final active = (tenanciesAsync.valueOrNull as List<Tenancy>? ?? [])
        .where((t) => t.status == 'active')
        .length;
    final openIncidents = (incidentsAsync.valueOrNull as List? ?? [])
        .where((i) => i.status != 'completed')
        .length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            value: '$active',
            label: 'Properties',
            description: 'Active tenancies',
            color: AppTheme.tenantColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$openIncidents',
            label: 'Incidents',
            description: 'Open issues',
            color: const Color(0xFFF97316),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(
          BuildContext context, IconData icon, String title, Color color) =>
      Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(title,
              style: Theme.of(context).textTheme.headlineMedium),
        ],
      );

  Widget _loading() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );

  Widget _emptyState(String msg, {required IconData icon}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 10),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Welcome header
// ---------------------------------------------------------------------------

class _WelcomeHeader extends StatelessWidget {
  final UserProfile profile;
  const _WelcomeHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.roleGradient(profile.role);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_outline,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${profile.fullName}!',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (profile.email != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.email!,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
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
// Pending invitation card
// ---------------------------------------------------------------------------

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
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined,
              size: 22, color: Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenancy.shortAddress,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (tenancy.landlord?.fullName != null)
                  Text(
                    'From: ${tenancy.landlord!.fullName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
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
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Accept',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tenancy info card (active view for tenant)
// ---------------------------------------------------------------------------

class _TenancyInfoCard extends StatelessWidget {
  final Tenancy tenancy;
  const _TenancyInfoCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.roleGradient('tenant'),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.home_outlined,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tenancy.addressLine1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(tenancy.postcode,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12)),
                  ],
                ),
              ),
              _StatusPill(status: tenancy.status),
            ],
          ),
          if (tenancy.landlord?.fullName != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text('Landlord: ${tenancy.landlord!.fullName}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
          if (tenancy.monthlyRent != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                    '£${tenancy.monthlyRent!.toStringAsFixed(0)}/month',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isActive
              ? const Color(0xFF16A34A)
              : const Color(0xFFEA580C),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
