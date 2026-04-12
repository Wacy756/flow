import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/add_tenancy_sheet.dart';
import '../widgets/incident_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final tenanciesAsync = ref.watch(landlordTenanciesProvider);
    final incidentsAsync = ref.watch(landlordIncidentsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(landlordTenanciesProvider);
        ref.invalidate(landlordIncidentsProvider);
      },
      child: CustomScrollView(
        slivers: [
          // ----------------------------------------------------------------
          // App bar
          // ----------------------------------------------------------------
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
                  await _supabaseSignOut(context);
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
                // ----------------------------------------------------------------
                // Welcome header
                // ----------------------------------------------------------------
                _WelcomeHeader(profile: widget.profile),
                const SizedBox(height: 24),

                // ----------------------------------------------------------------
                // Incidents section
                // ----------------------------------------------------------------
                _incidentsSection(incidentsAsync),
                const SizedBox(height: 28),

                // ----------------------------------------------------------------
                // Properties header + Add button
                // ----------------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 18, color: AppTheme.landlordColor),
                        const SizedBox(width: 6),
                        Text('Your Properties',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => showAddTenancySheet(context),
                      icon: const Icon(Icons.add, size: 16,
                          color: Colors.white),
                      label: const Text('Add Tenancy',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.landlordColor,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ----------------------------------------------------------------
                // Tenancy list
                // ----------------------------------------------------------------
                _tenanciesList(tenanciesAsync),
                const SizedBox(height: 28),

                // ----------------------------------------------------------------
                // Stats
                // ----------------------------------------------------------------
                _statsRow(tenanciesAsync),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Incidents
  // ---------------------------------------------------------------------------

  Widget _incidentsSection(AsyncValue<List<Incident>> incidentsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFF97316)),
                const SizedBox(width: 6),
                Text(
                  _showArchive
                      ? 'Previous Incidents'
                      : 'Property Incidents',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _showArchive = !_showArchive),
              child: Text(_showArchive
                  ? 'View Active'
                  : 'View Previous'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        incidentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) =>
              _emptyState('Failed to load incidents', icon: Icons.error_outline),
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
                    : 'No open incidents — everything looks good!',
                icon: Icons.check_circle_outline,
              );
            }

            return Column(
              children: filtered
                  .map((incident) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: IncidentCard(
                          incident: incident,
                          role: 'landlord',
                          onAction: (action) =>
                              _handleAction(incident.id, action),
                        ),
                      ))
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
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Tenancies list
  // ---------------------------------------------------------------------------

  Widget _tenanciesList(AsyncValue<List<Tenancy>> tenanciesAsync) {
    return tenanciesAsync.when(
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) =>
          _emptyState('Failed to load properties', icon: Icons.error_outline),
      data: (tenancies) {
        if (tenancies.isEmpty) {
          return _emptyState(
            "No properties yet. Tap 'Add Tenancy' to get started.",
            icon: Icons.business_outlined,
          );
        }
        return Column(
          children: tenancies
              .map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TenancyCard(
                      tenancy: t,
                      canUploadDocs: true,
                      onDelete: () => _deleteTenancy(t.tenancyId),
                    ),
                  ))
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  Widget _statsRow(AsyncValue<List<Tenancy>> tenanciesAsync) {
    final tenancies = tenanciesAsync.valueOrNull ?? [];
    final totalTenants = tenancies.fold<int>(
        0, (sum, t) => sum + t.tenants.length);

    return Row(
      children: [
        Expanded(
          child: StatCard(
            value: '${tenancies.length}',
            label: 'Properties',
            description: 'Managed properties',
            color: AppTheme.landlordColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '$totalTenants',
            label: 'Tenants',
            description: 'Total tenants',
            color: AppTheme.tenantColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            value: '0',
            label: 'Tasks',
            description: 'Pending tasks',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  Future<void> _supabaseSignOut(BuildContext context) async {
    await supabase.auth.signOut();
    if (context.mounted) context.go(AppRoutes.landing);
  }
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
            child: const Icon(Icons.business_outlined,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${profile.fullName}!',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
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
