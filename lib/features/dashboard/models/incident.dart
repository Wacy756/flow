class Incident {
  final String id;
  final String title;
  final String description;
  final String status; // reported | approved | quoted | in_progress | completed
  final String? category;
  final DateTime createdAt;
  final String? tenantId;
  final String? tenancyId;
  final List<String> mediaUrls;
  final double? quoteAmount;
  final bool isTenantCompleted;
  final bool isContractorCompleted;
  final String? contractorId;
  final List<String> declinedBy;

  // Joined
  final String? tenantName;
  final String? tenantEmail;
  final String? propertyAddress;
  final String? propertyPostcode;
  final double? distanceMeters;

  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.category,
    required this.createdAt,
    this.tenantId,
    this.tenancyId,
    this.mediaUrls = const [],
    this.quoteAmount,
    this.isTenantCompleted = false,
    this.isContractorCompleted = false,
    this.contractorId,
    this.declinedBy = const [],
    this.tenantName,
    this.tenantEmail,
    this.propertyAddress,
    this.propertyPostcode,
    this.distanceMeters,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    String? tenantName, tenantEmail;
    final tenantRaw = json['tenant'];
    if (tenantRaw is Map<String, dynamic>) {
      tenantName = tenantRaw['full_name'] as String?;
      tenantEmail = tenantRaw['email'] as String?;
    } else {
      // From RPC mapped fields
      tenantName = json['tenant_name'] as String?;
    }

    String? propertyAddress, propertyPostcode;
    final propRaw = json['property'];
    if (propRaw is Map<String, dynamic>) {
      propertyAddress = propRaw['address_line_1'] as String?;
      propertyPostcode = propRaw['postcode'] as String?;
    } else {
      propertyAddress = json['property_address'] as String?;
      propertyPostcode = json['property_postcode'] as String?;
    }

    final mediaRaw = json['media_urls'];
    final List<String> media = mediaRaw is List
        ? mediaRaw.map((e) => e.toString()).toList()
        : [];

    final declinedRaw = json['declined_by'];
    final List<String> declined = declinedRaw is List
        ? declinedRaw.map((e) => e.toString()).toList()
        : [];

    return Incident(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'reported',
      category: json['category'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      tenantId: json['tenant_id'] as String?,
      tenancyId: json['tenancy_id'] as String?,
      mediaUrls: media,
      quoteAmount: (json['quote_amount'] as num?)?.toDouble(),
      isTenantCompleted: json['is_tenant_completed'] as bool? ?? false,
      isContractorCompleted: json['is_contractor_completed'] as bool? ?? false,
      contractorId: json['contractor_id'] as String?,
      declinedBy: declined,
      tenantName: tenantName,
      tenantEmail: tenantEmail,
      propertyAddress: propertyAddress,
      propertyPostcode: propertyPostcode,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    );
  }

  String get displayStatus => status.replaceAll('_', ' ');

  bool get isActive => status != 'completed';
}
