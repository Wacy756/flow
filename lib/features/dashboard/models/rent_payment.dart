class RentPayment {
  final String id;
  final String tenancyId;   // group UUID = properties.id
  final String landlordId;
  final double amountDue;
  final double amountPaid;
  final String dueDate;     // 'yyyy-MM-dd'
  final DateTime? paidAt;
  final String status;      // 'pending' | 'paid' | 'partial' | 'late'
  final String? notes;
  final DateTime createdAt;

  const RentPayment({
    required this.id,
    required this.tenancyId,
    required this.landlordId,
    required this.amountDue,
    required this.amountPaid,
    required this.dueDate,
    this.paidAt,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  double get arrears => (amountDue - amountPaid).clamp(0, double.infinity);
  bool get isInArrears => arrears > 0;

  bool get isPending => status == 'pending';
  bool get isPaid => status == 'paid';
  bool get isPartial => status == 'partial';
  bool get isLate => status == 'late';

  String get statusFormatted {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'late':
        return 'Late';
      default:
        return 'Pending';
    }
  }

  String get dueDateFormatted => _fmtDate(dueDate);

  String? get paidAtFormatted {
    if (paidAt == null) return null;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${paidAt!.day} ${m[paidAt!.month - 1]} ${paidAt!.year}';
  }

  static String _fmtDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  // ---------------------------------------------------------------------------

  factory RentPayment.fromJson(Map<String, dynamic> json) => RentPayment(
        id: json['id'] as String,
        tenancyId: json['tenancy_id'] as String,
        landlordId: json['landlord_id'] as String,
        amountDue: (json['amount_due'] as num).toDouble(),
        amountPaid: (json['amount_paid'] as num? ?? 0).toDouble(),
        dueDate: json['due_date'] as String,
        paidAt: json['paid_at'] != null
            ? DateTime.tryParse(json['paid_at'] as String)
            : null,
        status: json['status'] as String? ?? 'pending',
        notes: json['notes'] as String?,
        createdAt: DateTime.tryParse(
                json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// List extension
// ---------------------------------------------------------------------------

extension RentPaymentListX on List<RentPayment> {
  double get totalArrears =>
      fold<double>(0, (sum, p) => sum + p.arrears);

  bool get hasArrears => totalArrears > 0;
}
