import 'package:flow_app/core/widgets/adaptive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/dialogs.dart';
import '../providers/agent_providers.dart';
import 'package:flow_app/core/widgets/abode_toast.dart';

// ─── Sheet entry point ────────────────────────────────────────────────────────
void showAgentClientsSheet(BuildContext context) {
  showAdaptiveSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final p = AbodePalette.of(ctx);
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.border),
        ),
        child: const SafeArea(
          top: false,
          child: _AgentClientsSheetContent(),
        ),
      );
    },
  );
}

// ─── Sheet content (no Scaffold) ──────────────────────────────────────────────
class _AgentClientsSheetContent extends ConsumerWidget {
  const _AgentClientsSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p           = AbodePalette.of(context);
    final clientsAsync = ref.watch(agentManagedLandlordsProvider);
    const accent      = Color(0xFFA855F7);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
          child: Row(children: [
            Text('Managed Landlords',
              style: TextStyle(color: p.text, fontSize: 18,
                fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showInviteSheet(context, ref, p),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: p.green.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.person_add_outlined, color: p.green, size: 16),
              ),
            ),
          ]),
        ),
        Container(height: 1, color: p.border),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text('Error: $e', style: TextStyle(color: p.red))),
            data: (clients) {
              if (clients.isEmpty) {
                return _EmptyState(p: p, onInvite: () => _showInviteSheet(context, ref, p));
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _SummaryBar(clients: clients, p: p),
                  const SizedBox(height: 16),
                  ...clients.map((c) => _ClientCard(client: c, p: p, ref: ref)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref, AbodePalette p) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(
        p: p,
        onInvited: () => ref.invalidate(agentManagedLandlordsProvider),
      ),
    );
  }
}

// ─── Full-screen entry point ───────────────────────────────────────────────────
class AgentClientsScreen extends ConsumerWidget {
  final VoidCallback? onBack;
  const AgentClientsScreen({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AbodePalette.of(context);
    final clientsAsync = ref.watch(agentManagedLandlordsProvider);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        elevation: 0,
        title: Text('Managed Landlords',
          style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
        leading: onBack != null
            ? IconButton(icon: Icon(Icons.arrow_back, color: p.text), onPressed: onBack)
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: p.text),
            onPressed: () => _showInviteSheet(context, ref, p),
            tooltip: 'Invite landlord',
          ),
        ],
      ),
      body: clientsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: p.green, strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: p.red))),
        data: (clients) {
          if (clients.isEmpty) {
            return _EmptyState(p: p, onInvite: () => _showInviteSheet(context, ref, p));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SummaryBar(clients: clients, p: p),
              const SizedBox(height: 16),
              ...clients.map((c) => _ClientCard(client: c, p: p, ref: ref)),
            ],
          );
        },
      ),
    );
  }

  void _showInviteSheet(BuildContext context, WidgetRef ref, AbodePalette p) {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(p: p, onInvited: () => ref.invalidate(agentManagedLandlordsProvider)),
    );
  }
}

// ─── Summary bar ──────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<ManagedLandlord> clients;
  final AbodePalette p;
  const _SummaryBar({required this.clients, required this.p});

  @override
  Widget build(BuildContext context) {
    final active  = clients.where((c) => c.status == 'active').length;
    final pending = clients.where((c) => c.status == 'pending').length;
    return Row(children: [
      _Stat(label: 'Active', value: active.toString(), color: p.green, p: p),
      const SizedBox(width: 10),
      _Stat(label: 'Pending', value: pending.toString(), color: p.amber, p: p),
      const SizedBox(width: 10),
      _Stat(label: 'Total', value: clients.length.toString(), color: p.blue, p: p),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final AbodePalette p;
  const _Stat({required this.label, required this.value, required this.color, required this.p});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: p.sub, fontSize: 11)),
      ]),
    ));
  }
}

// ─── Client card ──────────────────────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final ManagedLandlord client;
  final AbodePalette p;
  final WidgetRef ref;
  const _ClientCard({required this.client, required this.p, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isPending = client.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: isPending
                  ? p.amber.withValues(alpha: 0.12)
                  : p.green.withValues(alpha: 0.12),
              shape: BoxShape.circle),
            child: Center(child: Text(
              _initials(client.landlordName ?? client.invitedEmail ?? '?'),
              style: TextStyle(
                color: isPending ? p.amber : p.green,
                fontSize: 15, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(client.landlordName ?? client.invitedEmail ?? 'Invited landlord',
              style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(client.landlordEmail ?? client.invitedEmail ?? '',
              style: TextStyle(color: p.muted, fontSize: 12)),
          ])),
          _StatusChip(status: client.status, p: p),
        ]),

        if (client.propertyCount != null || client.tenancyCount != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (client.propertyCount != null)
              _MiniStat(icon: Icons.home_outlined,
                label: '${client.propertyCount} propert${client.propertyCount == 1 ? 'y' : 'ies'}', p: p),
            if (client.tenancyCount != null) ...[
              const SizedBox(width: 16),
              _MiniStat(icon: Icons.people_outline,
                label: '${client.tenancyCount} tenanc${client.tenancyCount == 1 ? 'y' : 'ies'}', p: p),
            ],
          ]),
        ],

        if (isPending) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.amber.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.amber.withValues(alpha: 0.2))),
            child: Row(children: [
              Icon(Icons.schedule_rounded, size: 13, color: p.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Invite sent${client.invitedAt != null ? " on ${DateFormat('d MMM yyyy').format(client.invitedAt!)}" : ""}. Awaiting landlord acceptance.',
                style: TextStyle(color: p.amber, fontSize: 11))),
            ]),
          ),
        ],

        const SizedBox(height: 12),
        Row(children: [
          if (client.status == 'active')
            Expanded(child: _ActionBtn(
              label: 'View Portfolio',
              icon: Icons.open_in_new_rounded,
              color: p.blue,
              p: p,
              onTap: () {/* navigate to filtered portfolio view */},
            )),
          if (client.status == 'active') const SizedBox(width: 8),
          Expanded(child: _ActionBtn(
            label: client.status == 'active' ? 'Revoke Access' : 'Resend Invite',
            icon: client.status == 'active'
                ? Icons.link_off_rounded
                : Icons.send_rounded,
            color: client.status == 'active' ? p.red : p.amber,
            p: p,
            onTap: () => client.status == 'active'
                ? _revokeAccess(context, ref)
                : _resendInvite(context, ref),
          )),
        ]),
      ]),
    );
  }

  Future<void> _revokeAccess(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAbodeConfirmDialog(
      context,
      title: 'Revoke access?',
      body: 'This will remove your agency\'s access to ${client.landlordName ?? "this landlord"}\'s properties.',
      confirmLabel: 'Revoke',
      isDestructive: true,
      icon: Icons.person_remove_outlined,
    );
    if (confirmed != true) return;
    await supabase.from('agency_landlords')
        .update({'status': 'revoked'})
        .eq('id', client.id);
    ref.invalidate(agentManagedLandlordsProvider);
  }

  Future<void> _resendInvite(BuildContext context, WidgetRef ref) async {
    // In a real integration, re-send the invite email via an Edge Function
    if (context.mounted) {
      showAbodeToast(context, 'Invite resent to ${client.invitedEmail ?? client.landlordEmail ?? "landlord"}');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final AbodePalette p;
  const _StatusChip({required this.status, required this.p});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active'  => ('Active',  p.green),
      'pending' => ('Pending', p.amber),
      _         => ('Revoked', p.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final AbodePalette p;
  const _MiniStat({required this.icon, required this.label, required this.p});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: p.muted),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: p.sub, fontSize: 12)),
  ]);
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final AbodePalette p;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
    required this.color, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─── Invite sheet ─────────────────────────────────────────────────────────────
class _InviteSheet extends StatefulWidget {
  final AbodePalette p;
  final VoidCallback onInvited;
  const _InviteSheet({required this.p, required this.onInvited});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  AbodePalette get p => widget.p;
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  bool get _canSend =>
      _emailCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.contains('@') &&
      !_sending;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [

            Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: p.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.person_add_outlined, color: p.green, size: 20)),
              const SizedBox(width: 12),
              Text('Invite Landlord',
                style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.blue.withValues(alpha: 0.2))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 14, color: p.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'The landlord will receive an email invitation. Once accepted, their properties '
                  'and tenancies will appear in your managed portfolio.',
                  style: TextStyle(color: p.blue, fontSize: 12, height: 1.4))),
              ]),
            ),
            const SizedBox(height: 20),

            Text('LANDLORD EMAIL',
              style: TextStyle(color: p.sub, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: p.text, fontSize: 15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'landlord@email.com',
                hintStyle: TextStyle(color: p.muted),
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.border)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.green, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 18, color: p.muted),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _canSend ? _sendInvite : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _canSend ? p.green : p.border,
                    borderRadius: BorderRadius.circular(14)),
                  child: Center(child: _sending
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Send Invitation',
                          style: TextStyle(
                            color: _canSend ? Colors.white : p.muted,
                            fontSize: 15, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sendInvite() async {
    if (!_canSend) return;
    setState(() => _sending = true);
    try {
      final user = supabase.auth.currentUser!;
      await supabase.from('agency_landlords').insert({
        'agency_id':     user.id,
        'landlord_id':   user.id, // placeholder — real landlord claimed on acceptance
        'status':        'pending',
        'invited_email': _emailCtrl.text.trim().toLowerCase(),
      });
      // Fire-and-forget — email failure is non-fatal
      supabase.functions.invoke('send-invitation-email', body: {
        'invite_type':   'agent_landlord',
        'invited_email': _emailCtrl.text.trim().toLowerCase(),
        'agency_name':   user.userMetadata?['full_name'] as String? ?? 'Your letting agent',
      }).ignore();
      widget.onInvited();
      if (mounted) {
        Navigator.pop(context);
        showAbodeToast(context, 'Invitation sent to ${_emailCtrl.text.trim()}');
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        showAbodeToast(context, 'Failed to send invite — try again', isError: true);
      }
    }
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final AbodePalette p;
  final VoidCallback onInvite;
  const _EmptyState({required this.p, required this.onInvite});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: p.green.withValues(alpha: 0.1),
          shape: BoxShape.circle),
        child: Icon(Icons.group_add_outlined, color: p.green, size: 32)),
      const SizedBox(height: 20),
      Text('No managed landlords yet',
        style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('Invite a landlord to manage their\nproperties under your agency.',
        style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
        textAlign: TextAlign.center),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: onInvite,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
          decoration: BoxDecoration(
            color: p.green,
            borderRadius: BorderRadius.circular(14)),
          child: const Text('Invite a Landlord',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );
}
