class IncidentComment {
  final String id;
  final String incidentId;
  final String authorId;
  final String authorRole; // 'landlord' | 'tenant' | 'contractor'
  final String? authorName; // joined from profiles
  final String body;
  final DateTime createdAt;

  const IncidentComment({
    required this.id,
    required this.incidentId,
    required this.authorId,
    required this.authorRole,
    this.authorName,
    required this.body,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  String get authorInitial {
    if (authorName != null && authorName!.isNotEmpty) {
      return authorName![0].toUpperCase();
    }
    return authorRole[0].toUpperCase();
  }

  String get authorDisplayName => authorName ?? _capitalize(authorRole);

  String get timeFormatted {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${createdAt.day} ${m[createdAt.month - 1]}';
  }

  // ---------------------------------------------------------------------------

  factory IncidentComment.fromJson(Map<String, dynamic> json) {
    String? authorName;
    final authorRaw = json['author'];
    if (authorRaw is Map<String, dynamic>) {
      authorName = authorRaw['full_name'] as String?;
    }

    return IncidentComment(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      authorId: json['author_id'] as String,
      authorRole: json['author_role'] as String? ?? 'tenant',
      authorName: authorName,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
