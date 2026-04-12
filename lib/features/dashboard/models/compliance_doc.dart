class ComplianceDoc {
  final String id;
  final String tenancyId;
  final String docType;
  final String filePath;
  final String fileName;
  final String? uploadedBy;

  const ComplianceDoc({
    required this.id,
    required this.tenancyId,
    required this.docType,
    required this.filePath,
    required this.fileName,
    this.uploadedBy,
  });

  factory ComplianceDoc.fromJson(Map<String, dynamic> json) => ComplianceDoc(
        id: json['id'] as String,
        tenancyId: json['tenancy_id'] as String,
        docType: json['doc_type'] as String,
        filePath: json['file_path'] as String,
        fileName: json['file_name'] as String,
        uploadedBy: json['uploaded_by'] as String?,
      );

  bool get isExternal => filePath.startsWith('EXT:');
}

const List<String> kComplianceDocTypes = [
  'Tenancy agreement',
  'Right to rent',
  'EPC (Energy Performance Certificate)',
  'ECIR (Electrical Installation Condition Report)',
  'Gas Safety',
];
