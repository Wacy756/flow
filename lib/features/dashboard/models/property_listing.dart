class PropertyListing {
  final String id;
  final String propertyId;
  final String landlordId;
  final double? askingRent;
  final String? availableFrom; // 'yyyy-MM-dd'
  final double? depositAmount;
  final int? minTenancyMonths;
  final String? description;
  final bool isActive;
  final String shareToken;
  final DateTime createdAt;

  const PropertyListing({
    required this.id,
    required this.propertyId,
    required this.landlordId,
    this.askingRent,
    this.availableFrom,
    this.depositAmount,
    this.minTenancyMonths,
    this.description,
    required this.isActive,
    required this.shareToken,
    required this.createdAt,
  });

  factory PropertyListing.fromJson(Map<String, dynamic> json) => PropertyListing(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        landlordId: json['landlord_id'] as String,
        askingRent: (json['asking_rent'] as num?)?.toDouble(),
        availableFrom: json['available_from'] as String?,
        depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
        minTenancyMonths: (json['min_tenancy_months'] as num?)?.toInt(),
        description: json['description'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        shareToken: json['share_token'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  /// The shareable application link sent to prospective tenants.
  String get shareUrl => 'https://flowapp.co.uk/apply/$shareToken';

  String get availableFromFormatted {
    if (availableFrom == null) return 'Immediately';
    final dt = DateTime.tryParse(availableFrom!);
    if (dt == null) return availableFrom!;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
