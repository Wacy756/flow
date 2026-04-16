import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/incident_comment.dart';
import '../providers/dashboard_providers.dart';

class IncidentCommentsThread extends ConsumerStatefulWidget {
  final String incidentId;
  final String currentUserId;
  final String currentUserRole; // 'landlord' | 'tenant' | 'contractor'

  const IncidentCommentsThread({
    super.key,
    required this.incidentId,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  ConsumerState<IncidentCommentsThread> createState() =>
      _IncidentCommentsThreadState();
}

class _IncidentCommentsThreadState
    extends ConsumerState<IncidentCommentsThread> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _inputCtrl.clear();

    final ok = await ref
        .read(postIncidentCommentProvider.notifier)
        .post(
          incidentId: widget.incidentId,
          body: text,
          authorRole: widget.currentUserRole,
        );

    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        // Scroll to bottom after new message renders
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync =
        ref.watch(incidentCommentsProvider(widget.incidentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thread
        commentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.green),
              ),
            ),
          ),
          error: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Could not load comments.',
                style: TextStyle(
                    color: AppTheme.textMuted, fontSize: 12)),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No messages yet — start the conversation.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                controller: _scrollCtrl,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4),
                itemCount: comments.length,
                itemBuilder: (_, i) => _CommentBubble(
                  comment: comments[i],
                  isOwn: comments[i].authorId == widget.currentUserId,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        // Input row
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Write a message…',
                    hintStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.bgPage,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.border, width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.border, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.green, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _sending
                      ? AppTheme.green.withValues(alpha: 0.5)
                      : AppTheme.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CommentBubble extends StatelessWidget {
  final IncidentComment comment;
  final bool isOwn;

  const _CommentBubble({
    required this.comment,
    required this.isOwn,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = AppTheme.roleColor(comment.authorRole);
    final roleBg = AppTheme.roleBg(comment.authorRole);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            _Avatar(
              initial: comment.authorInitial,
              color: roleColor,
              bg: roleBg,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwn
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Author name + role badge + time
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwn) ...[
                      Text(
                        comment.timeFormatted,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      isOwn ? 'You' : comment.authorDisplayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _RolePill(
                        role: comment.authorRole,
                        color: roleColor,
                        bg: roleBg),
                    if (!isOwn) ...[
                      const SizedBox(width: 6),
                      Text(
                        comment.timeFormatted,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Message bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: isOwn
                        ? AppTheme.greenBg
                        : AppTheme.bgPage,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: isOwn
                          ? const Radius.circular(12)
                          : const Radius.circular(4),
                      bottomRight: isOwn
                          ? const Radius.circular(4)
                          : const Radius.circular(12),
                    ),
                    border: Border.all(
                      color: isOwn
                          ? AppTheme.green.withValues(alpha: 0.25)
                          : AppTheme.border,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    comment.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: isOwn
                          ? AppTheme.green
                          : AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            _Avatar(
              initial: comment.authorInitial,
              color: roleColor,
              bg: roleBg,
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final Color color;
  final Color bg;

  const _Avatar({
    required this.initial,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      );
}

class _RolePill extends StatelessWidget {
  final String role;
  final Color color;
  final Color bg;

  const _RolePill({
    required this.role,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      );
}
