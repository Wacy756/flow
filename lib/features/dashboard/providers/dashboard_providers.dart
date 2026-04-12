import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/compliance_doc.dart';
import '../models/contractor_profile.dart';
import '../models/service_area.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';

part 'dashboard_providers.g.dart';

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
      .select('*, tenant:profiles!tenant_id(full_name, email)')
      .eq('landlord_id', user.id)
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
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
      .inFilter('tenancy_id', ids)
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
}

// ---------------------------------------------------------------------------
// Compliance docs (per tenancy) — used by tenancy card
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
      final batchTenancyId = _uuid();
      final errors = <String>[];
      int successCount = 0;

      for (final email in tenantEmails) {
        // 1. Look up the tenant
        final profileRows = await supabase
            .from('profiles')
            .select('id, role')
            .eq('email', email)
            .maybeSingle();

        if (profileRows == null) {
          errors.add('$email: Not registered on Flow.');
          continue;
        }
        if (profileRows['role'] != 'tenant') {
          errors.add('$email: User is not registered as a tenant.');
          continue;
        }

        // 2. Check for duplicate
        final existing = await supabase
            .from('tenancies')
            .select('id')
            .eq('landlord_id', user.id)
            .eq('tenant_id', profileRows['id'] as String)
            .eq('postcode', formData['postcode'] as String)
            .eq('address_line_1', formData['address_line_1'] as String)
            .maybeSingle();

        if (existing != null) {
          errors.add('$email: Already invited to this property.');
          continue;
        }

        // 3. Insert
        final insertError = await _insertTenancy(
          landlordId: user.id,
          tenantId: profileRows['id'] as String,
          tenancyId: batchTenancyId,
          formData: formData,
        );

        if (insertError != null) {
          errors.add('$email: $insertError');
        } else {
          successCount++;
        }
      }

      if (successCount > 0) {
        ref.invalidate(landlordTenanciesProvider);
      }

      if (errors.isNotEmpty) {
        state = AsyncError(errors.join('\n'), StackTrace.current);
        return successCount > 0;
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
    required String tenancyId,
    required Map<String, dynamic> formData,
  }) async {
    try {
      await supabase.from('tenancies').insert({
        'landlord_id': landlordId,
        'tenant_id': tenantId,
        'tenancy_id': tenancyId,
        'status': 'pending',
        ...formData,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String _uuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
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
      await supabase
          .from('tenancies')
          .delete()
          .eq('tenancy_id', tenancyGroupId);
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
      .select('*, landlord:profiles!landlord_id(full_name, email)')
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
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
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
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
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
  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
      .eq('status', 'approved')
      .isFilter('contractor_id', null)
      .order('created_at', ascending: false);

  return (rows as List)
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
// Contractor — save profile (upsert to contractor_details)
// ---------------------------------------------------------------------------

@riverpod
class SaveContractorDetails extends _$SaveContractorDetails {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> save({
    required List<String> workTypes,
    required List<ServiceArea> serviceAreas,
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
