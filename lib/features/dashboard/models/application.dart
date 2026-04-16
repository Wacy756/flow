class Application {
  final String id;
  final String listingId;
  final String propertyId;
  final String landlordId;
  final String applicantId;
  final String? applicantName;
  final String? applicantEmail;
  final String? employmentStatus;
  final String? employerName;
  final double? monthlyIncome;
  final String? moveInPreference; // 'yyyy-MM-dd'
  final int numAdults;
  final int numChildren;
  final bool hasPets;
  final String? petDetails;
  final bool isSmoker;
  final bool hasCcj;
  final String? ccjDetails;
  final String? notes;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final DateTime createdAt;
  // Joined from property when fetched via landlordApplicationsProvider
  final String? addressLine1;
  final String? postcode;
  final double? monthlyRent;

  const Application({
    required this.id,
    required this.listingId,
    required this.propertyId,
    required this.landlordId,
    required this.applicantId,
    this.applicantName,
    this.applicantEmail,
    this.employmentStatus,
    this.employerName,
    this.monthlyIncome,
    this.moveInPreference,
    this.numAdults = 1,
    this.numChildren = 0,
    this.hasPets = false,
    this.petDetails,
    this.isSmoker = false,
    this.hasCcj = false,
    this.ccjDetails,
    this.notes,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.addressLine1,
    this.postcode,
    this.monthlyRent,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    final applicant = json['applicant'];
    final String? name = applicant is Map ? applicant['full_name'] as String? : null;
    final String? email = applicant is Map ? applicant['email'] as String? : null;
    final property = json['property'];
    final listing = json['listing'];

    return Application(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      propertyId: json['property_id'] as String,
      landlordId: json['landlord_id'] as String,
      applicantId: json['applicant_id'] as String,
      applicantName: name,
      applicantEmail: email,
      employmentStatus: json['employment_status'] as String?,
      employerName: json['employer_name'] as String?,
      monthlyIncome: (json['monthly_income'] as num?)?.toDouble(),
      moveInPreference: json['move_in_preference'] as String?,
      numAdults: (json['num_adults'] as num?)?.toInt() ?? 1,
      numChildren: (json['num_children'] as num?)?.toInt() ?? 0,
      hasPets: json['has_pets'] as bool? ?? false,
      petDetails: json['pet_details'] as String?,
      isSmoker: json['is_smoker'] as bool? ?? false,
      hasCcj: json['has_ccj'] as bool? ?? false,
      ccjDetails: json['ccj_details'] as String?,
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      addressLine1: property is Map ? property['address_line_1'] as String? : null,
      postcode: property is Map ? property['postcode'] as String? : null,
      monthlyRent: listing is Map ? (listing['monthly_rent'] as num?)?.toDouble() : null,
    );
  }

  String get addressFormatted {
    if (addressLine1 == null) return 'Unknown property';
    if (postcode == null) return addressLine1!;
    return '$addressLine1, $postcode';
  }

  String get moveInFormatted {
    if (moveInPreference == null) return 'Flexible';
    final dt = DateTime.tryParse(moveInPreference!);
    if (dt == null) return moveInPreference!;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String get employmentStatusFormatted {
    switch (employmentStatus) {
      case 'employed': return 'Employed';
      case 'self_employed': return 'Self-employed';
      case 'student': return 'Student';
      case 'unemployed': return 'Unemployed';
      case 'retired': return 'Retired';
      default: return employmentStatus ?? '—';
    }
  }
}
