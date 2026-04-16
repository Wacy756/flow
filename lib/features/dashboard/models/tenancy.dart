class TenantProfile {
  final String? id;       // tenancy row id (used for accept/delete)
  final String? fullName;
  final String? email;
  final String? status;   // 'pending' | 'active'

  const TenantProfile({this.id, this.fullName, this.email, this.status});

  factory TenantProfile.fromJson(Map<String, dynamic> json) => TenantProfile(
        id: json['id'] as String?,
        fullName: (json['full_name'] ?? json['fullName']) as String?,
        email: json['email'] as String?,
        status: json['status'] as String?,
      );
}

class Tenancy {
  final String id;
  final String tenancyId;
  final String? propertyId;
  final String? landlordId;
  final String status; // 'pending' | 'active' | 'notice_given' | 'ended'

  // Property fields (populated from joined properties table)
  final String addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String? town;
  final String postcode;
  final String? propertyType;
  final int? numBedrooms;
  final int? numBathrooms;
  final int? maxTenants;
  final String? furnishing;
  final double? latitude;
  final double? longitude;

  // Financial / terms fields (on tenancies table)
  final double? monthlyRent;
  final double? weeklyRent;
  final double? depositAmount;
  final int? minTenancyLength;
  final String? moveInDate;

  // End-of-tenancy fields
  final DateTime? noticeGivenAt;
  final String? noticeType;              // 's21' | 's8' | 'mutual' | 'surrender'
  final String? vacateDate;              // 'yyyy-MM-dd'
  final String? endOfTenancyDate;        // 'yyyy-MM-dd'
  final DateTime? depositReturnedAt;
  final double? depositDeductionAmount;
  final String? depositDeductionReason;

  final DateTime createdAt;

  // Joined / enriched fields
  final TenantProfile? tenant;     // single joined tenant (from Supabase join, landlord view)
  final TenantProfile? landlord;   // single joined landlord (from Supabase join, tenant view)
  final List<TenantProfile> tenants; // grouped list after client-side grouping

  const Tenancy({
    required this.id,
    required this.tenancyId,
    this.propertyId,
    this.landlordId,
    required this.status,
    required this.addressLine1,
    this.addressLine2,
    this.addressLine3,
    this.town,
    required this.postcode,
    this.propertyType,
    this.numBedrooms,
    this.numBathrooms,
    this.maxTenants,
    this.furnishing,
    this.monthlyRent,
    this.weeklyRent,
    this.depositAmount,
    this.minTenancyLength,
    this.moveInDate,
    this.noticeGivenAt,
    this.noticeType,
    this.vacateDate,
    this.endOfTenancyDate,
    this.depositReturnedAt,
    this.depositDeductionAmount,
    this.depositDeductionReason,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.tenant,
    this.landlord,
    this.tenants = const [],
  });

  // ---------------------------------------------------------------------------
  // Computed status helpers
  // ---------------------------------------------------------------------------

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isNoticeGiven => status == 'notice_given';
  bool get isEnded => status == 'ended';

  String get noticeTypeFormatted {
    switch (noticeType) {
      case 's21': return 'Section 21 (No-fault)';
      case 's8':  return 'Section 8 (With grounds)';
      case 'mutual': return 'Mutual Agreement';
      case 'surrender': return 'Surrender';
      default: return noticeType ?? '—';
    }
  }

  // ---------------------------------------------------------------------------

  factory Tenancy.fromJson(Map<String, dynamic> json) {
    TenantProfile? tenant;
    final tenantRaw = json['tenant'];
    if (tenantRaw is Map<String, dynamic>) {
      tenant = TenantProfile.fromJson(tenantRaw);
    }

    TenantProfile? landlord;
    final landlordRaw = json['landlord'];
    if (landlordRaw is Map<String, dynamic>) {
      landlord = TenantProfile.fromJson(landlordRaw);
    }

    // Property fields come from nested 'property' join after migration.
    // Fall back to direct fields for backwards compatibility.
    final propRaw = json['property'];
    final prop = (propRaw is Map<String, dynamic>) ? propRaw : json;

    return Tenancy(
      id: json['id'] as String,
      tenancyId: json['tenancy_id'] as String? ?? json['id'] as String,
      propertyId: json['property_id'] as String?,
      landlordId: json['landlord_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      addressLine1: prop['address_line_1'] as String? ?? '',
      addressLine2: prop['address_line_2'] as String?,
      addressLine3: prop['address_line_3'] as String?,
      town: prop['town'] as String?,
      postcode: prop['postcode'] as String? ?? '',
      propertyType: prop['property_type'] as String?,
      numBedrooms: (prop['num_bedrooms'] as num?)?.toInt(),
      numBathrooms: (prop['num_bathrooms'] as num?)?.toInt(),
      maxTenants: (prop['max_tenants'] as num?)?.toInt(),
      furnishing: prop['furnishing'] as String?,
      monthlyRent: (json['monthly_rent'] as num?)?.toDouble(),
      weeklyRent: (json['weekly_rent'] as num?)?.toDouble(),
      depositAmount: double.tryParse(json['deposit_amount']?.toString() ?? ''),
      minTenancyLength: (json['min_tenancy_length'] as num?)?.toInt(),
      moveInDate: json['move_in_date'] as String?,
      noticeGivenAt: json['notice_given_at'] != null
          ? DateTime.tryParse(json['notice_given_at'] as String)
          : null,
      noticeType: json['notice_type'] as String?,
      vacateDate: json['vacate_date'] as String?,
      endOfTenancyDate: json['end_of_tenancy_date'] as String?,
      depositReturnedAt: json['deposit_returned_at'] != null
          ? DateTime.tryParse(json['deposit_returned_at'] as String)
          : null,
      depositDeductionAmount:
          (json['deposit_deduction_amount'] as num?)?.toDouble(),
      depositDeductionReason: json['deposit_deduction_reason'] as String?,
      latitude: (prop['latitude'] as num?)?.toDouble(),
      longitude: (prop['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      tenant: tenant,
      landlord: landlord,
    );
  }

  Tenancy copyWith({
    List<TenantProfile>? tenants,
    TenantProfile? landlord,
    String? status,
  }) =>
      Tenancy(
        id: id,
        tenancyId: tenancyId,
        propertyId: propertyId,
        landlordId: landlordId,
        status: status ?? this.status,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        addressLine3: addressLine3,
        town: town,
        postcode: postcode,
        propertyType: propertyType,
        numBedrooms: numBedrooms,
        numBathrooms: numBathrooms,
        maxTenants: maxTenants,
        furnishing: furnishing,
        monthlyRent: monthlyRent,
        weeklyRent: weeklyRent,
        depositAmount: depositAmount,
        minTenancyLength: minTenancyLength,
        moveInDate: moveInDate,
        noticeGivenAt: noticeGivenAt,
        noticeType: noticeType,
        vacateDate: vacateDate,
        endOfTenancyDate: endOfTenancyDate,
        depositReturnedAt: depositReturnedAt,
        depositDeductionAmount: depositDeductionAmount,
        depositDeductionReason: depositDeductionReason,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tenant: tenant,
        landlord: landlord ?? this.landlord,
        tenants: tenants ?? this.tenants,
      );

  String get shortAddress => '$addressLine1, $postcode';
}
