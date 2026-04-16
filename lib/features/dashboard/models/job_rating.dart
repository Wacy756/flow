class JobRating {
  final String id;
  final String incidentId;
  final String tenantId;
  final String contractorId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const JobRating({
    required this.id,
    required this.incidentId,
    required this.tenantId,
    required this.contractorId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory JobRating.fromJson(Map<String, dynamic> json) => JobRating(
        id: json['id'] as String,
        incidentId: json['incident_id'] as String,
        tenantId: json['tenant_id'] as String,
        contractorId: json['contractor_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        createdAt: DateTime.tryParse(
                json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
