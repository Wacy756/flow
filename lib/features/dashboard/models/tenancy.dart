class TenantProfile {
  final String? id;
  final String? fullName;
  final String? email;
  final String? status;
  final String? referencingStatus;
  // Bank details (landlord profile, joined for tenant view)
  final String? bankAccountName;
  final String? bankSortCode;
  final String? bankAccountNumber;

  const TenantProfile({
    this.id,
    this.fullName,
    this.email,
    this.status,
    this.referencingStatus,
    this.bankAccountName,
    this.bankSortCode,
    this.bankAccountNumber,
  });

  factory TenantProfile.fromJson(Map<String, dynamic> json) => TenantProfile(
        id: json['id'] as String?,
        fullName: (json['full_name'] ?? json['fullName']) as String?,
        email: json['email'] as String?,
        status: json['status'] as String?,
        referencingStatus: json['referencing_status'] as String?,
        bankAccountName:   json['bank_account_name'] as String?,
        bankSortCode:      json['bank_sort_code'] as String?,
        bankAccountNumber: json['bank_account_number'] as String?,
      );
}

class Tenancy {
  final String id;
  final String tenancyId;
  final String? landlordId;
  final String? propertyId;
  final String status; // 'pending' | 'active' | 'expiring_soon' | 'expired' | 'holding_over' | 'terminated'
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
  final String? depositScheme;
  final String? depositRef;
  final int? minTenancyLength;
  final String? moveInDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? breakClauseDate;
  /// Credit/employment referencing (Homeppl etc.): 'not_started' | 'in_progress' | 'passed' | 'failed'
  final String referencingStatus;
  /// Right to Rent check (Home Office): 'not_started' | 'completed' | 'needs_followup'
  final String rtrStatus;
  final DateTime? rtrCheckDate;
  final String? rtrCheckMethod; // 'online_gov' | 'physical_document'
  final String? rtrDocumentType;
  final String? rtrShareCode;
  final int rtrChecklistMask;
  final String? rtrDocumentUrl;   // storage path of tenant-uploaded RTR doc
  final String? rtrTenantDocType; // doc type chosen by tenant when uploading
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  // ── RRA / Renters' Rights Act fields ──────────────────────────────────────
  /// Date notice to quit was served (periodic tenancy ending)
  final DateTime? noticeServedDate;
  /// Who gave notice: 'tenant' | 'landlord'
  final String? noticeGivenBy;
  /// Expected vacate date after notice period
  final DateTime? expectedVacateDate;
  /// Date rent was last formally increased under s.13
  final DateTime? lastRentIncreaseDate;
  /// Next scheduled s.13 rent review date
  final DateTime? nextRentReviewDate;
  /// Soft reminder date — not a legal term, just a landlord-side prompt to
  /// review the tenancy (renew, adjust rent, serve notice, or do nothing).
  final DateTime? tenancyReviewDate;
  /// PRS (Private Rented Sector) registration reference
  final String? prsRegistrationRef;
  /// Homeppl application reference (set when referencing is requested via API)
  final String? homepplApplicationId;
  /// URL to the Homeppl PDF report (populated via webhook when complete)
  final String? homepplReportUrl;
  /// When referencing completed (set by webhook)
  final DateTime? referencingCompletedAt;
  /// Whether a pet has been approved for this tenancy
  final bool petPermitted;
  /// Housing Ombudsman case reference (if any)
  final String? ombudsmanRef;

  // ── Tenant offer fields (submitted by tenant) ─────────────────────────────
  /// Employment status: 'employed' | 'self_employed' | 'student' | 'unemployed' | 'retired'
  final String? tenantEmploymentStatus;
  /// Gross annual income submitted by tenant (£)
  final double? tenantAnnualIncome;
  /// Tenant's preferred move-in date
  final DateTime? tenantMoveInPreference;
  /// Cover note from tenant to landlord
  final String? tenantMessage;
  /// When the tenant submitted their completed offer
  final DateTime? offerSubmittedAt;

  /// Email address of the invited tenant (for pending invites)
  final String? invitedEmail;

  // ── Holding deposit ───────────────────────────────────────────────────────
  /// Calculated holding deposit amount (1 week's rent)
  final double? holdingDepositAmount;
  /// 'not_requested' | 'requested' | 'tenant_confirmed' | 'received' | 'returned' | 'forfeited'
  final String holdingDepositStatus;
  /// Unique reference e.g. ABODE-HD-2847
  final String? holdingDepositReference;
  final DateTime? holdingDepositRequestedAt;
  final DateTime? holdingDepositConfirmedAt;
  final DateTime? holdingDepositReceivedAt;

  // ── GoCardless Direct Debit ───────────────────────────────────────────────
  final String? gcCustomerId;
  final String? gcMandateId;
  /// 'pending_customer_approval' | 'submitted' | 'active' | 'failed' | 'cancelled' | 'expired' | 'consumed'
  final String? gcMandateStatus;
  final DateTime? gcMandateCreatedAt;

  // ── TDS Deposit Protection ────────────────────────────────────────────────
  /// 'unprotected' | 'pending' | 'protected' | 'dispute_raised' | 'released'
  final String tdsStatus;
  final String? tdsDepositId;
  final String? tdsProtectionRef;
  final DateTime? tdsProtectionDate;
  final String? tdsCertUrl;

  // ── DPS Deposit Protection ────────────────────────────────────────────────
  /// 'unprotected' | 'pending' | 'protected' | 'released'
  final String dpsStatus;
  final String? dpsProtectionId;
  final String? dpsProtectionRef;
  final DateTime? dpsProtectionDate;
  final String? dpsCertUrl;

  // ── Reposit (deposit replacement) ────────────────────────────────────────
  /// 'not_started' | 'invited' | 'active' | 'expired' | 'claimed'
  final String repositStatus;
  final String? repositPolicyId;
  final String? repositPolicyRef;

  /// 'manual' | 'tds' | 'dps' | 'reposit'
  final String? depositProtectionMethod;

  // Joined / enriched fields
  final TenantProfile? tenant;     // single joined tenant (from Supabase join, landlord view)
  final TenantProfile? landlord;   // single joined landlord (from Supabase join, tenant view)
  final List<TenantProfile> tenants; // grouped list after client-side grouping

  const Tenancy({
    required this.id,
    required this.tenancyId,
    this.landlordId,
    this.propertyId,
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
    this.depositScheme,
    this.depositRef,
    this.minTenancyLength,
    this.moveInDate,
    this.startDate,
    this.endDate,
    this.breakClauseDate,
    this.referencingStatus = 'not_started',
    this.rtrStatus = 'not_started',
    this.rtrCheckDate,
    this.rtrCheckMethod,
    this.rtrDocumentType,
    this.rtrShareCode,
    this.rtrChecklistMask = 0,
    this.rtrDocumentUrl,
    this.rtrTenantDocType,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.tenant,
    this.landlord,
    this.tenants = const [],
    // RRA fields
    this.noticeServedDate,
    this.noticeGivenBy,
    this.expectedVacateDate,
    this.lastRentIncreaseDate,
    this.nextRentReviewDate,
    this.tenancyReviewDate,
    this.prsRegistrationRef,
    this.homepplApplicationId,
    this.homepplReportUrl,
    this.referencingCompletedAt,
    this.petPermitted = false,
    this.ombudsmanRef,
    this.tenantEmploymentStatus,
    this.tenantAnnualIncome,
    this.tenantMoveInPreference,
    this.tenantMessage,
    this.offerSubmittedAt,
    this.invitedEmail,
    this.holdingDepositAmount,
    this.holdingDepositStatus = 'not_requested',
    this.holdingDepositReference,
    this.holdingDepositRequestedAt,
    this.holdingDepositConfirmedAt,
    this.holdingDepositReceivedAt,
    // GoCardless
    this.gcCustomerId,
    this.gcMandateId,
    this.gcMandateStatus,
    this.gcMandateCreatedAt,
    // TDS
    this.tdsStatus = 'unprotected',
    this.tdsDepositId,
    this.tdsProtectionRef,
    this.tdsProtectionDate,
    this.tdsCertUrl,
    // DPS
    this.dpsStatus = 'unprotected',
    this.dpsProtectionId,
    this.dpsProtectionRef,
    this.dpsProtectionDate,
    this.dpsCertUrl,
    // Reposit
    this.repositStatus = 'not_started',
    this.repositPolicyId,
    this.repositPolicyRef,
    this.depositProtectionMethod,
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
      tenancyId: json['id'] as String,
      landlordId: json['landlord_id'] as String?,
      propertyId: json['property_id'] as String?,
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
      depositScheme: json['deposit_scheme'] as String?,
      depositRef: json['deposit_ref'] as String?,
      minTenancyLength: (json['min_tenancy_length'] as num?)?.toInt(),
      moveInDate: json['move_in_date'] as String?,
      startDate: json['start_date'] == null
          ? null
          : DateTime.tryParse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.tryParse(json['end_date'] as String),
      breakClauseDate: json['break_clause_date'] == null
          ? null
          : DateTime.tryParse(json['break_clause_date'] as String),
      referencingStatus:
          json['referencing_status'] as String? ?? 'not_started',
      rtrStatus: json['rtr_status'] as String? ?? 'not_started',
      rtrCheckDate: json['rtr_check_date'] == null
          ? null
          : DateTime.tryParse(json['rtr_check_date'] as String),
      rtrCheckMethod: json['rtr_check_method'] as String?,
      rtrDocumentType: json['rtr_document_type'] as String?,
      rtrShareCode: json['rtr_share_code'] as String?,
      rtrChecklistMask: json['rtr_checklist_mask'] as int? ?? 0,
      rtrDocumentUrl: json['rtr_document_url'] as String?,
      rtrTenantDocType: json['rtr_tenant_doc_type'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      tenant: tenant,
      landlord: landlord,
      // RRA fields
      noticeServedDate: json['notice_served_date'] == null
          ? null
          : DateTime.tryParse(json['notice_served_date'] as String),
      noticeGivenBy: json['notice_given_by'] as String?,
      expectedVacateDate: json['expected_vacate_date'] == null
          ? null
          : DateTime.tryParse(json['expected_vacate_date'] as String),
      lastRentIncreaseDate: json['last_rent_increase_date'] == null
          ? null
          : DateTime.tryParse(json['last_rent_increase_date'] as String),
      tenancyReviewDate: json['tenancy_review_date'] == null
          ? null
          : DateTime.tryParse(json['tenancy_review_date'] as String),
      nextRentReviewDate: json['next_rent_review_date'] == null
          ? null
          : DateTime.tryParse(json['next_rent_review_date'] as String),
      prsRegistrationRef: json['prs_registration_ref'] as String?,
      homepplApplicationId: json['homeppl_application_id'] as String?,
      homepplReportUrl: json['homeppl_report_url'] as String?,
      referencingCompletedAt: json['referencing_completed_at'] == null
          ? null : DateTime.tryParse(json['referencing_completed_at'] as String),
      petPermitted: json['pet_permitted'] as bool? ?? false,
      ombudsmanRef: json['ombudsman_ref'] as String?,
      tenantEmploymentStatus: json['tenant_employment_status'] as String?,
      tenantAnnualIncome: (json['tenant_annual_income'] as num?)?.toDouble(),
      tenantMoveInPreference: json['tenant_move_in_preference'] == null
          ? null
          : DateTime.tryParse(json['tenant_move_in_preference'] as String),
      tenantMessage: json['tenant_message'] as String?,
      offerSubmittedAt: json['offer_submitted_at'] == null
          ? null
          : DateTime.tryParse(json['offer_submitted_at'] as String),
      invitedEmail: json['invited_email'] as String?,
      holdingDepositAmount: (json['holding_deposit_amount'] as num?)?.toDouble(),
      holdingDepositStatus: json['holding_deposit_status'] as String? ?? 'not_requested',
      holdingDepositReference: json['holding_deposit_reference'] as String?,
      holdingDepositRequestedAt: json['holding_deposit_requested_at'] == null
          ? null : DateTime.tryParse(json['holding_deposit_requested_at'] as String),
      holdingDepositConfirmedAt: json['holding_deposit_confirmed_at'] == null
          ? null : DateTime.tryParse(json['holding_deposit_confirmed_at'] as String),
      holdingDepositReceivedAt: json['holding_deposit_received_at'] == null
          ? null : DateTime.tryParse(json['holding_deposit_received_at'] as String),
      // GoCardless
      gcCustomerId: json['gc_customer_id'] as String?,
      gcMandateId: json['gc_mandate_id'] as String?,
      gcMandateStatus: json['gc_mandate_status'] as String?,
      gcMandateCreatedAt: json['gc_mandate_created_at'] == null
          ? null : DateTime.tryParse(json['gc_mandate_created_at'] as String),
      // TDS
      tdsStatus: json['tds_status'] as String? ?? 'unprotected',
      tdsDepositId: json['tds_deposit_id'] as String?,
      tdsProtectionRef: json['tds_protection_ref'] as String?,
      tdsProtectionDate: json['tds_protection_date'] == null
          ? null : DateTime.tryParse(json['tds_protection_date'] as String),
      tdsCertUrl: json['tds_cert_url'] as String?,
      // DPS
      dpsStatus: json['dps_status'] as String? ?? 'unprotected',
      dpsProtectionId: json['dps_protection_id'] as String?,
      dpsProtectionRef: json['dps_protection_ref'] as String?,
      dpsProtectionDate: json['dps_protection_date'] == null
          ? null : DateTime.tryParse(json['dps_protection_date'] as String),
      dpsCertUrl: json['dps_cert_url'] as String?,
      // Reposit
      repositStatus: json['reposit_status'] as String? ?? 'not_started',
      repositPolicyId: json['reposit_policy_id'] as String?,
      repositPolicyRef: json['reposit_policy_ref'] as String?,
      depositProtectionMethod: json['deposit_protection_method'] as String?,
    );
  }

  Tenancy copyWith({
    List<TenantProfile>? tenants,
    TenantProfile? landlord,
    DateTime? noticeServedDate,
    String? noticeGivenBy,
    DateTime? expectedVacateDate,
    DateTime? nextRentReviewDate,
    DateTime? tenancyReviewDate,
    String? prsRegistrationRef,
    bool? petPermitted,
    String? gcMandateStatus,
    String? tdsStatus,
    String? tdsProtectionRef,
    DateTime? tdsProtectionDate,
    String? tdsCertUrl,
    String? invitedEmail,
    String? tenantEmploymentStatus,
    double? tenantAnnualIncome,
    DateTime? tenantMoveInPreference,
    String? tenantMessage,
    DateTime? offerSubmittedAt,
    String? rtrDocumentUrl,
    String? rtrTenantDocType,
    DateTime? referencingCompletedAt,
    String? homepplReportUrl,
    String? referencingStatus,
  }) =>
      Tenancy(
        id: id,
        tenancyId: tenancyId,
        landlordId: landlordId,
        propertyId: propertyId,
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
        depositScheme: depositScheme,
        depositRef: depositRef,
        minTenancyLength: minTenancyLength,
        moveInDate: moveInDate,
        startDate: startDate,
        endDate: endDate,
        breakClauseDate: breakClauseDate,
        rtrStatus: rtrStatus,
        rtrCheckDate: rtrCheckDate,
        rtrCheckMethod: rtrCheckMethod,
        rtrDocumentType: rtrDocumentType,
        rtrShareCode: rtrShareCode,
        rtrChecklistMask: rtrChecklistMask,
        rtrDocumentUrl: rtrDocumentUrl ?? this.rtrDocumentUrl,
        rtrTenantDocType: rtrTenantDocType ?? this.rtrTenantDocType,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        tenant: tenant,
        landlord: landlord ?? this.landlord,
        tenants: tenants ?? this.tenants,
        noticeServedDate: noticeServedDate ?? this.noticeServedDate,
        noticeGivenBy: noticeGivenBy ?? this.noticeGivenBy,
        expectedVacateDate: expectedVacateDate ?? this.expectedVacateDate,
        lastRentIncreaseDate: lastRentIncreaseDate,
        nextRentReviewDate: nextRentReviewDate ?? this.nextRentReviewDate,
        tenancyReviewDate: tenancyReviewDate ?? this.tenancyReviewDate,
        prsRegistrationRef: prsRegistrationRef ?? this.prsRegistrationRef,
        petPermitted: petPermitted ?? this.petPermitted,
        ombudsmanRef: ombudsmanRef,
        gcCustomerId: gcCustomerId,
        gcMandateId: gcMandateId,
        gcMandateStatus: gcMandateStatus ?? this.gcMandateStatus,
        gcMandateCreatedAt: gcMandateCreatedAt,
        tdsStatus: tdsStatus ?? this.tdsStatus,
        tdsDepositId: tdsDepositId,
        tdsProtectionRef: tdsProtectionRef ?? this.tdsProtectionRef,
        tdsProtectionDate: tdsProtectionDate ?? this.tdsProtectionDate,
        tdsCertUrl: tdsCertUrl ?? this.tdsCertUrl,
        invitedEmail: invitedEmail ?? this.invitedEmail,
        tenantEmploymentStatus: tenantEmploymentStatus ?? this.tenantEmploymentStatus,
        tenantAnnualIncome: tenantAnnualIncome ?? this.tenantAnnualIncome,
        tenantMoveInPreference: tenantMoveInPreference ?? this.tenantMoveInPreference,
        tenantMessage: tenantMessage ?? this.tenantMessage,
        offerSubmittedAt: offerSubmittedAt ?? this.offerSubmittedAt,
        homepplApplicationId: homepplApplicationId ?? this.homepplApplicationId,
        homepplReportUrl: homepplReportUrl ?? this.homepplReportUrl,
        referencingCompletedAt: referencingCompletedAt ?? this.referencingCompletedAt,
        referencingStatus: referencingStatus ?? this.referencingStatus,
      );

  String get shortAddress => '$addressLine1, $postcode';

  /// Compact single-line address for display in lists/messages
  String get addressOneLiner {
    final parts = [addressLine1, town, postcode]
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.join(', ');
  }

  /// Landlord's display name (from joined profile)
  String? get landlordName => landlord?.fullName;

}

extension TenantProfileName on TenantProfile {
  /// Display name for a tenant (handles null)
  String get name => fullName ?? email ?? 'Tenant';
}