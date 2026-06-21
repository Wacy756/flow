import 'package:flow_app/core/widgets/abode_toast.dart';
import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/contractor_document.dart';
import '../providers/dashboard_providers.dart';
import 'admin_theme.dart';

class ContractorAdminScreen extends ConsumerStatefulWidget {
  const ContractorAdminScreen({super.key});

  @override
  ConsumerState<ContractorAdminScreen> createState() =>
      _ContractorAdminScreenState();
}

class _ContractorAdminScreenState extends ConsumerState<ContractorAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = ['Pending', 'Approved', 'Rejected', 'All', 'Invited'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> all, String status) {
    if (status == 'all') return all;
    return all
        .where((r) => (r['verification_status'] as String?) == status)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(adminAllContractorsProvider);
    final invitesAsync = ref.watch(adminContractorInvitesProvider);

    return Theme(
      data: AP.appBarTheme(context),
      child: Scaffold(
        backgroundColor: AP.bg,
        appBar: AppBar(
          title: const Text('Contractor Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Invite contractor',
              onPressed: () => _showInviteModal(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AP.accent,
            labelColor: AP.accent,
            unselectedLabelColor: AP.sub,
            labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
            tabs: _tabLabels
                .map((l) => Tab(text: l))
                .toList(),
          ),
        ),
        body: AdminConstraint(
          child: TabBarView(
            controller: _tabs,
            children: [
              // Pending
              _ContractorList(
                asyncValue: allAsync,
                filter: (all) => _filter(all, 'pending_review'),
                emptyMessage: 'No pending applications',
                emptyIcon: Icons.task_alt_rounded,
              ),
              // Approved
              _ContractorList(
                asyncValue: allAsync,
                filter: (all) => _filter(all, 'approved'),
                emptyMessage: 'No approved contractors yet',
                emptyIcon: Icons.check_circle_outline_rounded,
              ),
              // Rejected
              _ContractorList(
                asyncValue: allAsync,
                filter: (all) => _filter(all, 'rejected'),
                emptyMessage: 'No rejected applications',
                emptyIcon: Icons.cancel_outlined,
              ),
              // All
              _ContractorList(
                asyncValue: allAsync,
                filter: (all) => all,
                emptyMessage: 'No contractors yet',
                emptyIcon: Icons.people_outline_rounded,
              ),
              // Invited
              _InviteList(asyncValue: invitesAsync),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteModal(BuildContext context) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        onInvited: () {
          ref.invalidate(adminContractorInvitesProvider);
        },
      ),
    );
  }
}

// ─── Contractor list (filtered) ───────────────────────────────────────────────

class _ContractorList extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> asyncValue;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) filter;
  final String emptyMessage;
  final IconData emptyIcon;

  const _ContractorList({
    required this.asyncValue,
    required this.filter,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AP.accent,
      backgroundColor: AP.card,
      onRefresh: () async => ref.invalidate(adminAllContractorsProvider),
      child: asyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AP.accent, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text('Error: $e',
            style: const TextStyle(color: AP.sub))),
        data: (all) {
          final contractors = filter(all);
          if (contractors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AP.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                    child: Icon(emptyIcon, color: AP.green, size: 32)),
                  const SizedBox(height: 16),
                  Text(emptyMessage,
                    style: const TextStyle(
                      color: AP.text, fontSize: 16,
                      fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: contractors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) =>
                _ContractorCard(data: contractors[i]),
          );
        },
      ),
    );
  }
}

// ─── Invite list ──────────────────────────────────────────────────────────────

class _InviteList extends ConsumerWidget {
  final AsyncValue<List<Map<String, dynamic>>> asyncValue;
  const _InviteList({required this.asyncValue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AP.accent,
      backgroundColor: AP.card,
      onRefresh: () async => ref.invalidate(adminContractorInvitesProvider),
      child: asyncValue.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AP.accent, strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text('Error: $e',
            style: const TextStyle(color: AP.sub))),
        data: (invites) {
          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AP.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                    child: const Icon(Icons.mail_outline_rounded,
                      color: AP.accent, size: 32)),
                  const SizedBox(height: 16),
                  const Text('No invites sent yet',
                    style: TextStyle(
                      color: AP.text, fontSize: 16,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Tap the + icon to invite a contractor',
                    style: TextStyle(color: AP.sub, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _InviteCard(data: invites[i]),
          );
        },
      ),
    );
  }
}

// ─── Contractor card ──────────────────────────────────────────────────────────

class _ContractorCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ContractorCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final contractor = data['contractor'] as Map<String, dynamic>? ?? {};
    final name       = contractor['full_name'] as String? ?? 'Unknown';
    final email      = contractor['email']     as String? ?? '';
    final rawWork    = data['work_types'];
    final workTypes  = rawWork is List
        ? rawWork.map((e) => e.toString()).toList()
        : <String>[];
    final status = data['verification_status'] as String? ?? 'unverified';

    return GestureDetector(
      onTap: () => showAdaptiveSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ContractorDetailSheet(data: data)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AP.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AP.cardBorder),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AP.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AP.accent, fontSize: 18,
                  fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: const TextStyle(
                    color: AP.text, fontSize: 15,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email,
                  style: const TextStyle(color: AP.sub, fontSize: 12)),
                if (workTypes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4, runSpacing: 4,
                    children: workTypes.take(3).map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AP.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t,
                        style: const TextStyle(
                          color: AP.accent, fontSize: 10,
                          fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: status),
        ]),
      ),
    );
  }
}

// ─── Invite card ──────────────────────────────────────────────────────────────

class _InviteCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _InviteCard({required this.data});

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final email       = widget.data['email']     as String? ?? '';
    final name        = widget.data['contractor_name'] as String?;
    final acceptedAt  = widget.data['accepted_at'];
    final expiresAt   = widget.data['expires_at'] as String?;
    final isAccepted  = acceptedAt != null;
    final isExpired   = expiresAt != null &&
        DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AP.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AP.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (isAccepted ? AP.green : AP.accent).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isAccepted
                ? Icons.check_circle_rounded
                : Icons.mail_outline_rounded,
            color: isAccepted ? AP.green : AP.accent,
            size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name ?? email,
                style: const TextStyle(
                  color: AP.text, fontSize: 15,
                  fontWeight: FontWeight.w700)),
              if (name != null)
                Text(email,
                  style: const TextStyle(color: AP.sub, fontSize: 12)),
              const SizedBox(height: 4),
              _InviteStatusBadge(
                isAccepted: isAccepted, isExpired: isExpired),
            ],
          ),
        ),
        if (!isAccepted && !isExpired)
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(
                text: 'https://app.useabode.co.uk/auth?role=contractor&mode=signup'));
              setState(() => _copied = true);
              await Future.delayed(const Duration(seconds: 2));
              if (mounted) setState(() => _copied = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _copied
                    ? AP.green.withValues(alpha: 0.1)
                    : AP.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _copied ? 'Copied!' : 'Copy link',
                style: TextStyle(
                  color: _copied ? AP.green : AP.accent,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved'      => ('Approved', AP.green),
      'pending_review'=> ('Pending',  AP.amber),
      'rejected'      => ('Rejected', AP.red),
      _               => ('Applied',  AP.sub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          color: color, fontSize: 11,
          fontWeight: FontWeight.w700)),
    );
  }
}

class _InviteStatusBadge extends StatelessWidget {
  final bool isAccepted;
  final bool isExpired;
  const _InviteStatusBadge({
    required this.isAccepted, required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final (label, color) = isAccepted
        ? ('Signed up', AP.green)
        : isExpired
            ? ('Expired', AP.sub)
            : ('Invited · awaiting signup', AP.amber);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(
          color: color, fontSize: 11,
          fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Invite modal ─────────────────────────────────────────────────────────────

class _InviteSheet extends ConsumerStatefulWidget {
  final VoidCallback onInvited;
  const _InviteSheet({required this.onInvited});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _emailController = TextEditingController();
  final List<String> _emails = [];
  String? _fieldError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addEmail() {
    final raw = _emailController.text.trim().toLowerCase();
    if (raw.isEmpty) return;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw)) {
      setState(() => _fieldError = 'Enter a valid email address');
      return;
    }
    if (_emails.contains(raw)) {
      setState(() => _fieldError = 'Already in the list');
      return;
    }
    setState(() {
      _emails.add(raw);
      _fieldError = null;
    });
    _emailController.clear();
  }

  Future<void> _sendAll() async {
    if (_emails.isEmpty) return;
    final notifier = ref.read(adminInviteContractorProvider.notifier);
    int sent = 0;
    for (final email in _emails) {
      final ok = await notifier.invite(email);
      if (ok) sent++;
    }
    widget.onInvited();
    if (mounted) {
      Navigator.of(context).pop();
      showAbodeToast(
        context,
        sent == _emails.length
            ? 'Invites sent to $sent contractor${sent == 1 ? '' : 's'}'
            : '$sent of ${_emails.length} invites sent',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteState = ref.watch(adminInviteContractorProvider);
    final isSending   = inviteState.isLoading;

    return Container(
      decoration: const BoxDecoration(
        color: AP.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
        20, 8, 20,
        20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AP.el,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Text('Invite contractors',
            style: TextStyle(
              color: AP.text, fontSize: 18,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Enter email addresses below. Each person will receive a signup link.',
            style: TextStyle(color: AP.sub, fontSize: 13)),
          const SizedBox(height: 20),

          // Email input row
          Row(children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onSubmitted: (_) => _addEmail(),
                style: const TextStyle(color: AP.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'contractor@example.com',
                  hintStyle: const TextStyle(color: AP.muted, fontSize: 13),
                  errorText: _fieldError,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AP.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AP.el)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AP.el)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AP.accent)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _addEmail,
                style: FilledButton.styleFrom(
                  backgroundColor: AP.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 20),
              ),
            ),
          ]),

          // Email chips
          if (_emails.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _emails.map((e) => Chip(
                label: Text(e,
                  style: const TextStyle(
                    color: AP.text, fontSize: 12)),
                backgroundColor: AP.card,
                side: const BorderSide(color: AP.el),
                deleteIcon: const Icon(Icons.close_rounded,
                  size: 14, color: AP.sub),
                onDeleted: () =>
                    setState(() => _emails.remove(e)),
              )).toList(),
            ),
          ],

          const SizedBox(height: 20),

          FilledButton(
            onPressed: (_emails.isEmpty || isSending) ? null : _sendAll,
            style: FilledButton.styleFrom(
              backgroundColor: AP.accent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
            child: isSending
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : Text(
                    _emails.isEmpty
                        ? 'Add emails above'
                        : 'Send ${_emails.length} invite${_emails.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Contractor detail sheet (unchanged logic, copied from original) ───────────

class _ContractorDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _ContractorDetailSheet({required this.data});
  @override
  ConsumerState<_ContractorDetailSheet> createState() =>
      _ContractorDetailSheetState();
}

class _ContractorDetailSheetState
    extends ConsumerState<_ContractorDetailSheet> {
  final _rejectController = TextEditingController();
  final _companyNumberController = TextEditingController();
  bool _showRejectField = false;
  bool _companyFieldPrepopulated = false;

  bool _gasSafeLoading = false;
  bool? _gasSafeVerified;
  String? _gasSafeResult;

  bool _chLoading = false;
  bool? _chVerified;
  String? _chResult;

  @override
  void dispose() {
    _rejectController.dispose();
    _companyNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contractorId = widget.data['contractor_id'] as String? ?? '';
    final contractor   = widget.data['contractor'] as Map<String, dynamic>? ?? {};

    if (!_companyFieldPrepopulated) {
      final submitted = widget.data['companies_house_number'] as String?;
      if (submitted != null && submitted.isNotEmpty) {
        _companyNumberController.text = submitted;
      }
      _companyFieldPrepopulated = true;
    }

    final name      = contractor['full_name'] as String? ?? 'Unknown';
    final email     = contractor['email']     as String? ?? '';
    final phone     = contractor['phone']     as String?;
    final rawWork   = widget.data['work_types'];
    final workTypes = rawWork is List
        ? rawWork.map((e) => e.toString()).toList()
        : <String>[];
    final status    = widget.data['verification_status'] as String? ?? 'unverified';

    final docsAsync = ref.watch(adminContractorDocsProvider(contractorId));
    final vetState  = ref.watch(adminVetContractorProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AP.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AP.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AP.accent, fontSize: 17,
                      fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(name,
                          style: const TextStyle(
                            color: AP.text, fontSize: 16,
                            fontWeight: FontWeight.w700))),
                      _StatusBadge(status: status),
                    ]),
                    Text(email,
                      style: const TextStyle(
                        color: AP.sub, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          Container(height: 1, color: AP.el),

          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                if (phone?.isNotEmpty == true) ...[
                  _FieldRow(label: 'Phone', value: phone!),
                  const SizedBox(height: 8),
                ],

                if (workTypes.isNotEmpty) ...[
                  const Text('Trade types',
                    style: TextStyle(
                      color: AP.sub, fontSize: 12,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: workTypes.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AP.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AP.accent.withValues(alpha: 0.25)),
                      ),
                      child: Text(t,
                        style: const TextStyle(
                          color: AP.accent, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                const Text('Documents',
                  style: TextStyle(
                    color: AP.sub, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                docsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator(
                      color: AP.accent, strokeWidth: 2))),
                  error: (_, __) => const Text('Failed to load documents',
                    style: TextStyle(color: AP.red, fontSize: 13)),
                  data: (docs) {
                    if (docs.isEmpty) {
                      return const Text('No documents submitted',
                        style: TextStyle(color: AP.muted, fontSize: 13));
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: AP.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AP.el),
                      ),
                      child: Column(
                        children: docs.asMap().entries.map((entry) {
                          final isLast = entry.key == docs.length - 1;
                          return Column(children: [
                            _DocRow(doc: entry.value),
                            if (!isLast)
                              Container(height: 1, color: AP.el,
                                margin: const EdgeInsets.only(left: 54)),
                          ]);
                        }).toList(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                const Text('Verify Credentials',
                  style: TextStyle(
                    color: AP.sub, fontSize: 12,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                if (widget.data['gas_safe_number'] != null) ...[
                  _VerifyRow(
                    label: 'Gas Safe',
                    detail: widget.data['gas_safe_number'] as String,
                    icon: Icons.local_fire_department_outlined,
                    loading: _gasSafeLoading,
                    verified: _gasSafeVerified,
                    resultText: _gasSafeResult,
                    onVerify: () => _verifyGasSafe(
                      contractorId,
                      widget.data['gas_safe_number'] as String,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Container(
                  decoration: BoxDecoration(
                    color: AP.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AP.el),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AP.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.business_outlined,
                            color: AP.blue, size: 16)),
                        const SizedBox(width: 10),
                        const Text('Companies House',
                          style: TextStyle(
                            color: AP.text, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (_chVerified != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (_chVerified!
                                  ? AP.green : AP.red)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              _chVerified! ? 'Active' : 'Not found',
                              style: TextStyle(
                                color: _chVerified! ? AP.green : AP.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      if (_chResult != null) ...[
                        const SizedBox(height: 4),
                        Text(_chResult!,
                          style: const TextStyle(
                            color: AP.sub, fontSize: 11)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _companyNumberController,
                            style: const TextStyle(
                              color: AP.text, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Company number (e.g. 12345678)',
                              hintStyle: const TextStyle(
                                color: AP.muted, fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: AP.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AP.el)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AP.el)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AP.blue)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 38,
                          child: FilledButton(
                            onPressed: _chLoading
                                ? null
                                : () => _verifyCompaniesHouse(contractorId),
                            style: FilledButton.styleFrom(
                              backgroundColor: AP.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16)),
                            child: _chLoading
                                ? const SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                                : const Text('Check',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                if (widget.data['niceic_number'] != null) ...[
                  const SizedBox(height: 8),
                  _ExternalVerifyRow(
                    label: 'NICEIC',
                    number: widget.data['niceic_number'] as String,
                    icon: Icons.electric_bolt_outlined,
                    color: AP.amber,
                    url: 'https://www.niceic.com/find-a-contractor',
                  ),
                ],

                const SizedBox(height: 24),

                if (status != 'approved') ...[
                  if (_showRejectField) ...[
                    TextField(
                      controller: _rejectController,
                      maxLines: 3,
                      style: const TextStyle(color: AP.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Explain why the application was rejected...',
                        hintStyle: const TextStyle(
                          color: AP.muted, fontSize: 13),
                        filled: true,
                        fillColor: AP.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AP.el)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AP.el)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AP.red)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _showRejectField = false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AP.el),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                          child: const Text('Cancel',
                            style: TextStyle(color: AP.sub)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: vetState.isLoading
                              ? null
                              : () => _reject(contractorId),
                          style: FilledButton.styleFrom(
                            backgroundColor: AP.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                          child: Text(
                            vetState.isLoading ? 'Rejecting...' : 'Confirm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  if (!_showRejectField) ...[
                    FilledButton.icon(
                      onPressed: vetState.isLoading
                          ? null
                          : () => _approve(contractorId),
                      icon: vetState.isLoading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline_rounded,
                              size: 18, color: Colors.white),
                      label: Text(
                        vetState.isLoading ? 'Approving...' : 'Approve Application',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AP.green,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: vetState.isLoading
                          ? null
                          : () => setState(() => _showRejectField = true),
                      icon: const Icon(Icons.cancel_outlined,
                        size: 18, color: AP.red),
                      label: const Text('Reject Application',
                        style: TextStyle(
                          color: AP.red, fontSize: 15,
                          fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AP.red.withValues(alpha: 0.35)),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                    ),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AP.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AP.green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check_circle_rounded,
                        color: AP.green, size: 20),
                      SizedBox(width: 10),
                      Text('Contractor is approved and active',
                        style: TextStyle(
                          color: AP.green, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _verifyGasSafe(
      String contractorId, String licenceNumber) async {
    setState(() { _gasSafeLoading = true; _gasSafeResult = null; });
    try {
      final res = await supabase.functions.invoke(
        'verify-gas-safe',
        body: {'licence_number': licenceNumber, 'contractor_id': contractorId},
      );
      final data = res.data as Map<String, dynamic>? ?? {};
      final verified = data['verified'] as bool? ?? false;
      final name     = data['engineerName'] as String?;
      final expiry   = data['expiryDate'] as String?;
      final error    = data['error'] as String?;
      setState(() {
        _gasSafeVerified = verified;
        _gasSafeResult = error ??
            (verified
              ? '${name ?? 'Verified'}${expiry != null ? ' · Expires $expiry' : ''}'
              : 'Not found on register');
      });
    } catch (e) {
      setState(() {
        _gasSafeVerified = false;
        _gasSafeResult = 'Lookup failed — manual review required';
      });
    } finally {
      setState(() => _gasSafeLoading = false);
    }
  }

  Future<void> _verifyCompaniesHouse(String contractorId) async {
    final number = _companyNumberController.text.trim();
    if (number.isEmpty) return;
    setState(() { _chLoading = true; _chResult = null; });
    try {
      final res = await supabase.functions.invoke(
        'verify-companies-house',
        body: {
          'company_number': number,
          'profile_id': contractorId,
          'profile_type': 'contractor',
        },
      );
      final data = res.data as Map<String, dynamic>? ?? {};
      final verified = data['verified'] as bool? ?? false;
      final name   = data['companyName'] as String?;
      final status = data['companyStatus'] as String?;
      final error  = data['error'] as String?;
      setState(() {
        _chVerified = verified;
        _chResult = error ??
            (name != null ? '$name · ${status ?? ''}' : 'Unknown');
      });
    } catch (e) {
      setState(() {
        _chVerified = false;
        _chResult = 'Lookup failed';
      });
    } finally {
      setState(() => _chLoading = false);
    }
  }

  Future<void> _approve(String contractorId) async {
    final ok = await ref
        .read(adminVetContractorProvider.notifier)
        .approve(contractorId);
    if (ok && mounted) {
      ref.invalidate(adminAllContractorsProvider);
      Navigator.of(context).pop();
    }
  }

  Future<void> _reject(String contractorId) async {
    final reason = _rejectController.text.trim();
    if (reason.isEmpty) return;
    final ok = await ref
        .read(adminVetContractorProvider.notifier)
        .reject(contractorId, reason);
    if (ok && mounted) {
      ref.invalidate(adminAllContractorsProvider);
      Navigator.of(context).pop();
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label: ',
      style: const TextStyle(
        color: AP.sub, fontSize: 13, fontWeight: FontWeight.w600)),
    Text(value,
      style: const TextStyle(color: AP.text, fontSize: 13)),
  ]);
}

class _VerifyRow extends StatelessWidget {
  final String label;
  final String detail;
  final IconData icon;
  final bool loading;
  final bool? verified;
  final String? resultText;
  final VoidCallback onVerify;
  const _VerifyRow({
    required this.label,
    required this.detail,
    required this.icon,
    required this.loading,
    required this.verified,
    required this.resultText,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AP.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AP.el),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AP.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AP.green, size: 16)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(
              color: AP.text, fontSize: 13,
              fontWeight: FontWeight.w600)),
          Text(detail,
            style: const TextStyle(color: AP.sub, fontSize: 11)),
          if (resultText != null)
            Text(resultText!,
              style: TextStyle(
                color: verified == true ? AP.green : AP.red,
                fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
      if (verified != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (verified! ? AP.green : AP.red).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20)),
          child: Text(
            verified! ? 'Verified' : 'Failed',
            style: TextStyle(
              color: verified! ? AP.green : AP.red,
              fontSize: 11, fontWeight: FontWeight.w700)),
        )
      else
        SizedBox(
          height: 32,
          child: FilledButton(
            onPressed: loading ? null : onVerify,
            style: FilledButton.styleFrom(
              backgroundColor: AP.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: loading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Text('Verify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
    ]),
  );
}

class _ExternalVerifyRow extends StatelessWidget {
  final String label;
  final String number;
  final IconData icon;
  final Color color;
  final String url;
  const _ExternalVerifyRow({
    required this.label,
    required this.number,
    required this.icon,
    required this.color,
    required this.url,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AP.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AP.el),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
            style: const TextStyle(
              color: AP.text, fontSize: 13,
              fontWeight: FontWeight.w600)),
          Text(number,
            style: const TextStyle(color: AP.sub, fontSize: 11)),
          const Text('Manual check via official website',
            style: TextStyle(color: AP.muted, fontSize: 10)),
        ]),
      ),
      SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          icon: Icon(Icons.open_in_new_rounded, size: 13, color: color),
          label: Text('Check',
            style: TextStyle(
              color: color, fontSize: 12,
              fontWeight: FontWeight.w700)),
          onPressed: () => showAbodeToast(context, 'Open: $url'),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12)),
        ),
      ),
    ]),
  );
}

class _DocRow extends StatelessWidget {
  final ContractorDocument doc;
  const _DocRow({required this.doc});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AP.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.description_outlined,
          color: AP.green, size: 16)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc.docTypeLabel,
              style: const TextStyle(
                color: AP.text, fontSize: 13,
                fontWeight: FontWeight.w600)),
            if (doc.certNumber?.isNotEmpty == true)
              Text('Cert: ${doc.certNumber}',
                style: const TextStyle(color: AP.sub, fontSize: 11)),
            if (doc.expiryDate != null)
              Text(
                'Expires: ${doc.expiryDate!.day}/${doc.expiryDate!.month}/${doc.expiryDate!.year}',
                style: const TextStyle(color: AP.sub, fontSize: 11)),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: doc.status == 'approved'
              ? AP.green.withValues(alpha: 0.1)
              : AP.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          doc.status == 'approved' ? 'Approved' : 'Pending',
          style: TextStyle(
            color: doc.status == 'approved' ? AP.green : AP.amber,
            fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}
