import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/agent_providers.dart';

class AgentPeopleScreen extends ConsumerStatefulWidget {
  const AgentPeopleScreen({super.key});

  @override
  ConsumerState<AgentPeopleScreen> createState() => _AgentPeopleScreenState();
}

class _AgentPeopleScreenState extends ConsumerState<AgentPeopleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((p) {
      final name = (p['full_name'] as String? ?? '').toLowerCase();
      final email = (p['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final landlordAsync = ref.watch(agentLandlordsProvider);
    final tenantAsync = ref.watch(agentTenantsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('People'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.agentColor,
          labelColor: AppTheme.agentColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(
              text: landlordAsync.maybeWhen(
                data: (l) => 'Landlords (${l.length})',
                orElse: () => 'Landlords',
              ),
            ),
            Tab(
              text: tenantAsync.maybeWhen(
                data: (t) => 'Tenants (${t.length})',
                orElse: () => 'Tenants',
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by name or email…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          // ── Tabs ────────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Landlords tab
                landlordAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (all) {
                    final filtered = _filter(all);
                    if (filtered.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.business_outlined,
                        message: 'No landlords found',
                      );
                    }
                    return RefreshIndicator(
                      color: AppTheme.agentColor,
                      onRefresh: () async =>
                          ref.invalidate(agentLandlordsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _PersonTile(
                          person: filtered[i],
                          role: 'landlord',
                        ),
                      ),
                    );
                  },
                ),
                // Tenants tab
                tenantAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(message: e.toString()),
                  data: (all) {
                    final filtered = _filter(all);
                    if (filtered.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.person_outline,
                        message: 'No tenants found',
                      );
                    }
                    return RefreshIndicator(
                      color: AppTheme.agentColor,
                      onRefresh: () async =>
                          ref.invalidate(agentTenantsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _PersonTile(
                          person: filtered[i],
                          role: 'tenant',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Map<String, dynamic> person;
  final String role;

  const _PersonTile({required this.person, required this.role});

  @override
  Widget build(BuildContext context) {
    final name = person['full_name'] as String? ?? 'Unknown';
    final email = person['email'] as String? ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    final roleColor = AppTheme.roleColor(role);

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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: roleColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              role[0].toUpperCase() + role.substring(1),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style:
            Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
