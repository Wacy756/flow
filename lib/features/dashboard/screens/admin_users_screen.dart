import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_providers.dart';
import 'admin_theme.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _filter = 'all';
  String _query  = '';
  final _searchCtrl = TextEditingController();
  static const _roles = ['all', 'landlord', 'tenant', 'contractor', 'agent'];

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminAllUsersProvider);

    return Theme(
      data: AP.appBarTheme(context),
      child: Scaffold(
        backgroundColor: AP.bg,
        appBar: AppBar(
          title: const Text('Users'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AP.el)),
        ),
        body: AdminConstraint(child: Column(children: [

          // ── Search ───────────────────────────────────────────────────────
          Container(
            color: AP.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AP.text, fontSize: 14),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search name or email…',
                hintStyle: const TextStyle(color: AP.muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AP.muted, size: 18),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
                        child: const Icon(Icons.clear_rounded, color: AP.muted, size: 16))
                    : null,
                filled: true,
                fillColor: AP.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AP.el)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AP.el)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AP.accent.withValues(alpha: 0.5), width: 1.5)),
              ),
            ),
          ),

          // ── Filter chips ──────────────────────────────────────────────────
          Container(
            color: AP.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roles.map((role) {
                  final active = _filter == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = role),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AP.accent : AP.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AP.accent
                                : AP.el),
                        ),
                        child: Text(
                          _label(role),
                          style: TextStyle(
                            color: active ? Colors.white : AP.sub,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AP.accent,
              backgroundColor: AP.card,
              onRefresh: () async => ref.invalidate(adminAllUsersProvider),
              child: usersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AP.accent, strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                    style: const TextStyle(color: AP.sub))),
                data: (users) {
                  var filtered = _filter == 'all'
                      ? users
                      : users.where((u) => u['role'] == _filter).toList();
                  if (_query.isNotEmpty) {
                    filtered = filtered.where((u) {
                      final name  = (u['full_name'] as String? ?? '').toLowerCase();
                      final email = (u['email']     as String? ?? '').toLowerCase();
                      return name.contains(_query) || email.contains(_query);
                    }).toList();
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('No ${_label(_filter).toLowerCase()} found.',
                        style: const TextStyle(color: AP.sub)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Container(
                      height: 1, color: AP.el,
                      margin: const EdgeInsets.only(left: 66)),
                    itemBuilder: (_, i) => _UserRow(data: filtered[i]),
                  );
                },
              ),
            ),
          ),
        ])),
      ),
    );
  }

  String _label(String role) => switch (role) {
    'all'         => 'All',
    'landlord'    => 'Landlords',
    'tenant'      => 'Tenants',
    'contractor'  => 'Contractors',
    'agent'       => 'Agents',
    _             => role,
  };
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _UserRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final name      = data['full_name'] as String? ?? '—';
    final email     = data['email']    as String? ?? '—';
    final role      = data['role']     as String? ?? 'unknown';
    final isAdmin   = data['is_admin'] as bool? ?? false;
    final onboarded = data['onboarding_completed'] as bool? ?? false;
    final createdAt = data['created_at'] as String?;
    final joined    = createdAt != null
        ? _fmt(DateTime.tryParse(createdAt))
        : '—';
    final roleColor = _roleColor(role);
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      color: AP.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
          child: Center(
            child: Text(initial,
              style: TextStyle(
                color: roleColor, fontSize: 17, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AP.text, fontSize: 14, fontWeight: FontWeight.w700))),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AP.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4)),
                  child: const Text('ADMIN',
                    style: TextStyle(
                      color: AP.accent, fontSize: 8,
                      fontWeight: FontWeight.w800))),
              ],
            ]),
            const SizedBox(height: 2),
            Text(email,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AP.sub, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_roleLabel(role),
              style: TextStyle(
                color: roleColor, fontSize: 10,
                fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(joined,
            style: const TextStyle(color: AP.muted, fontSize: 10)),
          if (!onboarded)
            const Text('Not onboarded',
              style: TextStyle(
                color: AP.amber, fontSize: 10,
                fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  Color _roleColor(String role) => switch (role) {
    'landlord'   => AP.blue,
    'tenant'     => AP.green,
    'contractor' => AP.accent,
    'agent'      => const Color(0xFFA855F7),
    _            => AP.muted,
  };

  String _roleLabel(String role) => switch (role) {
    'landlord'   => 'Landlord',
    'tenant'     => 'Tenant',
    'contractor' => 'Contractor',
    'agent'      => 'Agent',
    _            => role,
  };

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
