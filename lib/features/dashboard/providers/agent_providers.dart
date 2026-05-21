import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import '../models/compliance_doc.dart';
import '../models/incident.dart';
import '../models/tenancy.dart';

// ---------------------------------------------------------------------------
// Agent Stats — counts for dashboard home
// ---------------------------------------------------------------------------

final agentStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final results = await Future.wait([
    supabase.from('tenancies').select('id').eq('status', 'active'),
    supabase.from('incidents').select('id').neq('status', 'completed'),
    supabase.from('profiles').select('id').eq('role', 'tenant'),
    supabase.from('profiles').select('id').eq('role', 'landlord'),
    supabase.from('compliance_docs').select('id'),
  ]);

  return {
    'tenancies': (results[0] as List).length,
    'open_incidents': (results[1] as List).length,
    'tenants': (results[2] as List).length,
    'landlords': (results[3] as List).length,
    'compliance_docs': (results[4] as List).length,
  };
});

// ---------------------------------------------------------------------------
// Agent — all tenancies (grouped by tenancy_id like landlord view)
// ---------------------------------------------------------------------------

final agentAllTenanciesProvider = FutureProvider<List<Tenancy>>((ref) async {
  final rows = await supabase
      .from('tenancies')
      .select('*, tenant:profiles!tenant_id(full_name, email)')
      .order('created_at', ascending: false);

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
          ? [TenantProfile(id: t.id, fullName: t.tenant!.fullName, email: t.tenant!.email, status: t.status)]
          : <TenantProfile>[];
      grouped[t.tenancyId] = t.copyWith(tenants: tenants);
    }
  }

  return grouped.values.toList();
});

// ---------------------------------------------------------------------------
// Agent — all incidents across every property
// ---------------------------------------------------------------------------

final agentAllIncidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
});

// ---------------------------------------------------------------------------
// Agent — all landlord profiles
// ---------------------------------------------------------------------------

final agentLandlordsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('profiles')
      .select('id, full_name, email, created_at')
      .eq('role', 'landlord')
      .order('full_name', ascending: true);

  return List<Map<String, dynamic>>.from(rows as List);
});

// ---------------------------------------------------------------------------
// Agent — all tenant profiles
// ---------------------------------------------------------------------------

final agentTenantsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase
      .from('profiles')
      .select('id, full_name, email, created_at')
      .eq('role', 'tenant')
      .order('full_name', ascending: true);

  return List<Map<String, dynamic>>.from(rows as List);
});

// ---------------------------------------------------------------------------
// Agent — all compliance docs (with tenancy address for context)
// ---------------------------------------------------------------------------

final agentComplianceProvider =
    FutureProvider<List<ComplianceDoc>>((ref) async {
  final rows = await supabase
      .from('compliance_docs')
      .select('*, tenancy:tenancies!tenancy_id(address_line_1, postcode)')
      .order('created_at', ascending: false);

  return (rows as List)
      .map((r) => ComplianceDoc.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
});

// ---------------------------------------------------------------------------
// Agent — recent incidents (last 5 for dashboard preview)
// ---------------------------------------------------------------------------

final agentRecentIncidentsProvider =
    FutureProvider<List<Incident>>((ref) async {
  final rows = await supabase
      .from('incidents')
      .select(
          '*, tenant:profiles!tenant_id(full_name, email), property:tenancies!tenancy_id(address_line_1, postcode)')
      .order('created_at', ascending: false)
      .limit(5);

  return (rows as List)
      .map((r) => Incident.fromJson(Map<String, dynamic>.from(r as Map)))
      .toList();
});
