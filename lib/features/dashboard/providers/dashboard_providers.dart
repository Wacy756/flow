import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/application.dart';
import '../models/compliance_certificate.dart';
import '../models/compliance_doc.dart';
import '../models/contractor_document.dart';
import '../models/contractor_profile.dart';
import '../models/incident_comment.dart';
import '../models/job_rating.dart';
import '../models/notification_item.dart';
import '../models/plan.dart';
import '../models/pet_request.dart';
import '../models/property_listing.dart';
import '../models/rent_payment.dart';
import '../models/rent_review.dart';
import '../models/section8_ground.dart';
import '../models/service_area.dart';
import '../models/incident.dart';
import '../models/property_record.dart';
import '../models/tenancy.dart';
import '../../../core/theme/app_colors.dart';
import '../models/alert_item.dart';

part 'dashboard_providers.g.dart';

// ---------------------------------------------------------------------------
// Deep-link state — set by NotificationCentre, read by dashboards
// ---------------------------------------------------------------------------

/// ID of the incident that was tapped in the Notification Centre.
/// Dashboards watch this to scroll-to + highlight the matching card.
final deepLinkIncidentIdProvider = StateProvider<String?>((ref) => null);

/// ID of the tenancy that was tapped in the Notification Centre.
/// Dashboards watch this to scroll-to + expand the matching card.
final deepLinkTenancyIdProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class UserProfile {
  final String id;
  final String fullName;
  final String role;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bankAccountName;
  final String? bankSortCode;
  final String? bankAccountNumber;
  final bool onboardingCompleted;
  final bool isAdmin;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bankAccountName,
    this.bankSortCode,
    this.bankAccountNumber,
    this.onboardingCompleted = false,
    this.isAdmin = false,
  });
}

// ---------------------------------------------------------------------------
// Platform settings — feature flags controlled by admin via Supabase dashboard
// ---------------------------------------------------------------------------

class PlatformSettings {
  final bool tdsEnabled;
  final bool gcEnabled;
  final bool epcEnabled;
  final bool dpsEnabled;
  final bool repositEnabled;

  const PlatformSettings({
    this.tdsEnabled     = false,
    this.gcEnabled      = false,
    this.epcEnabled     = false,
    this.dpsEnabled     = false,
    this.repositEnabled = false,
  });

  bool get anyDepositEnabled => tdsEnabled || dpsEnabled || repositEnabled;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) => PlatformSettings(
    tdsEnabled:     json['tds_enabled']     as bool? ?? false,
    gcEnabled:      json['gc_enabled']      as bool? ?? false,
    epcEnabled:     json['epc_enabled']     as bool? ?? false,
    dpsEnabled:     json['dps_enabled']     as bool? ?? false,
    repositEnabled: json['reposit_enabled'] as bool? ?? false,
  );
}

@riverpod
Future<PlatformSettings> platformSettings(Ref ref) async {
  try {
    final row = await supabase
        .from('platform_settings')
        .select('tds_enabled, gc_enabled, epc_enabled, dps_enabled, reposit_enabled')
        .eq('id', 1)
        .single();
    return PlatformSettings.fromJson(Map<String, dynamic>.from(row as Map));
  } catch (_) {
    return const PlatformSettings();
  }
}

@riverpod
Future<UserProfile?> currentProfile(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select('full_name, role, onboarding_completed, phone, avatar_url, bank_account_name, bank_sort_code, bank_account_number, is_admin')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) {
    return UserProfile(
      id: user.id,
      fullName: user.userMetadata?['full_name'] as String? ?? 'User',
      role: user.userMetadata?['role'] as String? ?? '',
      email: user.email,
      onboardingCompleted: false,
    );
  }

  return UserProfile(
    id: user.id,
    fullName: data['full_name'] as String? ?? 'User',
    role: data['role'] as String? ?? '',
    email: user.email,
    phone: data['phone'] as String?,
    avatarUrl: data['avatar_url'] as String?,
    bankAccountName: data['bank_account_name'] as String?,
    bankSortCode: data['bank_sort_code'] as String?,
    bankAccountNumber: data['bank_account_number'] as String?,
    onboardingCompleted: data['onboarding_completed'] as bool? ?? false,
    isAdmin: data['is_admin'] as bool? ?? false,
  );
}

// ---------------------------------------------------------------------------
// Plan
// ---------------------------------------------------------------------------

/// Derives the current user's plan from their profile's selected_plan field.
@riverpod
Future<AbodePlan> currentPlan(Ref ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return AbodePlan.free;
  final data = await supabase
      .from('profiles')
      .select('selected_plan')
      .eq('id', profile.id)
      .maybeSingle();
  return AbodePlan.fromString(data?['selected_plan'] as String?);
}

// ---------------------------------------------------------------------------
// Landlord — tenancies
// ---------------------------------------------------------------------------

@riverpod
Future<List<Tenancy>> landlordTenancies(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final rows = await supabase
      .from('tenancies')
      .select(
        '*, tenant:profiles!tenant_id(full_name, email), '
        'property:properties!property_id('
          'address_line_1, address_line_2, address_line_3, town, postcode, '
          'latitude, longitude, property_type, num_bedrooms, num_bathrooms, '
          'max_tenants, furnishing'
        ')',
      )
      .eq('landlord_id', user.id)
      .not('status', 'eq', 'ended')
      .order('created_at', ascending: false);

  final raw = List<Map<String, dynamic>>.from(rows as List);

  // Group by tenancy_id so all co-tenants appear under one property card
  final Map<String, Tenancy> grouped = {};
  for (final row in raw) {
    final t = Tenancy.fromJson(row);
    if (grouped.containsKey(t.tenancyId)) {
      final existing = grouped[t.tenancyId]!;
      final tenant = t.tenant != null
          ? TenantProfile(
              id: t.id,
              fullName: t.tenant!.fullName,
              email: t.tenant!.email,
              status: t.status,
            )
          : null;
      grouped[t.tenancyId] = existing.copyWith(
        tenants: [
          ...existing.tenants,
          if (tenant != null) tenant,
        ],
      );
    } else {
      final tenants = t.tenant != null
          ? [
              TenantProfile(
                id: t.id,
                fullName: t.tenant!.fullName,
                email: t.tenant!.email,
                status: t.status,
              ),
            ]
          : <TenantProfile>[];
      grouped[t.tenancyId] = t.copyWith(tenants: tenants);
    }
  }

  return grouped.values.toList();
}

// ---------------------------------------------------------------------------
// Landlord — all properties (including vacant ones with no tenancy yet)
// ---------------------------------------------------------------------------

@riverpod
Future<List<PropertyRecord>> landlordProperties(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final rows = await supabase
      .from('properties')
      .select(
        'id, landlord_id, address_line_1, address_line_2, town, postcode, '
        'property_type, num_bedrooms, num_bathrooms, agent_id, created_at, '
        'epc_rating, epc_score, epc_cert_url, epc_expiry_date, epc_fetched_at, '
        'tenancies!property_id('
          'id, status, monthly_rent, start_date, end_date, '
          'tenant:profiles!tenant_id(full_name, email)'
        ')',
      )
      .eq('landlord_id', user.id)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => PropertyRecord.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Landlord — incidents
// ---------------------------------------------------------------------------

@riverpod
Future<List<Incident>> landlordIncidents(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  // Get all tenancy IDs for this landlord first
  final tenancyRows = await supabase
      .from('tenancies')
      .select('id')
      .eq('landlord_id', user.id);

  final ids = (tenancyRows as List)
      .map((r) => r['id'] as String)
      .toList();

  if (ids.isEmpty) return [];

  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), '
          'tenancy:tenancies!tenancy_id(property:properties!property_id(address_line_1, postcode))')
      .inFilter('tenancy_id', ids)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Compliance docs (per property) — used by tenancy card
// ---------------------------------------------------------------------------

@riverpod
Future<List<ComplianceDoc>> complianceDocs(
  Ref ref,
  String tenancyId,
) async {
  final rows = await supabase
      .from('compliance_docs')
      .select('*')
      .eq('tenancy_id', tenancyId);

  return (rows as List)
      .map((r) => ComplianceDoc.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Compliance summary — drives the dashboard alert banner
// ---------------------------------------------------------------------------

class ComplianceSummary {
  final int expiringSoon; // within 60 days
  final int expired;

  const ComplianceSummary({
    required this.expiringSoon,
    required this.expired,
  });

  bool get hasAlerts => expiringSoon > 0 || expired > 0;
  int get total => expiringSoon + expired;
}

@riverpod
Future<ComplianceSummary> complianceSummary(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return const ComplianceSummary(expiringSoon: 0, expired: 0);

  try {
    // Fetch all compliance docs across landlord's properties
    final tenancyRows = await supabase
        .from('tenancies')
        .select('tenancy_id')
        .eq('landlord_id', user.id);

    final propertyIds = (tenancyRows as List)
        .map((r) => r['tenancy_id'] as String)
        .toSet()
        .toList();

    if (propertyIds.isEmpty) {
      return const ComplianceSummary(expiringSoon: 0, expired: 0);
    }

    final docRows = await supabase
        .from('compliance_docs')
        .select('expiry_date')
        .inFilter('tenancy_id', propertyIds)
        .not('expiry_date', 'is', null);

    int expiringSoon = 0;
    int expired = 0;
    final now = DateTime.now();

    for (final row in (docRows as List)) {
      final expiry = DateTime.tryParse(row['expiry_date'] as String? ?? '');
      if (expiry == null) continue;
      final days = expiry.difference(now).inDays;
      if (days < 0) {
        expired++;
      } else if (days <= 60) {
        expiringSoon++;
      }
    }

    return ComplianceSummary(expiringSoon: expiringSoon, expired: expired);
  } catch (e, st) {
    dev.log('complianceSummaryProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return const ComplianceSummary(expiringSoon: 0, expired: 0);
  }
}

// ---------------------------------------------------------------------------
// Incident action (approve / approve_quote)
// ---------------------------------------------------------------------------

@riverpod
class IncidentActions extends _$IncidentActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> approveIncident(String incidentId) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('incidents')
          .update({'status': 'approved'})
          .eq('id', incidentId);
      state = const AsyncData(null);
      ref.invalidate(landlordIncidentsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> approveQuote(String incidentId, {double? quoteAmount}) async {
    state = const AsyncLoading();
    try {
      // Fetch incident to get contractor_id and quote_amount if not passed
      final row = await supabase
          .from('incidents')
          .select('contractor_id, quote_amount')
          .eq('id', incidentId)
          .maybeSingle();

      final amount = quoteAmount ?? (row?['quote_amount'] as num?)?.toDouble();
      final contractorId = row?['contractor_id'] as String?;

      // Calculate the 4% platform fee split
      final fee    = amount != null ? amount * 0.04 : null;
      final payout = amount != null ? amount - fee! : null;

      await supabase.from('incidents').update({
        'status':            'in_progress',
        'quote_accepted_at': DateTime.now().toIso8601String(),
        // Re-writing quote_amount ensures the server-side trg_calculate_payout
        // trigger fires and computes the authoritative platform_fee / payout.
        if (amount != null) 'quote_amount': amount,
        'payment_status':    'unpaid',
      }).eq('id', incidentId);

      // Notify the contractor
      if (contractorId != null) {
        await supabase.from('notifications').insert({
          'user_id': contractorId,
          'type':    'quote_accepted',
          'title':   'Quote accepted!',
          'body':    amount != null
              ? 'Your quote of £${amount.toStringAsFixed(0)} has been accepted. You can now begin work.'
              : 'Your quote has been accepted. You can now begin work.',
          'data': {'incident_id': incidentId},
        });
      }

      state = const AsyncData(null);
      ref.invalidate(landlordIncidentsProvider);
      ref.invalidate(contractorJobsProvider);
      ref.invalidate(tenantIncidentsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> declineQuote(String incidentId) async {
    state = const AsyncLoading();
    try {
      // Fetch contractor_id before clearing it
      final row = await supabase
          .from('incidents')
          .select('contractor_id, quote_amount')
          .eq('id', incidentId)
          .maybeSingle();
      final contractorId = row?['contractor_id'] as String?;
      final amount = (row?['quote_amount'] as num?)?.toDouble();

      // Reset job to approved — clears contractor so it re-enters the pool
      await supabase.from('incidents').update({
        'status':        'approved',
        'contractor_id': null,
        'quote_amount':  null,
        'platform_fee':  null,
        'contractor_payout': null,
      }).eq('id', incidentId);

      // Notify the contractor
      if (contractorId != null) {
        await supabase.from('notifications').insert({
          'user_id': contractorId,
          'type':    'quote_declined',
          'title':   'Quote not accepted',
          'body':    amount != null
              ? 'Your quote of £${amount.toStringAsFixed(0)} was not accepted. The job is now available again.'
              : 'Your quote was not accepted. The job is now available again.',
          'data': {'incident_id': incidentId},
        });
      }

      state = const AsyncData(null);
      ref.invalidate(landlordIncidentsProvider);
      ref.invalidate(tenantIncidentsProvider);
      ref.invalidate(contractorJobsProvider);
      ref.invalidate(availableJobsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Resolve dispute
// ---------------------------------------------------------------------------

@riverpod
class ResolveDispute extends _$ResolveDispute {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// [resolution] must be 'favour_contractor' or 'favour_landlord'
  Future<void> resolve(String incidentId, String resolution) async {
    state = const AsyncLoading();
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final favourContractor = resolution == 'favour_contractor';
      final payoutStatus = favourContractor ? 'released' : 'withheld';

      await supabase.from('incidents').update({
        'status':               'completed',
        'payout_status':        payoutStatus,
        'dispute_resolved_at':  DateTime.now().toIso8601String(),
        'dispute_resolution':   resolution,
        'dispute_resolved_by':  user.id,
      }).eq('id', incidentId);

      // Release payout via edge function so payout_releases log is written
      // and the contractor gets the "Payment released" notification.
      if (favourContractor) {
        try {
          await supabase.functions.invoke('release-payout', body: {'job_id': incidentId});
        } catch (_) {
          // Edge function failure is non-fatal — payout_status already set above
        }
      }

      // Notify both parties
      final row = await supabase
          .from('incidents')
          .select('contractor_id, tenant_id')
          .eq('id', incidentId)
          .maybeSingle();

      final contractorId = row?['contractor_id'] as String?;

      if (contractorId != null) {
        final body = payoutStatus == 'released'
            ? 'The landlord has accepted your response. Payment will be released shortly.'
            : 'The landlord has decided to withhold payment. Contact Abode support if you disagree.';
        await supabase.from('notifications').insert({
          'user_id':     contractorId,
          'type':        'dispute_resolved',
          'title':       'Dispute resolved',
          'body':        body,
          'data': {'incident_id': incidentId},
        });
      }

      state = const AsyncData(null);
      ref.invalidate(landlordIncidentsProvider);
      ref.invalidate(contractorJobsProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ---------------------------------------------------------------------------
// Add tenancy
// ---------------------------------------------------------------------------

@riverpod
class AddTenancy extends _$AddTenancy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required Map<String, dynamic> formData,
    required List<String> tenantEmails,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }

    try {
      final errors = <String>[];
      final validTenants = <Map<String, dynamic>>[];

      // Get landlord name for invitation emails
      final landlordProfile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final landlordName =
          (landlordProfile?['full_name'] as String?) ?? 'Your landlord';

      // Unregistered emails — still send invitation email, skip tenancy creation
      final unregisteredEmails = <String>[];

      // If no emails provided, skip tenant validation entirely —
      // the property will be created with no tenancy rows attached.
      if (tenantEmails.isEmpty) {
        // Phase 2 (property creation only) runs further below — fall through.
      }

      // Phase 1: validate all tenant emails and check for duplicates
      for (final email in tenantEmails) {
        final profile = await supabase
            .from('profiles')
            .select('id, role')
            .eq('email', email)
            .maybeSingle();

        if (profile == null) {
          // Not on Flow yet — queue invitation email, don't block submit
          unregisteredEmails.add(email);
          continue;
        }
        if (profile['role'] != 'tenant') {
          errors.add('$email: User is not registered as a tenant.');
          continue;
        }

        // Check for duplicate: tenant already on a property with same address
        final existingTenancies = await supabase
            .from('tenancies')
            .select(
              'id, property:properties!property_id(address_line_1, postcode)',
            )
            .eq('landlord_id', user.id)
            .eq('tenant_id', profile['id'] as String);

        bool isDuplicate = false;
        for (final row in (existingTenancies as List)) {
          final prop = row['property'];
          if (prop is Map<String, dynamic> &&
              prop['postcode']?.toString().toUpperCase() ==
                  (formData['postcode'] as String?)?.toUpperCase() &&
              prop['address_line_1'] == formData['address_line_1']) {
            isDuplicate = true;
            break;
          }
        }

        if (isDuplicate) {
          errors.add('$email: Already invited to this property.');
          continue;
        }

        validTenants.add(profile);
      }

      // Only block if the caller supplied emails but ALL of them failed validation.
      // If no emails were supplied at all we fall through and create property-only.
      if (tenantEmails.isNotEmpty &&
          validTenants.isEmpty &&
          unregisteredEmails.isEmpty) {
        state = AsyncError(errors.join('\n'), StackTrace.current);
        return false;
      }

      // Phase 2: create the property
      final propertyRow = await supabase.from('properties').insert({
        'landlord_id': user.id,
        'address_line_1': formData['address_line_1'] ?? '',
        'address_line_2': formData['address_line_2'],
        'address_line_3': formData['address_line_3'],
        'town': formData['town'],
        'postcode': formData['postcode'] ?? '',
        'latitude': formData['latitude'],
        'longitude': formData['longitude'],
        'property_type': formData['property_type'],
        'num_bedrooms': formData['num_bedrooms'],
        'num_bathrooms': formData['num_bathrooms'],
        'max_tenants': formData['max_tenants'],
        'furnishing': formData['furnishing'],
      }).select('id').single();

      final propertyId = propertyRow['id'] as String;
      int successCount = 0;

      // Phase 3: create one tenancy row per valid tenant
      for (final profile in validTenants) {
        final insertError = await _insertTenancy(
          landlordId: user.id,
          tenantId: profile['id'] as String,
          propertyId: propertyId,
          formData: formData,
        );

        if (insertError != null) {
          errors.add('${profile['email'] ?? profile['id']}: $insertError');
        } else {
          successCount++;
        }
      }

      // Refresh dashboard whenever the property was created, even with no tenants.
      if (successCount > 0 || tenantEmails.isEmpty) {
        ref.invalidate(landlordTenanciesProvider);
      }

      // Phase 4: create pending tenancy rows + send invitation emails for unregistered emails
      final address =
          '${formData['address_line_1'] ?? ''}, ${formData['postcode'] ?? ''}'
              .trim()
              .replaceAll(RegExp(r'^,\s*|,\s*$'), '');
      for (final email in unregisteredEmails) {
        await _insertPendingTenancy(
          landlordId: user.id,
          propertyId: propertyId,
          invitedEmail: email,
          formData: formData,
        );
        await _sendInvitationEmail(
          tenantEmail: email,
          landlordName: landlordName,
          propertyAddress: address,
          tenancyId: propertyId,
        );
      }
      if (unregisteredEmails.isNotEmpty) {
        ref.invalidate(landlordTenanciesProvider);
      }

      if (errors.isNotEmpty) {
        state = AsyncError(errors.join('\n'), StackTrace.current);
        return successCount > 0 ||
            unregisteredEmails.isNotEmpty ||
            tenantEmails.isEmpty;
      }

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<String?> _insertTenancy({
    required String landlordId,
    required String tenantId,
    required String propertyId,
    required Map<String, dynamic> formData,
  }) async {
    try {
      await supabase.from('tenancies').insert({
        'landlord_id': landlordId,
        'tenant_id': tenantId,
        'property_id': propertyId,
        'tenancy_id': propertyId, // group key equals property id
        'status': 'pending',
        'monthly_rent': formData['monthly_rent'],
        'weekly_rent': formData['weekly_rent'],
        'deposit_amount': formData['deposit_amount'],
        'min_tenancy_length': formData['min_tenancy_length'],
        'move_in_date': formData['move_in_date'],
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Creates a tenancy row for an unregistered tenant. The row has no
  /// tenant_id but stores the invited email so auth_notifier.dart can
  /// auto-link the account when the tenant signs up.
  Future<void> _insertPendingTenancy({
    required String landlordId,
    required String propertyId,
    required String invitedEmail,
    required Map<String, dynamic> formData,
  }) async {
    try {
      await supabase.from('tenancies').insert({
        'landlord_id': landlordId,
        'property_id': propertyId,
        'tenancy_id': propertyId,
        'invited_email': invitedEmail,
        'status': 'pending',
        'monthly_rent': formData['monthly_rent'],
        'weekly_rent': formData['weekly_rent'],
        'deposit_amount': formData['deposit_amount'],
        'min_tenancy_length': formData['min_tenancy_length'],
        'move_in_date': formData['move_in_date'],
      });
    } catch (e, st) {
      dev.log('_insertPendingTenancy failed',
          error: e, stackTrace: st, name: 'dashboard');
    }
  }

  Future<void> _sendInvitationEmail({
    required String tenantEmail,
    required String landlordName,
    required String propertyAddress,
    required String tenancyId,
  }) async {
    try {
      await supabase.functions.invoke(
        'send-invitation-email',
        body: {
          'tenant_email': tenantEmail,
          'landlord_name': landlordName,
          'property_address': propertyAddress,
          'tenancy_id': tenancyId,
        },
      );
    } catch (e, st) {
      // Non-fatal — log but don't surface to user
      dev.log('_sendInvitationEmail failed',
          error: e, stackTrace: st, name: 'dashboard');
    }
  }
}

// ---------------------------------------------------------------------------
// Tenancy end — serve notice
// ---------------------------------------------------------------------------

@riverpod
class ServeNotice extends _$ServeNotice {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> serve({
    required String tenancyGroupId,
    required String noticeType,
    required String vacateDate,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('tenancies').update({
        'status': 'notice_given',
        'notice_given_at': DateTime.now().toIso8601String(),
        'notice_type': noticeType,
        'vacate_date': vacateDate,
      }).eq('id', tenancyGroupId);
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tenancy end — finalise / end tenancy
// ---------------------------------------------------------------------------

@riverpod
class EndTenancy extends _$EndTenancy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> end({
    required String tenancyGroupId,
    required String endOfTenancyDate,
    bool depositReturned = false,
    double? depositDeductionAmount,
    String? depositDeductionReason,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('tenancies').update({
        'status': 'ended',
        'end_of_tenancy_date': endOfTenancyDate,
        if (depositReturned)
          'deposit_returned_at': DateTime.now().toIso8601String(),
        if (depositDeductionAmount != null)
          'deposit_deduction_amount': depositDeductionAmount,
        if (depositDeductionReason != null)
          'deposit_deduction_reason': depositDeductionReason,
      }).eq('id', tenancyGroupId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(endedTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Ended tenancies — previous tenancies section on landlord dashboard
// ---------------------------------------------------------------------------

@riverpod
Future<List<Tenancy>> endedTenancies(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final rows = await supabase
      .from('tenancies')
      .select(
        '*, tenant:profiles!tenant_id(full_name, email), '
        'property:properties!property_id('
          'address_line_1, address_line_2, address_line_3, town, postcode, '
          'latitude, longitude, property_type, num_bedrooms, num_bathrooms, '
          'max_tenants, furnishing'
        ')',
      )
      .eq('landlord_id', user.id)
      .eq('status', 'ended')
      .order('end_of_tenancy_date', ascending: false);

  final raw = List<Map<String, dynamic>>.from(rows as List);

  final Map<String, Tenancy> grouped = {};
  for (final row in raw) {
    final t = Tenancy.fromJson(row);
    if (grouped.containsKey(t.tenancyId)) {
      final existing = grouped[t.tenancyId]!;
      final tenant = t.tenant != null
          ? TenantProfile(
              id: t.id,
              fullName: t.tenant!.fullName,
              email: t.tenant!.email,
              status: t.status,
            )
          : null;
      grouped[t.tenancyId] = existing.copyWith(
        tenants: [...existing.tenants, if (tenant != null) tenant],
      );
    } else {
      final tenants = t.tenant != null
          ? [
              TenantProfile(
                id: t.id,
                fullName: t.tenant!.fullName,
                email: t.tenant!.email,
                status: t.status,
              ),
            ]
          : <TenantProfile>[];
      grouped[t.tenancyId] = t.copyWith(tenants: tenants);
    }
  }

  return grouped.values.toList();
}

// ---------------------------------------------------------------------------
// Delete tenancy
// ---------------------------------------------------------------------------

@riverpod
class DeleteTenancy extends _$DeleteTenancy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> delete(String tenancyGroupId) async {
    state = const AsyncLoading();
    try {
      // tenancyGroupId == property id (tenancy_id column equals property_id after migration)
      // Deleting the property cascades to delete all associated tenancy rows
      await supabase
          .from('properties')
          .delete()
          .eq('id', tenancyGroupId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordPropertiesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tenant — tenancies
// ---------------------------------------------------------------------------

@riverpod
Future<List<Tenancy>> tenantTenancies(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  const selectClause =
      '*, landlord_id, '
      'landlord:profiles!landlord_id('
        'full_name, email, bank_account_name, bank_sort_code, bank_account_number'
      '), '
      'property:properties!property_id('
        'address_line_1, address_line_2, address_line_3, town, postcode, '
        'latitude, longitude, property_type, num_bedrooms, num_bathrooms, '
        'max_tenants, furnishing'
      ')';

  // 1. Tenancies where this user is already the tenant
  final myRows = await supabase
      .from('tenancies')
      .select(selectClause)
      .eq('tenant_id', user.id)
      .order('created_at', ascending: false);

  // 2. Pending offers sent to this user's email (tenant_id not yet claimed)
  final offerRows = user.email != null
      ? await supabase
          .from('tenancies')
          .select(selectClause)
          .eq('invited_email', user.email!)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
      : <dynamic>[];

  // Merge, deduplicating by id
  final seen = <String>{};
  final merged = <Tenancy>[];
  for (final row in [...(myRows as List), ...(offerRows as List)]) {
    final t = Tenancy.fromJson(Map<String, dynamic>.from(row as Map));
    if (seen.add(t.id)) merged.add(t);
  }
  return merged;
}

// ---------------------------------------------------------------------------
// Tenant — incidents
// ---------------------------------------------------------------------------

@riverpod
Future<List<Incident>> tenantIncidents(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final tenancyRows = await supabase
      .from('tenancies')
      .select('id')
      .eq('tenant_id', user.id);

  final ids = (tenancyRows as List).map((r) => r['id'] as String).toList();
  if (ids.isEmpty) return [];

  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), '
          'tenancy:tenancies!tenancy_id(property:properties!property_id(address_line_1, postcode))')
      .inFilter('tenancy_id', ids)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Holding deposit
// ---------------------------------------------------------------------------

@riverpod
class HoldingDeposit extends _$HoldingDeposit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Landlord requests a holding deposit — saves bank details to profile,
  /// creates the holding deposit record on the tenancy.
  Future<bool> request({
    required String tenancyId,
    required double amount,
    required String reference,
    required String bankAccountName,
    required String sortCode,
    required String accountNumber,
  }) async {
    state = const AsyncLoading();
    try {
      final user = supabase.auth.currentUser!;

      // Save bank details to profile (once)
      await supabase.from('profiles').update({
        'bank_account_name':   bankAccountName,
        'bank_sort_code':      sortCode,
        'bank_account_number': accountNumber,
      }).eq('id', user.id);

      // Create holding deposit request on tenancy
      await supabase.from('tenancies').update({
        'holding_deposit_amount':       amount,
        'holding_deposit_status':       'requested',
        'holding_deposit_reference':    reference,
        'holding_deposit_requested_at': DateTime.now().toIso8601String(),
      }).eq('id', tenancyId);

      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(tenantTenanciesProvider);
      ref.invalidate(currentProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Tenant marks payment as sent
  Future<bool> tenantConfirm(String tenancyId) async {
    state = const AsyncLoading();
    try {
      await supabase.from('tenancies').update({
        'holding_deposit_status':       'tenant_confirmed',
        'holding_deposit_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', tenancyId);
      ref.invalidate(tenantTenanciesProvider);
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Landlord confirms they received the payment
  Future<bool> markReceived(String tenancyId) async {
    state = const AsyncLoading();
    try {
      await supabase.from('tenancies').update({
        'holding_deposit_status':      'received',
        'holding_deposit_received_at': DateTime.now().toIso8601String(),
      }).eq('id', tenancyId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(tenantTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// Tenant — accept invitation
// ---------------------------------------------------------------------------

@riverpod
class AcceptInvitation extends _$AcceptInvitation {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> accept(String tenancyRowId) async {
    state = const AsyncLoading();
    try {
      final userId = supabase.auth.currentUser?.id;
      await supabase.from('tenancies').update({
        'status': 'active',
        if (userId != null) 'tenant_id': userId,
        'invited_email': null,
      }).eq('id', tenancyRowId);
      ref.invalidate(tenantTenanciesProvider);
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> decline(String tenancyRowId) async {
    state = const AsyncLoading();
    try {
      // Delete the pending row — no need to keep a declined offer
      await supabase
          .from('tenancies')
          .delete()
          .eq('id', tenancyRowId)
          .eq('status', 'pending');
      ref.invalidate(tenantTenanciesProvider);
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Landlord — accept or decline a submitted tenant offer
// ---------------------------------------------------------------------------

@riverpod
class LandlordOfferDecision extends _$LandlordOfferDecision {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> accept(String tenancyRowId, {DateTime? startDate}) async {
    state = const AsyncLoading();
    try {
      await supabase.from('tenancies').update({
        'status': 'active',
        'invited_email': null,
        if (startDate != null) 'start_date': startDate.toIso8601String(),
      }).eq('id', tenancyRowId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordPropertiesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> decline(String tenancyRowId) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('tenancies')
          .delete()
          .eq('id', tenancyRowId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordPropertiesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tenant — ended tenancies (previous tenancy history)
// ---------------------------------------------------------------------------

@riverpod
Future<List<Tenancy>> tenantEndedTenancies(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  try {
    final rows = await supabase
        .from('tenancies')
        .select(
          '*, landlord:profiles!landlord_id(full_name, email), '
          'property:properties!property_id('
            'address_line_1, address_line_2, address_line_3, town, postcode, '
            'latitude, longitude, property_type, num_bedrooms, num_bathrooms, '
            'max_tenants, furnishing'
          ')',
        )
        .eq('tenant_id', user.id)
        .eq('status', 'ended')
        .order('end_of_tenancy_date', ascending: false);

    return (rows as List)
        .map((r) => Tenancy.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('tenantEndedTenanciesProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Tenant — create incident
// ---------------------------------------------------------------------------

@riverpod
class CreateIncident extends _$CreateIncident {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required String tenancyId,
    required String title,
    required String description,
    String? category,
    bool isEmergency = false,
    List<String> mediaUrls = const [],
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('incidents').insert({
        'tenancy_id': tenancyId,
        'tenant_id': user.id,
        'title': title,
        'description': description,
        if (category != null) 'category': category,
        'status': 'reported',
        'is_emergency': isEmergency,
        if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      });
      ref.invalidate(tenantIncidentsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tenant — mark incident complete
// ---------------------------------------------------------------------------

@riverpod
class TenantMarkComplete extends _$TenantMarkComplete {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Returns true when the job is now fully completed (both parties done).
  Future<bool> markComplete(String incidentId) async {
    state = const AsyncLoading();
    try {
      final current = await supabase
          .from('incidents')
          .select('is_contractor_completed, contractor_id, title')
          .eq('id', incidentId)
          .single();

      final bothDone = current['is_contractor_completed'] == true;
      await supabase.from('incidents').update({
        'is_tenant_completed': true,
        if (bothDone) 'status': 'completed',
      }).eq('id', incidentId);

      // Notify contractor that tenant confirmed
      final contractorId = current['contractor_id'] as String?;
      if (contractorId != null) {
        final title = current['title'] as String? ?? 'Job';
        await supabase.from('notifications').insert({
          'user_id':     contractorId,
          'type':        'job_confirmed',
          'title':       bothDone ? 'Job complete — well done!' : 'Tenant confirmed work done',
          'body':        bothDone
              ? '$title has been marked complete by both parties. Payment will be processed.'
              : '$title: The tenant has confirmed the work is done.',
          'data': {'incident_id': incidentId},
        });
      }

      ref.invalidate(tenantIncidentsProvider);
      ref.invalidate(landlordIncidentsProvider);
      ref.invalidate(contractorJobsProvider);
      state = const AsyncData(null);
      return bothDone; // caller shows rating sheet only on full completion
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — profile (contractor_details table)
// ---------------------------------------------------------------------------

@riverpod
Future<ContractorDetails?> contractorProfile(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final row = await supabase
      .from('contractor_details')
      .select('*')
      .eq('contractor_id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return ContractorDetails.fromJson(Map<String, dynamic>.from(row));
}

// ---------------------------------------------------------------------------
// Contractor — my jobs (assigned to me)
// ---------------------------------------------------------------------------

@riverpod
Future<List<Incident>> contractorJobs(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), '
          'tenancy:tenancies!tenancy_id(property:properties!property_id(address_line_1, postcode))')
      .eq('contractor_id', user.id)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Contractor — available jobs (approved, unassigned)
// ---------------------------------------------------------------------------

@riverpod
Future<List<Incident>> availableJobs(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  // Guard: only approved contractors may fetch available jobs
  final cpRow = await supabase
      .from('contractor_details')
      .select('verification_status, service_areas')
      .eq('contractor_id', user.id)
      .maybeSingle();
  if (cpRow == null || cpRow['verification_status'] != 'approved') return [];

  // Extract postcode prefixes from service areas
  final rawAreas = cpRow['service_areas'];
  final prefixes = rawAreas is List
      ? rawAreas
          .map((a) => (a is Map ? a['postcode_prefix']?.toString() ?? '' : '').toUpperCase())
          .where((s) => s.isNotEmpty)
          .toList()
      : <String>[];

  // If no service areas configured, return empty before hitting the DB
  if (prefixes.isEmpty) return [];

  final rows = await supabase
      .from('incidents')
      .select('*')
      .eq('status', 'approved')
      .isFilter('contractor_id', null)
      .order('created_at', ascending: false);

  // Filter in Dart using the denormalized property_postcode column (no join needed)
  return (rows as List)
      .where((r) {
        final map = r as Map;
        final declined = (map['declined_by'] as List? ?? []);
        if (declined.contains(user.id)) return false;
        final postcode = ((map['property_postcode'] as String?) ?? '').toUpperCase();
        return prefixes.any((prefix) => postcode.startsWith(prefix));
      })
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Contractor — submit quote
// ---------------------------------------------------------------------------

@riverpod
class SubmitQuote extends _$SubmitQuote {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit(String incidentId, double amount) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('incidents').update({
        'status': 'quoted',
        'quote_amount': amount,
        'contractor_id': user.id,
      }).eq('id', incidentId);
      ref.invalidate(contractorJobsProvider);
      ref.invalidate(availableJobsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — decline job
// ---------------------------------------------------------------------------

@riverpod
class DeclineJob extends _$DeclineJob {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> decline(String incidentId) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.rpc('append_declined_by', params: {
        'p_incident_id':    incidentId,
        'p_contractor_id':  user.id,
      });

      ref.invalidate(availableJobsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — release job (unassign, returns to available pool)
// ---------------------------------------------------------------------------

@riverpod
class ReleaseJob extends _$ReleaseJob {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> release(String incidentId) async {
    state = const AsyncLoading();
    try {
      final row = await supabase
          .from('incidents')
          .select('tenant_id, title')
          .eq('id', incidentId)
          .maybeSingle();

      await supabase.from('incidents').update({
        'status':                'approved',
        'contractor_id':         null,
        'visit_slots':           <dynamic>[],
        'confirmed_visit_slot':  null,
      }).eq('id', incidentId);

      // Notify tenant so they're not left wondering
      final tenantId = row?['tenant_id'] as String?;
      if (tenantId != null) {
        final title = row?['title'] as String? ?? 'A job';
        await supabase.from('notifications').insert({
          'user_id':     tenantId,
          'type':        'contractor_released',
          'title':       'Looking for a new contractor',
          'body':        '$title: The contractor is no longer available. '
                         'We\'re finding someone else.',
          'data': {'incident_id': incidentId},
        });
      }

      ref.invalidate(contractorJobsProvider);
      ref.invalidate(availableJobsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — mark job complete
// ---------------------------------------------------------------------------

@riverpod
class ContractorMarkComplete extends _$ContractorMarkComplete {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> markComplete(String incidentId) async {
    state = const AsyncLoading();
    try {
      final current = await supabase
          .from('incidents')
          .select('is_tenant_completed, tenant_id, title')
          .eq('id', incidentId)
          .single();

      final bothDone = current['is_tenant_completed'] == true;
      await supabase.from('incidents').update({
        'is_contractor_completed': true,
        if (bothDone) 'status': 'completed',
      }).eq('id', incidentId);

      // Notify tenant to confirm (or celebrate completion)
      final tenantId = current['tenant_id'] as String?;
      if (tenantId != null) {
        final title = current['title'] as String? ?? 'Job';
        await supabase.from('notifications').insert({
          'user_id':     tenantId,
          'type':        bothDone ? 'job_confirmed' : 'work_complete',
          'title':       bothDone
              ? '${title.length > 30 ? title.substring(0, 30) + '…' : title} — complete!'
              : 'Work done — please confirm',
          'body':        bothDone
              ? 'Both parties have confirmed this job is complete.'
              : 'Your contractor has marked "$title" as done. Please confirm when you\'re satisfied.',
          'data': {'incident_id': incidentId},
        });
      }

      ref.invalidate(contractorJobsProvider);
      ref.invalidate(landlordIncidentsProvider);
      ref.invalidate(tenantIncidentsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Listing — fetch for a property
// ---------------------------------------------------------------------------

@riverpod
Future<PropertyListing?> propertyListing(Ref ref, String propertyId) async {
  try {
    final row = await supabase
        .from('property_listings')
        .select('*')
        .eq('property_id', propertyId)
        .maybeSingle();
    if (row == null) return null;
    return PropertyListing.fromJson(Map<String, dynamic>.from(row));
  } catch (e, st) {
    dev.log('propertyListingProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Listing — create / update
// ---------------------------------------------------------------------------

@riverpod
class ManageListing extends _$ManageListing {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<PropertyListing?> save({
    required String propertyId,
    required String landlordId,
    required double? askingRent,
    required String? availableFrom,
    required double? depositAmount,
    required int? minTenancyMonths,
    required String? description,
  }) async {
    state = const AsyncLoading();
    try {
      final existing = await supabase
          .from('property_listings')
          .select('id, share_token')
          .eq('property_id', propertyId)
          .maybeSingle();

      final Map<String, dynamic> data = {
        'property_id': propertyId,
        'landlord_id': landlordId,
        'asking_rent': askingRent,
        'available_from': availableFrom,
        'deposit_amount': depositAmount,
        'min_tenancy_months': minTenancyMonths,
        'description': description,
        'is_active': true,
      };

      late Map<String, dynamic> row;
      if (existing != null) {
        row = await supabase
            .from('property_listings')
            .update(data)
            .eq('property_id', propertyId)
            .select()
            .single();
      } else {
        data['share_token'] = _generateToken();
        row = await supabase
            .from('property_listings')
            .insert(data)
            .select()
            .single();
      }

      ref.invalidate(propertyListingProvider(propertyId));
      state = const AsyncData(null);
      return PropertyListing.fromJson(Map<String, dynamic>.from(row));
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  String _generateToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

// ---------------------------------------------------------------------------
// Listing — pause / resume
// ---------------------------------------------------------------------------

@riverpod
class ToggleListing extends _$ToggleListing {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> toggle(String propertyId, {required bool isActive}) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('property_listings')
          .update({'is_active': isActive})
          .eq('property_id', propertyId);
      ref.invalidate(propertyListingProvider(propertyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Apply — fetch listing by share token (public, no auth needed)
// ---------------------------------------------------------------------------

@riverpod
Future<PropertyListing?> listingByToken(Ref ref, String token) async {
  try {
    final row = await supabase
        .from('property_listings')
        .select('*')
        .eq('share_token', token)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return PropertyListing.fromJson(Map<String, dynamic>.from(row));
  } catch (e, st) {
    dev.log('listingByTokenProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Apply — check if current user has already applied
// ---------------------------------------------------------------------------

@riverpod
Future<Application?> myApplication(Ref ref, String listingId) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await supabase
        .from('applications')
        .select('*')
        .eq('listing_id', listingId)
        .eq('applicant_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return Application.fromJson(Map<String, dynamic>.from(row));
  } catch (e, st) {
    dev.log('existingApplicationProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Apply — submit application
// ---------------------------------------------------------------------------

@riverpod
class SubmitApplication extends _$SubmitApplication {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required String listingId,
    required String propertyId,
    required String landlordId,
    required String? employmentStatus,
    required String? employerName,
    required double? monthlyIncome,
    required String? moveInPreference,
    required int numAdults,
    required int numChildren,
    required bool hasPets,
    required String? petDetails,
    required bool isSmoker,
    required bool hasCcj,
    required String? ccjDetails,
    required String? notes,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('applications').insert({
        'listing_id': listingId,
        'property_id': propertyId,
        'landlord_id': landlordId,
        'applicant_id': user.id,
        'employment_status': employmentStatus,
        'employer_name': employerName,
        'monthly_income': monthlyIncome,
        'move_in_preference': moveInPreference,
        'num_adults': numAdults,
        'num_children': numChildren,
        'has_pets': hasPets,
        'pet_details': petDetails,
        'is_smoker': isSmoker,
        'has_ccj': hasCcj,
        'ccj_details': ccjDetails,
        'notes': notes,
        'status': 'pending',
      });
      ref.invalidate(myApplicationProvider(listingId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Landlord — applications for a listing
// ---------------------------------------------------------------------------

@riverpod
Future<List<Application>> listingApplications(
    Ref ref, String listingId) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final rows = await supabase
        .from('applications')
        .select('*, applicant:profiles!applicant_id(full_name, email)')
        .eq('listing_id', listingId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) =>
            Application.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('listingApplicationsProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Landlord — review application (approve / reject)
// ---------------------------------------------------------------------------

@riverpod
class ReviewApplication extends _$ReviewApplication {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> approve(String applicationId, String listingId) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('applications')
          .update({'status': 'approved', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', applicationId);
      ref.invalidate(listingApplicationsProvider(listingId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> reject(String applicationId, String listingId,
      {String? reason}) async {
    state = const AsyncLoading();
    try {
      await supabase.from('applications').update({
        'status': 'rejected',
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', applicationId);
      ref.invalidate(listingApplicationsProvider(listingId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Landlord — all applications across all listings
// ---------------------------------------------------------------------------

@riverpod
Future<List<Application>> landlordApplications(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final rows = await supabase
        .from('applications')
        .select(
            '*, applicant:profiles!applicant_id(full_name, email), listing:property_listings!listing_id(monthly_rent), property:properties!property_id(address_line_1, postcode)')
        .eq('landlord_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) =>
            Application.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordApplicationsProvider error',
        error: e, stackTrace: st, name: 'dashboard');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Notifications — realtime stream for current user
// ---------------------------------------------------------------------------

@riverpod
Stream<List<NotificationItem>> notificationsStream(Ref ref) {
  final user = supabase.auth.currentUser;
  if (user == null) return const Stream.empty();

  return supabase
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(60)
      .map((rows) => rows
          .map((r) => NotificationItem.fromJson(
              Map<String, dynamic>.from(r)))
          .toList());
}

@riverpod
int unreadNotificationCount(Ref ref) {
  final notifications =
      ref.watch(notificationsStreamProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
}

// ---------------------------------------------------------------------------
// Notifications — mark single as read
// ---------------------------------------------------------------------------

@riverpod
class MarkNotificationRead extends _$MarkNotificationRead {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> mark(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      // Stream auto-updates via realtime; no manual invalidation needed
    } catch (e, st) {
      dev.log('markNotificationRead error', error: e, stackTrace: st,
          name: 'dashboard');
    }
  }
}

// ---------------------------------------------------------------------------
// Notifications — mark all as read
// ---------------------------------------------------------------------------

@riverpod
class MarkAllNotificationsRead extends _$MarkAllNotificationsRead {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> markAll() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e, st) {
      dev.log('markAllNotificationsRead error', error: e, stackTrace: st,
          name: 'dashboard');
    }
  }
}

// ---------------------------------------------------------------------------
// Incident comments — fetch thread for an incident
// ---------------------------------------------------------------------------

@riverpod
Future<List<IncidentComment>> incidentComments(
  Ref ref,
  String incidentId,
) async {
  try {
    final rows = await supabase
        .from('incident_comments')
        .select('*, author:profiles!author_id(full_name)')
        .eq('incident_id', incidentId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((r) => IncidentComment.fromJson(
            Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('incidentCommentsProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Incident comments — post a new comment
// ---------------------------------------------------------------------------

@riverpod
class PostIncidentComment extends _$PostIncidentComment {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> post({
    required String incidentId,
    required String body,
    required String authorRole,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('incident_comments').insert({
        'incident_id': incidentId,
        'author_id': user.id,
        'author_role': authorRole,
        'body': body.trim(),
      });
      ref.invalidate(incidentCommentsProvider(incidentId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent payments — fetch for a tenancy group
// ---------------------------------------------------------------------------

@riverpod
Future<List<RentPayment>> rentPayments(Ref ref, String tenancyId) async {
  try {
    final rows = await supabase
        .from('rent_payments')
        .select('*')
        .eq('tenancy_id', tenancyId)
        .order('due_date', ascending: false);

    return (rows as List)
        .map((r) =>
            RentPayment.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('rentPaymentsProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return [];
  }
}

// ---------------------------------------------------------------------------
// Rent payments — log a new payment
// ---------------------------------------------------------------------------

@riverpod
class LogRentPayment extends _$LogRentPayment {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> log({
    required String tenancyId,
    required String landlordId,
    required double amountDue,
    required double amountPaid,
    required String dueDate,
    required String status,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('rent_payments').insert({
        'tenancy_id': tenancyId,
        'landlord_id': landlordId,
        'amount_due': amountDue,
        'amount_paid': amountPaid,
        'due_date': dueDate,
        'status': status,
        if (amountPaid > 0)
          'paid_at': DateTime.now().toIso8601String(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent payments — update an existing entry
// ---------------------------------------------------------------------------

@riverpod
class UpdateRentPayment extends _$UpdateRentPayment {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> update({
    required String paymentId,
    required String tenancyId,
    required double amountPaid,
    required String status,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('rent_payments').update({
        'amount_paid': amountPaid,
        'status': status,
        if (amountPaid > 0)
          'paid_at': DateTime.now().toIso8601String(),
        if (notes != null) 'notes': notes,
      }).eq('id', paymentId);
      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent — tenant flags a payment discrepancy
// Sends an in-app notification to the landlord.
// ---------------------------------------------------------------------------

@riverpod
class FlagRentDiscrepancy extends _$FlagRentDiscrepancy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> flag({
    required String paymentId,
    required String tenancyId,
    required String landlordId,
    required String note,
    required String dueDateFormatted,
  }) async {
    state = const AsyncLoading();
    try {
      // Look up tenant's name for the notification body
      final userId = supabase.auth.currentUser?.id;
      final profileRow = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId ?? '')
          .maybeSingle();
      final tenantName =
          (profileRow?['full_name'] as String?) ?? 'Your tenant';

      // Insert an in-app notification to the landlord
      await supabase.from('notifications').insert({
        'user_id': landlordId,
        'type': 'rent_discrepancy',
        'title': 'Rent Discrepancy Flagged',
        'body': '$tenantName flagged a discrepancy for the payment due $dueDateFormatted',
        'data': {
          'payment_id': paymentId,
          'tenancy_id': tenancyId,
          'note': note,
        },
      });

      // Stamp the payment row so landlord's ledger shows the flag immediately
      await supabase
          .from('rent_payments')
          .update({'notes': 'DISCREPANCY: $note'})
          .eq('id', paymentId);

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      dev.log('FlagRentDiscrepancy failed', error: e, stackTrace: st,
          name: 'dashboard');
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent — landlord resolves a discrepancy (clears the DISCREPANCY: note)
// ---------------------------------------------------------------------------

@riverpod
class ResolveRentDiscrepancy extends _$ResolveRentDiscrepancy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> resolve({
    required String paymentId,
    required String tenancyId,
    String? resolutionNote,
  }) async {
    state = const AsyncLoading();
    try {
      final updatedNote = resolutionNote != null && resolutionNote.isNotEmpty
          ? 'RESOLVED: $resolutionNote'
          : null;
      await supabase
          .from('rent_payments')
          .update({'notes': updatedNote})
          .eq('id', paymentId);
      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      dev.log('ResolveRentDiscrepancy failed', error: e, stackTrace: st, name: 'dashboard');
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent — generate a monthly schedule from tenancy start date
// ---------------------------------------------------------------------------

@riverpod
class GenerateRentSchedule extends _$GenerateRentSchedule {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> generate({
    required String tenancyId,
    required DateTime startDate,
    required double monthlyRent,
    DateTime? endDate,
  }) async {
    state = const AsyncLoading();
    try {
      // Generate up to 12 months (or until end_date)
      final cutoff = endDate ?? DateTime(startDate.year + 1, startDate.month, startDate.day);
      final rows = <Map<String, dynamic>>[];
      var current = DateTime(startDate.year, startDate.month, startDate.day);

      while (!current.isAfter(cutoff)) {
        rows.add({
          'tenancy_id': tenancyId,
          'amount': monthlyRent,
          'amount_due': monthlyRent,
          'amount_paid': 0,
          'due_date': '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}',
          'status': 'due',
        });
        // Next month, same day
        var nextMonth = current.month + 1;
        var nextYear = current.year;
        if (nextMonth > 12) { nextMonth = 1; nextYear++; }
        current = DateTime(nextYear, nextMonth, startDate.day);
      }

      // Insert all — ignore conflicts (in case some already exist)
      if (rows.isNotEmpty) {
        await supabase
            .from('rent_payments')
            .upsert(rows, onConflict: 'tenancy_id,due_date');
      }

      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      dev.log('GenerateRentSchedule failed', error: e, stackTrace: st,
          name: 'dashboard');
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Rent — mark a single payment as paid
// ---------------------------------------------------------------------------

@riverpod
class MarkRentPaid extends _$MarkRentPaid {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> mark({
    required String paymentId,
    required String tenancyId,
    required double amount,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('rent_payments').update({
        'status': 'paid',
        'amount_paid': amount,
        'paid_at': DateTime.now().toIso8601String(),
      }).eq('id', paymentId);
      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — save profile (upsert to contractor_details)
// ---------------------------------------------------------------------------

@riverpod
class SaveContractorDetails extends _$SaveContractorDetails {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> save({
    required List<String> workTypes,
    required List<ServiceArea> serviceAreas,
    String? insuranceCertNumber,
    DateTime? insuranceExpiry,
    String? gasSafeNumber,
    DateTime? gasSafeExpiry,
    String? niceicNumber,
    DateTime? niceicExpiry,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('contractor_details').upsert(
        {
          'contractor_id': user.id,
          'work_types': workTypes,
          'service_areas': serviceAreas.map((a) => a.toJson()).toList(),
          'is_setup_completed': true,
          'updated_at': DateTime.now().toIso8601String(),
          if (insuranceCertNumber != null && insuranceCertNumber.isNotEmpty)
            'insurance_cert_number': insuranceCertNumber,
          if (insuranceExpiry != null)
            'insurance_expiry':
                insuranceExpiry.toIso8601String().substring(0, 10),
          if (gasSafeNumber != null && gasSafeNumber.isNotEmpty)
            'gas_safe_number': gasSafeNumber,
          if (gasSafeExpiry != null)
            'gas_safe_expiry':
                gasSafeExpiry.toIso8601String().substring(0, 10),
          if (niceicNumber != null && niceicNumber.isNotEmpty)
            'niceic_number': niceicNumber,
          if (niceicExpiry != null)
            'niceic_expiry':
                niceicExpiry.toIso8601String().substring(0, 10),
        },
        onConflict: 'contractor_id',
      );
      ref.invalidate(contractorProfileProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> saveBankDetails({
    required String bankAccountName,
    required String sortCode,
    required String accountNumber,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase.from('profiles').update({
        'bank_account_name':   bankAccountName,
        'bank_sort_code':      sortCode,
        'bank_account_number': accountNumber,
      }).eq('id', user.id);
      ref.invalidate(currentProfileProvider);
    } catch (e, st) {
      dev.log('saveBankDetails error', error: e, stackTrace: st, name: 'dashboard');
    }
  }
}

// ---------------------------------------------------------------------------
// Job ratings — fetch existing rating for an incident
// ---------------------------------------------------------------------------

@riverpod
Future<JobRating?> incidentRating(Ref ref, String incidentId) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  try {
    final row = await supabase
        .from('job_ratings')
        .select('*')
        .eq('incident_id', incidentId)
        .eq('tenant_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return JobRating.fromJson(Map<String, dynamic>.from(row));
  } catch (e, st) {
    dev.log('incidentRatingProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return null;
  }
}

// ---------------------------------------------------------------------------
// Submit job rating
// ---------------------------------------------------------------------------

@riverpod
class SubmitRating extends _$SubmitRating {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required String incidentId,
    required String contractorId,
    required int rating,
    String? comment,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('job_ratings').insert({
        'incident_id': incidentId,
        'tenant_id': user.id,
        'contractor_id': contractorId,
        'rating': rating,
        if (comment != null) 'comment': comment,
      });
      ref.invalidate(incidentRatingProvider(incidentId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Landlord — compliance certificates (filtered to this landlord's tenancies)
// ---------------------------------------------------------------------------

final landlordComplianceCertsProvider =
    FutureProvider<List<ComplianceCertificate>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id')
        .eq('landlord_id', user.id);
    final ids =
        (tenancyRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('compliance_certificates')
        .select('*')
        .inFilter('tenancy_id', ids)
        .order('expiry_date', ascending: true);
    return (data as List)
        .map((e) => ComplianceCertificate.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordComplianceCertsProvider error',
        error: e, stackTrace: st, name: 'dashboard');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Landlord — all overdue/at-risk rent payments (for Action Center)
// ---------------------------------------------------------------------------

final landlordAllRentPaymentsProvider = FutureProvider<List<RentPayment>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    // Fetch tenancy IDs for this landlord first (rent_payments may not have landlord_id on older rows)
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id')
        .eq('landlord_id', user.id);
    final ids = (tenancyRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('rent_payments')
        .select('*')
        .inFilter('tenancy_id', ids)
        .inFilter('status', ['late', 'missed', 'partial', 'pending'])
        .order('due_date', ascending: true);
    return (data as List)
        .map((r) => RentPayment.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordAllRentPaymentsProvider error', error: e, stackTrace: st,
        name: 'dashboard');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Landlord — rent reviews
// ---------------------------------------------------------------------------

final landlordRentReviewsProvider =
    FutureProvider<List<RentReview>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id')
        .eq('landlord_id', user.id);
    final ids =
        (tenancyRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('rent_reviews')
        .select('*')
        .inFilter('tenancy_id', ids)
        .order('effective_date', ascending: true);
    return (data as List)
        .map((e) =>
            RentReview.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordRentReviewsProvider error',
        error: e, stackTrace: st, name: 'dashboard');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Landlord — Section 8 grounds
// ---------------------------------------------------------------------------

final landlordSection8GroundsProvider =
    FutureProvider<List<Section8Ground>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id')
        .eq('landlord_id', user.id);
    final ids =
        (tenancyRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('section8_grounds')
        .select('*')
        .inFilter('tenancy_id', ids)
        .order('notice_served_date', ascending: false);
    return (data as List)
        .map((e) => Section8Ground.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordSection8GroundsProvider error',
        error: e, stackTrace: st, name: 'dashboard');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Landlord — pet requests
// ---------------------------------------------------------------------------

final landlordPetRequestsProvider =
    FutureProvider<List<PetRequest>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  try {
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id')
        .eq('landlord_id', user.id);
    final ids =
        (tenancyRows as List).map((r) => r['id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('pet_requests')
        .select('*')
        .inFilter('tenancy_id', ids)
        .order('requested_at', ascending: false);
    return (data as List)
        .map((e) =>
            PetRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (e, st) {
    dev.log('landlordPetRequestsProvider error',
        error: e, stackTrace: st, name: 'dashboard');
    return [];
  }
});

// ---------------------------------------------------------------------------
// Smart Alert Engine — aggregated alerts for the landlord overview
// ---------------------------------------------------------------------------

/// Tracks which alert IDs have been dismissed this session.
final dismissedAlertsProvider = StateProvider<Set<String>>((ref) => {});

/// Aggregates alerts from tenancies + compliance certs + rent reviews.
/// Returns a list ordered: critical first, then warning, then info.
final landlordAlertsProvider = FutureProvider<List<AlertItem>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final now = DateTime.now();
  final alerts = <AlertItem>[];

  try {
    // ── Fetch all landlord tenancies with relevant fields ──────────────────
    final tenancyRows = await supabase
        .from('tenancies')
        .select('id, tenancy_id, status, end_date, move_in_date, next_rent_review_date, '
            'referencing_status, rtr_status, deposit_scheme, deposit_ref, deposit_amount, '
            'address_line_1, address_line_2, town, postcode')
        .eq('landlord_id', user.id)
        .inFilter('status', ['active', 'pending', 'expiring_soon', 'holding_over']);

    final tenancies = (tenancyRows as List).cast<Map<String, dynamic>>();
    final tenancyIds = tenancies.map((t) => t['id'] as String).toList();

    // ── Fetch compliance certs expiring within 60 days ─────────────────────
    List<Map<String, dynamic>> certs = [];
    if (tenancyIds.isNotEmpty) {
      final certRows = await supabase
          .from('compliance_certificates')
          .select('id, tenancy_id, cert_type, expiry_date, status')
          .inFilter('tenancy_id', tenancyIds)
          .lt('expiry_date', now.add(const Duration(days: 60)).toIso8601String());
      certs = (certRows as List).cast<Map<String, dynamic>>();
    }

    // ── 1. Compliance certificates expiring/expired ──────────────────────
    for (final cert in certs) {
      final expiry = DateTime.tryParse(cert['expiry_date'] as String? ?? '');
      if (expiry == null) continue;
      final daysLeft = expiry.difference(now).inDays;
      final certLabel = _certTypeLabel(cert['cert_type'] as String? ?? '');
      final tenancyId = cert['tenancy_id'] as String;
      final tenancy = tenancies.firstWhere(
        (t) => t['id'] == tenancyId,
        orElse: () => {},
      );
      final addr = _alertShortAddress(tenancy);

      if (daysLeft < 0) {
        alerts.add(AlertItem(
          id: 'cert_expired_${cert['id']}',
          severity: AlertSeverity.critical,
          icon: Icons.verified_user_outlined,
          title: '$certLabel expired',
          body: '${addr.isNotEmpty ? "$addr — " : ""}Expired ${(-daysLeft)} days ago. Replace immediately.',
        ));
      } else if (daysLeft <= 7) {
        alerts.add(AlertItem(
          id: 'cert_7d_${cert['id']}',
          severity: AlertSeverity.critical,
          icon: Icons.verified_user_outlined,
          title: '$certLabel expires in $daysLeft day${daysLeft == 1 ? "" : "s"}',
          body: '${addr.isNotEmpty ? "$addr — " : ""}Urgent: renew before ${_alertFmtDate(expiry)}.',
        ));
      } else if (daysLeft <= 30) {
        alerts.add(AlertItem(
          id: 'cert_30d_${cert['id']}',
          severity: AlertSeverity.warning,
          icon: Icons.verified_user_outlined,
          title: '$certLabel expires in $daysLeft days',
          body: '${addr.isNotEmpty ? "$addr — " : ""}Due ${_alertFmtDate(expiry)}.',
        ));
      } else {
        alerts.add(AlertItem(
          id: 'cert_60d_${cert['id']}',
          severity: AlertSeverity.info,
          icon: Icons.verified_user_outlined,
          title: '$certLabel due within 60 days',
          body: '${addr.isNotEmpty ? "$addr — " : ""}Expires ${_alertFmtDate(expiry)}.',
        ));
      }
    }

    // ── 2. Tenancies ending within 90 days ───────────────────────────────
    for (final t in tenancies) {
      final end = DateTime.tryParse(t['end_date'] as String? ?? '');
      if (end == null) continue;
      final daysLeft = end.difference(now).inDays;
      if (daysLeft < 0 || daysLeft > 90) continue;
      final addr = _alertShortAddress(t);

      alerts.add(AlertItem(
        id: 'tenancy_end_${t['id']}',
        severity: daysLeft <= 14
            ? AlertSeverity.critical
            : daysLeft <= 30
                ? AlertSeverity.warning
                : AlertSeverity.info,
        icon: Icons.home_outlined,
        title: 'Tenancy ending in $daysLeft day${daysLeft == 1 ? "" : "s"}',
        body: '${addr.isNotEmpty ? "$addr — " : ""}'
            '${daysLeft <= 14 ? "Confirm renewal or serve notice." : "Plan renewal or remarketing."}',
      ));
    }

    // ── 3. Rent reviews due within 60 days ──────────────────────────────
    for (final t in tenancies) {
      final review = DateTime.tryParse(t['next_rent_review_date'] as String? ?? '');
      if (review == null) continue;
      final daysLeft = review.difference(now).inDays;
      if (daysLeft < 0 || daysLeft > 60) continue;
      final addr = _alertShortAddress(t);

      alerts.add(AlertItem(
        id: 'rent_review_${t['id']}',
        severity: daysLeft <= 14 ? AlertSeverity.warning : AlertSeverity.info,
        icon: Icons.payments_outlined,
        title: 'Rent review due ${_alertFmtDate(review)}',
        body: '${addr.isNotEmpty ? "$addr — " : ""}$daysLeft days to serve Section 13 notice.',
      ));
    }

    // ── 4. Right to Rent check not recorded ──────────────────────────────
    final rtrTenancies = tenancies
        .where((t) =>
            (t['status'] as String?) == 'active' &&
            (t['rtr_status'] as String? ?? 'not_started') == 'not_started')
        .toList();
    if (rtrTenancies.isNotEmpty) {
      final count = rtrTenancies.length;
      // Pass tenancy_id of first offending tenancy as data for the action
      final firstId = rtrTenancies.first['tenancy_id'] as String?
          ?? rtrTenancies.first['id'] as String;
      alerts.add(AlertItem(
        id: 'rtr_check_${rtrTenancies.map((t) => t['id']).join("_")}',
        severity: AlertSeverity.warning,
        icon: Icons.badge_outlined,
        title: 'Right to Rent check needed',
        body: '$count active tenancy${count > 1 ? "ies have" : " has"} no Right to Rent check recorded. '
            'Required by law — fines up to £20,000.',
        actionLabel: 'Record check →',
        // onAction is wired in the UI layer since it needs BuildContext
        // The tenancy_id is embedded in the alert id for the UI to extract
      ));
    }

    // ── 5. Deposit protection missing (within 30 days of move-in) ────────
    for (final t in tenancies) {
      final moveIn = DateTime.tryParse(t['move_in_date'] as String? ?? '');
      if (moveIn == null) continue;
      final daysSince = now.difference(moveIn).inDays;
      if (daysSince < 0 || daysSince > 30) continue;
      final depositAmount = (t['deposit_amount'] as num?)?.toDouble() ?? 0;
      if (depositAmount <= 0) continue; // no deposit taken, skip
      // DB defaults deposit_scheme to 'TDS' so check ref explicitly
      final hasRef = (t['deposit_ref'] as String?)?.isNotEmpty == true;
      if (!hasRef) {
        final addr = _alertShortAddress(t);
        alerts.add(AlertItem(
          id: 'deposit_${t['id']}',
          severity: AlertSeverity.critical,
          icon: Icons.lock_outlined,
          title: 'Deposit not protected',
          body: '${addr.isNotEmpty ? "$addr — " : ""}Moved in ${daysSince}d ago. Register with DPS, myDeposits, or TDS within 30 days.',
        ));
      }
    }
  } catch (e, st) {
    dev.log('landlordAlertsProvider error', error: e, stackTrace: st, name: 'dashboard');
  }

  alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
  return alerts;
});

String _alertShortAddress(Map<String, dynamic> t) {
  final parts = [
    t['address_line_1'] as String?,
    t['town'] as String?,
  ].where((s) => s != null && (s as String).isNotEmpty).toList();
  return parts.join(', ');
}

String _alertFmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
                  'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

String _certTypeLabel(String type) => switch (type) {
  'gas_safety'  => 'Gas Safety',
  'eicr'        => 'EICR',
  'epc'         => 'EPC',
  'pat_test'    => 'PAT Test',
  'fire_risk'   => 'Fire Risk',
  'legionella'  => 'Legionella',
  _             => 'Certificate',
};

// ---------------------------------------------------------------------------
// Section 8 — serve notice with grounds
// ---------------------------------------------------------------------------

@riverpod
class ServeSection8Notice extends _$ServeSection8Notice {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> serve({
    required String tenancyId,
    required String tenancyGroupId,
    required String groundNumber,
    required String groundType,
    required String description,
    required DateTime vacateDate,
    double? arrearsAmount,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      final today = DateTime.now();
      await supabase.from('section8_grounds').insert({
        'tenancy_id': tenancyId,
        'ground_number': groundNumber,
        'ground_type': groundType,
        'description': description,
        'notice_served_date': today.toIso8601String(),
        'earliest_court_date': vacateDate.toIso8601String(),
        'status': 'notice_served',
        if (arrearsAmount != null) 'arrears_amount': arrearsAmount,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      await supabase.from('tenancies').update({
        'status': 'notice_given',
        'notice_given_at': today.toIso8601String(),
        'notice_type': 'section_8',
        'notice_served_date': today.toIso8601String(),
        'expected_vacate_date': vacateDate.toIso8601String(),
        'notice_given_by': 'landlord',
      }).eq('id', tenancyGroupId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordSection8GroundsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Section 13 — serve rent increase notice
// ---------------------------------------------------------------------------

@riverpod
class ServeSection13Notice extends _$ServeSection13Notice {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> serve({
    required String tenancyId,
    required double currentRent,
    required double proposedRent,
    required DateTime effectiveDate,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      final today = DateTime.now();
      await supabase.from('rent_reviews').insert({
        'tenancy_id': tenancyId,
        'current_rent': currentRent,
        'proposed_rent': proposedRent,
        'notice_served_date': today.toIso8601String(),
        'effective_date': effectiveDate.toIso8601String(),
        'status': 'notice_served',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      await supabase.from('tenancies').update({
        'next_rent_review_date': effectiveDate.toIso8601String(),
        'last_rent_increase_date': today.toIso8601String(),
      }).eq('tenancy_id', tenancyId);
      ref.invalidate(landlordTenanciesProvider);
      ref.invalidate(landlordRentReviewsProvider);
      ref.invalidate(landlordAlertsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — documents (own)
// ---------------------------------------------------------------------------

@riverpod
Future<List<ContractorDocument>> contractorDocuments(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  final rows = await supabase
      .from('contractor_documents')
      .select('*')
      .eq('contractor_id', user.id)
      .order('uploaded_at', ascending: false);
  return (rows as List)
      .map((r) => ContractorDocument.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Contractor — upload document + submit for review
// ---------------------------------------------------------------------------

@riverpod
class SubmitForReview extends _$SubmitForReview {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> submit({
    required List<Map<String, dynamic>> documents,
  }) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      // Insert all documents
      if (documents.isNotEmpty) {
        await supabase.from('contractor_documents').insert(
          documents.map((d) => {...d, 'contractor_id': user.id}).toList(),
        );
      }

      // Mark contractor as pending review
      await supabase.from('contractor_details').update({
        'verification_status': 'pending_review',
        'submitted_for_review_at': DateTime.now().toIso8601String(),
      }).eq('contractor_id', user.id);

      ref.invalidate(contractorProfileProvider);
      ref.invalidate(contractorDocumentsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Admin — pending contractor applications
// ---------------------------------------------------------------------------

@riverpod
Future<List<Map<String, dynamic>>> adminPendingContractors(Ref ref) async {
  final rows = await supabase
      .from('contractor_details')
      .select('*, contractor:profiles!contractor_id(full_name, email, phone)')
      .eq('verification_status', 'pending_review')
      .order('submitted_for_review_at', ascending: true);
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}

@riverpod
Future<List<ContractorDocument>> adminContractorDocs(
    Ref ref, String contractorId) async {
  final rows = await supabase
      .from('contractor_documents')
      .select('*')
      .eq('contractor_id', contractorId)
      .order('uploaded_at', ascending: true);
  return (rows as List)
      .map((r) => ContractorDocument.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Admin — approve / reject contractor
// ---------------------------------------------------------------------------

@riverpod
class AdminVetContractor extends _$AdminVetContractor {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> approve(String contractorId) async {
    state = const AsyncLoading();
    try {
      // Guard: only update + notify if currently pending (idempotent — no duplicate notifications)
      final existing = await supabase
          .from('contractor_details')
          .select('verification_status')
          .eq('contractor_id', contractorId)
          .maybeSingle();
      if (existing == null) throw Exception('Contractor not found');
      if (existing['verification_status'] == 'approved') {
        state = const AsyncData(null);
        return true;
      }

      await supabase.from('contractor_details').update({
        'verification_status': 'approved',
        'verified_at': DateTime.now().toIso8601String(),
        'rejection_reason': null,
      }).eq('contractor_id', contractorId);

      // Notify the contractor only on first approval
      await supabase.from('notifications').insert({
        'user_id': contractorId,
        'type': 'contractor_approved',
        'title': 'Application approved',
        'body': 'Your contractor application has been approved. You can now view and quote on jobs.',
      });

      ref.invalidate(adminPendingContractorsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> reject(String contractorId, String reason) async {
    state = const AsyncLoading();
    try {
      await supabase.from('contractor_details').update({
        'verification_status': 'rejected',
        'rejection_reason': reason,
      }).eq('contractor_id', contractorId);

      await supabase.from('notifications').insert({
        'user_id': contractorId,
        'type': 'contractor_rejected',
        'title': 'Application not approved',
        'body': reason,
      });

      ref.invalidate(adminPendingContractorsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Admin — all contractors (all statuses)
// ---------------------------------------------------------------------------

@riverpod
Future<List<Map<String, dynamic>>> adminAllContractors(Ref ref) async {
  final rows = await supabase
      .from('contractor_details')
      .select('*, contractor:profiles!contractor_id(full_name, email, phone)')
      .order('submitted_for_review_at', ascending: false, nullsFirst: false);
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}

// ---------------------------------------------------------------------------
// Admin — contractor invites
// ---------------------------------------------------------------------------

@riverpod
Future<List<Map<String, dynamic>>> adminContractorInvites(Ref ref) async {
  final rows = await supabase.rpc('list_contractor_invites');
  return (rows as List)
      .map((r) => Map<String, dynamic>.from(r as Map))
      .toList();
}

// ---------------------------------------------------------------------------
// Admin — send contractor invite
// ---------------------------------------------------------------------------

@riverpod
class AdminInviteContractor extends _$AdminInviteContractor {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> invite(String email) async {
    state = const AsyncLoading();
    try {
      final token = await supabase.rpc(
        'create_contractor_invite',
        params: {'p_email': email},
      ) as String;

      await supabase.functions.invoke(
        'send-invitation-email',
        body: {
          'invite_type': 'contractor_invite',
          'contractor_email': email,
          'token': token,
        },
      );

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — reset for re-application after rejection
// ---------------------------------------------------------------------------

@riverpod
class ResetForReapply extends _$ResetForReapply {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> reset() async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('contractor_details').update({
        'verification_status': 'unverified',
        'rejection_reason': null,
        'is_setup_completed': false,
        'submitted_for_review_at': null,
      }).eq('contractor_id', user.id);

      // Remove previously submitted documents so they re-upload fresh
      await supabase
          .from('contractor_documents')
          .delete()
          .eq('contractor_id', user.id);

      ref.invalidate(contractorProfileProvider);
      ref.invalidate(contractorDocumentsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Admin — platform stats
// ---------------------------------------------------------------------------

class AdminStats {
  final int totalUsers;
  final int landlords;
  final int tenants;
  final int contractors;
  final int agents;
  final int activeTenancies;
  final int totalProperties;
  final int openDisputes;
  final int pendingVetting;
  final double totalPlatformFees;

  const AdminStats({
    required this.totalUsers,
    required this.landlords,
    required this.tenants,
    required this.contractors,
    required this.agents,
    required this.activeTenancies,
    required this.totalProperties,
    required this.openDisputes,
    required this.pendingVetting,
    required this.totalPlatformFees,
  });
}

@riverpod
Future<AdminStats> adminStats(Ref ref) async {
  final results = await Future.wait([
    supabase.from('profiles').select('role').eq('is_admin', false),
    supabase.from('tenancies').select('id').eq('status', 'active'),
    supabase.from('incidents').select('id').eq('status', 'disputed').isFilter('dispute_resolved_at', null),
    supabase.from('contractor_details').select('id').eq('verification_status', 'pending_review'),
    supabase.from('incidents').select('platform_fee').eq('payout_status', 'released'),
    supabase.from('properties').select('id'),
  ]);

  final users      = results[0] as List;
  final tenancies  = results[1] as List;
  final disputes   = results[2] as List;
  final pending    = results[3] as List;
  final fees       = results[4] as List;
  final properties = results[5] as List;

  final totalFees = fees.fold<double>(0, (sum, r) {
    final v = r['platform_fee'];
    if (v == null) return sum;
    return sum + (double.tryParse(v.toString()) ?? 0);
  });

  return AdminStats(
    totalUsers:        users.length,
    landlords:         users.where((u) => u['role'] == 'landlord').length,
    tenants:           users.where((u) => u['role'] == 'tenant').length,
    contractors:       users.where((u) => u['role'] == 'contractor').length,
    agents:            users.where((u) => u['role'] == 'agent').length,
    activeTenancies:   tenancies.length,
    totalProperties:   properties.length,
    openDisputes:      disputes.length,
    pendingVetting:    pending.length,
    totalPlatformFees: totalFees,
  );
}

@riverpod
Future<List<Map<String, dynamic>>> adminOpenDisputes(Ref ref) async {
  final rows = await supabase
      .from('incidents')
      .select('''
        *,
        contractor:profiles!contractor_id(full_name, email),
        tenancy:tenancies!tenancy_id(
          address_line_1, postcode,
          landlord:profiles!landlord_id(full_name, email)
        )
      ''')
      .eq('status', 'disputed')
      .isFilter('dispute_resolved_at', null)
      .order('dispute_raised_at', ascending: true);
  return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
}

@riverpod
Future<List<Map<String, dynamic>>> adminAllUsers(Ref ref) async {
  final rows = await supabase
      .from('profiles')
      .select('id, full_name, email, role, created_at, onboarding_completed, is_admin')
      .order('created_at', ascending: false);
  return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
}

@riverpod
Future<List<Map<String, dynamic>>> adminPayoutLog(Ref ref) async {
  final rows = await supabase
      .from('payout_releases')
      .select('''
        *,
        job:incidents!job_id(title, quote_amount, platform_fee, contractor_payout,
          contractor:profiles!contractor_id(full_name))
      ''')
      .order('released_at', ascending: false);
  return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
}

// ---------------------------------------------------------------------------
// Admin — resolve dispute (admin override)
// ---------------------------------------------------------------------------

@riverpod
class AdminResolveDispute extends _$AdminResolveDispute {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> resolve(String incidentId, String resolution) async {
    state = const AsyncLoading();
    try {
      final user = supabase.auth.currentUser;
      final favourContractor = resolution == 'favour_contractor';
      await supabase.from('incidents').update({
        'status':              'completed',
        'payout_status':       favourContractor ? 'released' : 'withheld',
        'dispute_resolved_at': DateTime.now().toIso8601String(),
        'dispute_resolution':  resolution,
        'dispute_resolved_by': user?.id,
      }).eq('id', incidentId);

      if (favourContractor) {
        try {
          await supabase.functions.invoke('release-payout', body: {'job_id': incidentId});
        } catch (_) {}
      }

      ref.invalidate(adminOpenDisputesProvider);
      ref.invalidate(adminStatsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Contractor — request visit (propose time slots)
// ---------------------------------------------------------------------------

@riverpod
class RequestVisit extends _$RequestVisit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> request(
      String incidentId, List<Map<String, dynamic>> slots) async {
    state = const AsyncLoading();
    final user = supabase.auth.currentUser;
    if (user == null) {
      state = AsyncError('Not logged in', StackTrace.current);
      return false;
    }
    try {
      await supabase.from('incidents').update({
        'status': 'visit_requested',
        'contractor_id': user.id,
        'visit_slots': slots,
      }).eq('id', incidentId);
      ref.invalidate(contractorJobsProvider);
      ref.invalidate(availableJobsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Tenant — confirm visit slot
// ---------------------------------------------------------------------------

@riverpod
class ConfirmVisit extends _$ConfirmVisit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> confirm(
      String incidentId, Map<String, dynamic> slot) async {
    state = const AsyncLoading();
    try {
      await supabase.from('incidents').update({
        'status': 'visit_confirmed',
        'confirmed_visit_slot': slot,
      }).eq('id', incidentId);
      ref.invalidate(tenantIncidentsProvider);
      ref.invalidate(contractorJobsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Pet requests — respond (approve / refuse / conditional)
// ---------------------------------------------------------------------------

@riverpod
class RespondToPetRequest extends _$RespondToPetRequest {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> respond({
    required String requestId,
    required String tenancyId,
    required String status, // 'approved' | 'refused' | 'conditionally_approved'
    String? refusalReason,
    String? conditions,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.from('pet_requests').update({
        'status': status,
        if (refusalReason != null && refusalReason.isNotEmpty)
          'refusal_reason': refusalReason,
        if (conditions != null && conditions.isNotEmpty)
          'conditions': conditions,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
      if (status == 'approved' || status == 'conditionally_approved') {
        await supabase.from('tenancies')
            .update({'pet_permitted': true})
            .eq('tenancy_id', tenancyId);
      }
      ref.invalidate(landlordPetRequestsProvider);
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
// ---------------------------------------------------------------------------
// GoCardless — create Direct Debit mandate
// ---------------------------------------------------------------------------

@riverpod
class SetupDirectDebit extends _$SetupDirectDebit {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<String?> setup(String tenancyId) async {
    state = const AsyncLoading();
    try {
      final res = await supabase.functions.invoke(
        'gocardless-create-mandate',
        body: {'tenancy_id': tenancyId},
      );
      final data = res.data as Map<String, dynamic>;
      if (data['already_active'] == true) {
        state = const AsyncData(null);
        return null;
      }
      final url = data['authorisation_url'] as String?;
      state = AsyncData(url);
      ref.invalidate(landlordTenanciesProvider);
      return url;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// GoCardless — collect payment via existing mandate
// ---------------------------------------------------------------------------

@riverpod
class CollectDirectDebit extends _$CollectDirectDebit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> collect({
    required String rentPaymentId,
    required String tenancyId,
  }) async {
    state = const AsyncLoading();
    try {
      await supabase.functions.invoke(
        'gocardless-collect-payment',
        body: {'rent_payment_id': rentPaymentId},
      );
      ref.invalidate(rentPaymentsProvider(tenancyId));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// TDS — register deposit
// ---------------------------------------------------------------------------

@riverpod
class RegisterTdsDeposit extends _$RegisterTdsDeposit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> register(String tenancyId) async {
    state = const AsyncLoading();
    try {
      await supabase.functions.invoke(
        'tds-register-deposit',
        body: {'tenancy_id': tenancyId},
      );
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// EPC — lookup energy certificate
// ---------------------------------------------------------------------------

@riverpod
class LookupEpc extends _$LookupEpc {
  @override
  AsyncValue<Map<String, dynamic>?> build() => const AsyncData(null);

  Future<Map<String, dynamic>?> lookup({
    required String postcode,
    String? address,
    String? propertyId,
  }) async {
    state = const AsyncLoading();
    try {
      final res = await supabase.functions.invoke(
        'lookup-epc',
        body: {
          'postcode': postcode,
          if (address != null) 'address': address,
          if (propertyId != null) 'property_id': propertyId,
        },
      );
      final data = res.data as Map<String, dynamic>;
      state = AsyncData(data);
      if (propertyId != null) ref.invalidate(landlordPropertiesProvider);
      return data;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// DPS — register custodial deposit
// ---------------------------------------------------------------------------

@riverpod
class RegisterDpsDeposit extends _$RegisterDpsDeposit {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> register(String tenancyId) async {
    state = const AsyncLoading();
    try {
      await supabase.functions.invoke(
        'dps-register-deposit',
        body: {'tenancy_id': tenancyId},
      );
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// Reposit — create deposit replacement policy
// ---------------------------------------------------------------------------

@riverpod
class CreateRepositPolicy extends _$CreateRepositPolicy {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> create(String tenancyId) async {
    state = const AsyncLoading();
    try {
      await supabase.functions.invoke(
        'reposit-create-policy',
        body: {'tenancy_id': tenancyId},
      );
      ref.invalidate(landlordTenanciesProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
