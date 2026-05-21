import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/tenancy.dart';
import '../providers/agent_providers.dart';
import '../widgets/tenancy_card.dart';

class AgentTenanciesScreen extends ConsumerStatefulWidget {
  const AgentTenanciesScreen({super.key});

  @override
  ConsumerState<AgentTenanciesScreen> createState() =>
      _AgentTenanciesScreenState();
}

class _AgentTenanciesScreenState extends ConsumerState<AgentTenanciesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Tenancy> _filter(List<Tenancy> all) {
    return all.where((t) {
      final matchesStatus =
          _statusFilter == 'all' || t.status == _statusFilter;
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty ||
          t.addressLine1.toLowerCase().contains(q) ||
          t.postcode.toLowerCase().contains(q) ||
          t.tenants.any((p) =>
              (p.fullName ?? '').toLowerCase().contains(q) ||
              (p.email ?? '').toLowerCase().contains(q));
      return matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tenanciesAsync = ref.watch(agentAllTenanciesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: tenanciesAsync.maybeWhen(
          data: (t) => Text('All Tenancies (${t.length})'),
          orElse: () => const Text('All Tenancies'),
        ),
      ),
      body: Column(
        children: [
          // ── Search + filter bar ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by address or tenant…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _statusFilter == 'all',
                        onTap: () => setState(() => _statusFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Active',
                        selected: _statusFilter == 'active',
                        onTap: () => setState(() => _statusFilter = 'active'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending',
                        selected: _statusFilter == 'pending',
                        onTap: () => setState(() => _statusFilter = 'pending'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: tenanciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(message: e.toString()),
              data: (all) {
                final filtered = _filter(all);
                if (filtered.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.home_work_outlined,
                    message: 'No tenancies match your search',
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.agentColor,
                  onRefresh: () async =>
                      ref.invalidate(agentAllTenanciesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => TenancyCard(
                      tenancy: filtered[i],
                      canUploadDocs: true,
                      onDelete: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.agentColor
              : AppTheme.agentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppTheme.agentColor
                : AppTheme.agentColor.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : AppTheme.agentColor,
                fontWeight: FontWeight.w600,
              ),
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppTheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
