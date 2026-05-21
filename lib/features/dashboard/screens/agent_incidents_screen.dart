import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/incident.dart';
import '../providers/agent_providers.dart';

class AgentIncidentsScreen extends ConsumerStatefulWidget {
  const AgentIncidentsScreen({super.key});

  @override
  ConsumerState<AgentIncidentsScreen> createState() =>
      _AgentIncidentsScreenState();
}

class _AgentIncidentsScreenState
    extends ConsumerState<AgentIncidentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    ('All', null),
    ('Reported', 'reported'),
    ('Approved', 'approved'),
    ('In Progress', 'in_progress'),
    ('Completed', 'completed'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidentsAsync = ref.watch(agentAllIncidentsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: incidentsAsync.maybeWhen(
          data: (list) => Text('All Incidents (${list.length})'),
          orElse: () => const Text('All Incidents'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.agentColor,
          labelColor: AppTheme.agentColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabAlignment: TabAlignment.start,
          tabs: _tabs
              .map((t) => Tab(text: t.$1))
              .toList(),
        ),
      ),
      body: incidentsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e.toString(),
            style: TextStyle(color: AppTheme.error),
          ),
        ),
        data: (incidents) => TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            final filtered = tab.$2 == null
                ? incidents
                : incidents
                    .where((i) => i.status == tab.$2)
                    .toList();
            return _IncidentList(
              incidents: filtered,
              onRefresh: () =>
                  ref.invalidate(agentAllIncidentsProvider),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _IncidentList extends StatelessWidget {
  final List<Incident> incidents;
  final VoidCallback onRefresh;

  const _IncidentList({
    required this.incidents,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (incidents.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_circle_outlined, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text(
              'No incidents in this category',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.agentColor,
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: incidents.length,
        itemBuilder: (_, i) => _AgentIncidentCard(incident: incidents[i]),
      ),
    );
  }
}

class _AgentIncidentCard extends StatelessWidget {
  final Incident incident;
  const _AgentIncidentCard({required this.incident});

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
    final statusColor = _statusColor(incident.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.title,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (incident.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            incident.description,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                    status: incident.status, color: statusColor),
              ],
            ),
          ),
          // Footer meta
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Row(
              children: [
                if (incident.propertyAddress != null) ...[
                  Icon(Icons.location_on_outlined,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${incident.propertyAddress}'
                      '${incident.propertyPostcode != null ? ', ${incident.propertyPostcode}' : ''}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Expanded(child: SizedBox.shrink()),
                if (incident.tenantName != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.person_outline,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    incident.tenantName!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  _formatDate(incident.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
