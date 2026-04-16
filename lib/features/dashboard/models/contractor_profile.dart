import 'service_area.dart';

const kWorkTypes = [
  'Plumbing',
  'Carpentry',
  'Locksmith',
  'Electrical',
  'Painting',
  'Roofing',
  'Gardening',
  'Cleaning',
  'General Maintenance',
  'HVAC',
];

class ContractorDetails {
  final String id;
  final String contractorId; // == user id
  final List<String> workTypes;
  final List<ServiceArea> serviceAreas;
  final bool isSetupCompleted;

  // Certification fields
  final String? insuranceCertNumber;
  final DateTime? insuranceExpiry;
  final String? gasSafeNumber;
  final DateTime? gasSafeExpiry;
  final String? niceicNumber;
  final DateTime? niceicExpiry;

  // Ratings (computed by DB trigger)
  final double averageRating;
  final int totalRatings;

  const ContractorDetails({
    required this.id,
    required this.contractorId,
    this.workTypes = const [],
    this.serviceAreas = const [],
    this.isSetupCompleted = false,
    this.insuranceCertNumber,
    this.insuranceExpiry,
    this.gasSafeNumber,
    this.gasSafeExpiry,
    this.niceicNumber,
    this.niceicExpiry,
    this.averageRating = 0,
    this.totalRatings = 0,
  });

  factory ContractorDetails.fromJson(Map<String, dynamic> json) {
    final rawWork = json['work_types'];
    final List<String> workTypes = rawWork is List
        ? rawWork.map((e) => e.toString()).toList()
        : [];

    final rawAreas = json['service_areas'];
    final List<ServiceArea> serviceAreas = rawAreas is List
        ? rawAreas
            .map((e) =>
                ServiceArea.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : [];

    return ContractorDetails(
      id: json['id'] as String? ?? '',
      contractorId: json['contractor_id'] as String? ?? '',
      workTypes: workTypes,
      serviceAreas: serviceAreas,
      isSetupCompleted: json['is_setup_completed'] as bool? ?? false,
      insuranceCertNumber: json['insurance_cert_number'] as String?,
      insuranceExpiry: json['insurance_expiry'] != null
          ? DateTime.tryParse(json['insurance_expiry'] as String)
          : null,
      gasSafeNumber: json['gas_safe_number'] as String?,
      gasSafeExpiry: json['gas_safe_expiry'] != null
          ? DateTime.tryParse(json['gas_safe_expiry'] as String)
          : null,
      niceicNumber: json['niceic_number'] as String?,
      niceicExpiry: json['niceic_expiry'] != null
          ? DateTime.tryParse(json['niceic_expiry'] as String)
          : null,
      averageRating:
          (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalRatings: json['total_ratings'] as int? ?? 0,
    );
  }

  // -------------------------------------------------------------------------
  // Computed helpers

  /// True once the contractor has completed setup
  bool get isSetUp => isSetupCompleted;

  /// True if at least one certification field is filled in
  bool get hasAnyCert =>
      (insuranceCertNumber?.isNotEmpty ?? false) ||
      (gasSafeNumber?.isNotEmpty ?? false) ||
      (niceicNumber?.isNotEmpty ?? false);

  /// Star rating string e.g. "4.7" or "—" if no ratings yet
  String get ratingDisplay =>
      totalRatings == 0 ? '—' : averageRating.toStringAsFixed(1);
}
