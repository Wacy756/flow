import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Compliance status — computed from expiry_date
// ---------------------------------------------------------------------------

enum ComplianceStatus { valid, expiringSoon, expired, unknown }

extension ComplianceStatusX on ComplianceStatus {
  Color get color {
    switch (this) {
      case ComplianceStatus.valid:        return AppTheme.green;
      case ComplianceStatus.expiringSoon: return const Color(0xFFE65100);
      case ComplianceStatus.expired:      return Colors.red;
      case ComplianceStatus.unknown:      return AppTheme.textMuted;
    }
  }

  Color get bgColor {
    switch (this) {
      case ComplianceStatus.valid:        return AppTheme.greenBg;
      case ComplianceStatus.expiringSoon: return const Color(0xFFFFF3E0);
      case ComplianceStatus.expired:      return const Color(0xFFFFEBEE);
      case ComplianceStatus.unknown:      return AppTheme.bgPage;
    }
  }

  String get label {
    switch (this) {
      case ComplianceStatus.valid:        return 'VALID';
      case ComplianceStatus.expiringSoon: return 'EXPIRING SOON';
      case ComplianceStatus.expired:      return 'EXPIRED';
      case ComplianceStatus.unknown:      return 'NO DATE SET';
    }
  }

  IconData get icon {
    switch (this) {
      case ComplianceStatus.valid:        return Icons.check_circle_outline;
      case ComplianceStatus.expiringSoon: return Icons.schedule_outlined;
      case ComplianceStatus.expired:      return Icons.error_outline;
      case ComplianceStatus.unknown:      return Icons.help_outline;
    }
  }
}

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class ComplianceDoc {
  final String id;
  final String tenancyId;
  final String docType;
  final String filePath;
  final String fileName;
  final String? uploadedBy;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? certNumber;

  const ComplianceDoc({
    required this.id,
    required this.tenancyId,
    required this.docType,
    required this.filePath,
    required this.fileName,
    this.uploadedBy,
    this.issueDate,
    this.expiryDate,
    this.certNumber,
  });

  factory ComplianceDoc.fromJson(Map<String, dynamic> json) => ComplianceDoc(
        id: json['id'] as String,
        tenancyId: json['tenancy_id'] as String,
        docType: json['doc_type'] as String,
        filePath: json['file_path'] as String,
        fileName: json['file_name'] as String,
        uploadedBy: json['uploaded_by'] as String?,
        issueDate: json['issue_date'] != null
            ? DateTime.tryParse(json['issue_date'] as String)
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'] as String)
            : null,
        certNumber: json['cert_number'] as String?,
      );

  bool get isExternal => filePath.startsWith('EXT:');

  ComplianceStatus get complianceStatus {
    if (expiryDate == null) return ComplianceStatus.unknown;
    final now = DateTime.now();
    final daysUntil = expiryDate!.difference(now).inDays;
    if (daysUntil < 0) return ComplianceStatus.expired;
    if (daysUntil <= 60) return ComplianceStatus.expiringSoon;
    return ComplianceStatus.valid;
  }

  /// Formatted expiry, e.g. "12 Apr 2026"
  String? get expiryFormatted {
    if (expiryDate == null) return null;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${expiryDate!.day} ${m[expiryDate!.month - 1]} ${expiryDate!.year}';
  }

  /// Days until expiry — negative means already expired.
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
}

// ---------------------------------------------------------------------------

const List<String> kComplianceDocTypes = [
  'Tenancy agreement',
  'Right to rent',
  'EPC (Energy Performance Certificate)',
  'ECIR (Electrical Installation Condition Report)',
  'Gas Safety',
];

/// Doc types that have legally required expiry dates.
const Map<String, String> kComplianceDocExpiry = {
  'Gas Safety': 'Annual (12 months)',
  'ECIR (Electrical Installation Condition Report)': 'Every 5 years',
  'EPC (Energy Performance Certificate)': 'Every 10 years',
};
