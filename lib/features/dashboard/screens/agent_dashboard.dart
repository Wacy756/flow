import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/agent_providers.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/stat_card.dart';
import 'agent_compliance_screen.dart';
import 'agent_incidents_screen.dart';
import 'agent_people_screen.dart';
import 'agent_tenancies_screen.dart';

class AgentDashboard extends ConsumerWidget {
  const AgentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(agentStatsProvider);
    final recentAsync = ref.watch(agentRecentIncidentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Agent Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.agentColor,
        onRefresh: () async {
          ref.invalidate(agentStatsProvider);
          ref.invalidate(agentRecentIncidentsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome header ──────────────────────────────────────────
              profileAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => _WelcomeHeader(
                  name: profile?.fullName ?? 'Agent',
                ),
              ),
              const SizedBox(height: 24),

              // ── Stats grid ───────────────────────────────────────────────
              statsAsync.when(
                loading: () => const _StatsLoading(),
                error: (e, _) => _ErrorBanner(message: e.toString()),
                data: (stats) => _StatsGrid(stats: stats),
              ),
              const SizedBox(height: 28),

              // ── Navigation cards ─────────────────────────────────────────
              Text(
                'MANAGE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 12),
              _NavGrid(
                items: [
                  _NavItem(
                    icon: Icons.home_work_outlined,
                    label: 'Tenancies',
                    color: AppTheme.landlordColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentTenanciesScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.build_outlined,
                    label: 'Incidents',
                    color: AppTheme.contractorColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentIncidentsScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.people_outline,
                    label: 'People',
                    color: AppTheme.tenantColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentPeopleScreen()),
                    ),
                  ),
                  _NavItem(
                    icon: Icons.verified_outlined,
                    label: 'Compliance',
                    color: AppTheme.agentColor,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentComplianceScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Recent incidents ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT INCIDENTS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AgentIncidentsScreen()),
                    ),
                    child: const Text('View all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              recentAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => _ErrorBanner(message: e.toString()),
                data: (incidents) {
                  if (incidents.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.check_circle_outline,
                      message: 'No incidents yet',
                    );
                  }
                  return Column(
                    children: incidents
                        .map((i) => _RecentIncidentTile(incident: i))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Welcome header ──────────────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final String name;
  const _WelcomeHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              Text(
                name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.agentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.agentColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined,
                  size: 14, color: AppTheme.agentColor),
              const SizedBox(width: 6),
              Text(
                'Agent',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.agentColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats grid ──────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          value: '${stats['tenancies'] ?? 0}',
          label: 'Active Tenancies',
          description: 'Across all landlords',
          color: AppTheme.landlordColor,
        ),
        StatCard(
          value: '${stats['open_incidents'] ?? 0}',
          label: 'Open Incidents',
          description: 'Awaiting resolution',
          color: AppTheme.contractorColor,
        ),
        StatCard(
          value: '${stats['tenants'] ?? 0}',
          label: 'Tenants',
          description: 'Registered on Flow',
          color: AppTheme.tenantColor,
        ),
        StatCard(
          value: '${stats['landlords'] ?? 0}',
          label: 'Landlords',
          description: 'Registered on Flow',
          color: AppTheme.agentColor,
        ),
      ],
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav grid ─────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _NavGrid extends StatelessWidget {
  final List<_NavItem> items;
  const _NavGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: items.map((item) => _NavCard(item: item)).toList(),
    );
  }
}

class _NavCard extends StatelessWidget {
  final _NavItem item;
  const _NavCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Recent incident tile ──────────────────────────────────────────────────────

class _RecentIncidentTile extends StatelessWidget {
  final dynamic incident;
  const _RecentIncidentTile({required this.incident});

  Color _statusColor(String status) => switch (status) {
        'reported' => AppTheme.info,
        'approved' => AppTheme.warning,
        'quoted' => const Color(0xFF8B5CF6),
        'in_progress' => AppTheme.contractorColor,
        'completed' => AppTheme.success,
        _ => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final status = incident.status as String;
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incident.title as String,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((incident.propertyAddress as String?) != null)
                  Text(
                    incident.propertyAddress as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
