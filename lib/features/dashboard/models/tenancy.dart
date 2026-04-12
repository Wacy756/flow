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
  final String? landlordId;
  final String status; // 'pending' | 'active'
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
  final double? monthlyRent;
  final double? weeklyRent;
  final double? depositAmount;
  final int? minTenancyLength;
  final String? moveInDate;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  // Joined / enriched fields
  final TenantProfile? tenant;     // single joined tenant (from Supabase join, landlord view)
  final TenantProfile? landlord;   // single joined landlord (from Supabase join, tenant view)
  final List<TenantProfile> tenants; // grouped list after client-side grouping

  const Tenancy({
    required this.id,
    required this.tenancyId,
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
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.tenant,
    this.landlord,
    this.tenants = const [],
  });

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

    return Tenancy(
      id: json['id'] as String,
      tenancyId: json['tenancy_id'] as String? ?? json['id'] as String,
      landlordId: json['landlord_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      addressLine1: json['address_line_1'] as String? ?? '',
      addressLine2: json['address_line_2'] as String?,
      addressLine3: json['address_line_3'] as String?,
      town: json['town'] as String?,
      postcode: json['postcode'] as String? ?? '',
      propertyType: json['property_type'] as String?,
      numBedrooms: (json['num_bedrooms'] as num?)?.toInt(),
      numBathrooms: (json['num_bathrooms'] as num?)?.toInt(),
      maxTenants: (json['max_tenants'] as num?)?.toInt(),
      furnishing: json['furnishing'] as String?,
      monthlyRent: (json['monthly_rent'] as num?)?.toDouble(),
      weeklyRent: (json['weekly_rent'] as num?)?.toDouble(),
      depositAmount: double.tryParse(json['deposit_amount']?.toString() ?? ''),
      minTenancyLength: (json['min_tenancy_length'] as num?)?.toInt(),
      moveInDate: json['move_in_date'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      tenant: tenant,
      landlord: landlord,
    );
  }

  Tenancy copyWith({List<TenantProfile>? tenants, TenantProfile? landlord}) => Tenancy(
        id: id,
        tenancyId: tenancyId,
        landlordId: landlordId,
        status: status,
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
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tenant: tenant,
        landlord: landlord ?? this.landlord,
        tenants: tenants ?? this.tenants,
      );

  String get shortAddress => '$addressLine1, $postcode';
}
