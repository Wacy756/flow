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

  const ContractorDetails({
    required this.id,
    required this.contractorId,
    this.workTypes = const [],
    this.serviceAreas = const [],
    this.isSetupCompleted = false,
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
    );
  }

  /// True once the contractor has completed setup
  bool get isSetUp => isSetupCompleted;
}
