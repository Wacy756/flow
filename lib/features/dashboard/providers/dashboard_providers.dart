import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/application.dart';
import '../models/compliance_doc.dart';
import '../models/contractor_profile.dart';
import '../models/incident_comment.dart';
import '../models/job_rating.dart';
import '../models/notification_item.dart';
import '../models/property_listing.dart';
import '../models/rent_payment.dart';
import '../models/service_area.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';

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

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
  });
}

@riverpod
Future<UserProfile?> currentProfile(Ref ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select('full_name, role')
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) {
    return UserProfile(
      id: user.id,
      fullName: user.userMetadata?['full_name'] as String? ?? 'User',
      role: user.userMetadata?['role'] as String? ?? '',
      email: user.email,
    );
  }

  return UserProfile(
    id: user.id,
    fullName: data['full_name'] as String? ?? 'User',
    role: data['role'] as String? ?? '',
    email: user.email,
  );
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

  Future<void> approveQuote(String incidentId) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('incidents')
          .update({'status': 'in_progress'})
          .eq('id', incidentId);
      state = const AsyncData(null);
      ref.invalidate(landlordIncidentsProvider);
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

      if (validTenants.isEmpty && unregisteredEmails.isEmpty) {
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

      if (successCount > 0) {
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
        return successCount > 0 || unregisteredEmails.isNotEmpty;
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
      }).eq('tenancy_id', tenancyGroupId);
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
      }).eq('tenancy_id', tenancyGroupId);
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

  final rows = await supabase
      .from('tenancies')
      .select(
        '*, landlord_id, landlord:profiles!landlord_id(full_name, email), '
        'property:properties!property_id('
          'address_line_1, address_line_2, address_line_3, town, postcode, '
          'latitude, longitude, property_type, num_bedrooms, num_bathrooms, '
          'max_tenants, furnishing'
        ')',
      )
      .eq('tenant_id', user.id)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Tenancy.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
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
// Tenant — accept invitation
// ---------------------------------------------------------------------------

@riverpod
class AcceptInvitation extends _$AcceptInvitation {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> accept(String tenancyRowId) async {
    state = const AsyncLoading();
    try {
      await supabase
          .from('tenancies')
          .update({'status': 'active'})
          .eq('id', tenancyRowId);
      ref.invalidate(tenantTenanciesProvider);
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

  Future<bool> markComplete(String incidentId) async {
    state = const AsyncLoading();
    try {
      final current = await supabase
          .from('incidents')
          .select('is_contractor_completed')
          .eq('id', incidentId)
          .single();

      final bothDone = current['is_contractor_completed'] == true;
      await supabase.from('incidents').update({
        'is_tenant_completed': true,
        if (bothDone) 'status': 'completed',
      }).eq('id', incidentId);

      ref.invalidate(tenantIncidentsProvider);
      ref.invalidate(landlordIncidentsProvider);
      state = const AsyncData(null);
      return true;
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

  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), '
          'tenancy:tenancies!tenancy_id(property:properties!property_id(address_line_1, postcode))')
      .eq('status', 'approved')
      .isFilter('contractor_id', null)
      .order('created_at', ascending: false);

  // Filter out jobs this contractor has already declined
  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .where((i) => !(i.declinedBy.contains(user.id)))
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
      final current = await supabase
          .from('incidents')
          .select('declined_by')
          .eq('id', incidentId)
          .single();

      final existing =
          List<String>.from((current['declined_by'] as List?) ?? []);
      if (!existing.contains(user.id)) existing.add(user.id);

      await supabase
          .from('incidents')
          .update({'declined_by': existing})
          .eq('id', incidentId);

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
          .select('is_tenant_completed')
          .eq('id', incidentId)
          .single();

      final bothDone = current['is_tenant_completed'] == true;
      await supabase.from('incidents').update({
        'is_contractor_completed': true,
        if (bothDone) 'status': 'completed',
      }).eq('id', incidentId);

      ref.invalidate(contractorJobsProvider);
      ref.invalidate(landlordIncidentsProvider);
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
