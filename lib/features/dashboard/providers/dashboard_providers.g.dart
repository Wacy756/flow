// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentProfileHash() => r'6ab5e826b2414f8f9cbe162451e5556bdc7d3df8';

/// See also [currentProfile].
@ProviderFor(currentProfile)
final currentProfileProvider = AutoDisposeFutureProvider<UserProfile?>.internal(
  currentProfile,
  name: r'currentProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentProfileRef = AutoDisposeFutureProviderRef<UserProfile?>;
String _$landlordTenanciesHash() => r'ea464955d7f7bd75c7979fdcaf47de496199a305';

/// See also [landlordTenancies].
@ProviderFor(landlordTenancies)
final landlordTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      landlordTenancies,
      name: r'landlordTenanciesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$landlordTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LandlordTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$landlordIncidentsHash() => r'7bd176409ad1897cb094bd790fb7348ebe3581b8';

/// See also [landlordIncidents].
@ProviderFor(landlordIncidents)
final landlordIncidentsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      landlordIncidents,
      name: r'landlordIncidentsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$landlordIncidentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LandlordIncidentsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$complianceDocsHash() => r'83e70bad41de111768b8d1f02f410ffcd86161d3';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [complianceDocs].
@ProviderFor(complianceDocs)
const complianceDocsProvider = ComplianceDocsFamily();

/// See also [complianceDocs].
class ComplianceDocsFamily extends Family<AsyncValue<List<ComplianceDoc>>> {
  /// See also [complianceDocs].
  const ComplianceDocsFamily();

  /// See also [complianceDocs].
  ComplianceDocsProvider call(String tenancyId) {
    return ComplianceDocsProvider(tenancyId);
  }

  @override
  ComplianceDocsProvider getProviderOverride(
    covariant ComplianceDocsProvider provider,
  ) {
    return call(provider.tenancyId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'complianceDocsProvider';
}

/// See also [complianceDocs].
class ComplianceDocsProvider
    extends AutoDisposeFutureProvider<List<ComplianceDoc>> {
  /// See also [complianceDocs].
  ComplianceDocsProvider(String tenancyId)
    : this._internal(
        (ref) => complianceDocs(ref as ComplianceDocsRef, tenancyId),
        from: complianceDocsProvider,
        name: r'complianceDocsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$complianceDocsHash,
        dependencies: ComplianceDocsFamily._dependencies,
        allTransitiveDependencies:
            ComplianceDocsFamily._allTransitiveDependencies,
        tenancyId: tenancyId,
      );

  ComplianceDocsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.tenancyId,
  }) : super.internal();

  final String tenancyId;

  @override
  Override overrideWith(
    FutureOr<List<ComplianceDoc>> Function(ComplianceDocsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ComplianceDocsProvider._internal(
        (ref) => create(ref as ComplianceDocsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        tenancyId: tenancyId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ComplianceDoc>> createElement() {
    return _ComplianceDocsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ComplianceDocsProvider && other.tenancyId == tenancyId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, tenancyId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ComplianceDocsRef on AutoDisposeFutureProviderRef<List<ComplianceDoc>> {
  /// The parameter `tenancyId` of this provider.
  String get tenancyId;
}

class _ComplianceDocsProviderElement
    extends AutoDisposeFutureProviderElement<List<ComplianceDoc>>
    with ComplianceDocsRef {
  _ComplianceDocsProviderElement(super.provider);

  @override
  String get tenancyId => (origin as ComplianceDocsProvider).tenancyId;
}

String _$tenantTenanciesHash() => r'e1b153a406c594e8550c2b37e084161a69c46a74';

/// See also [tenantTenancies].
@ProviderFor(tenantTenancies)
final tenantTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      tenantTenancies,
      name: r'tenantTenanciesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$tenantTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TenantTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$tenantIncidentsHash() => r'3960e86456a4b06069f3369fb7f8026d192087a2';

/// See also [tenantIncidents].
@ProviderFor(tenantIncidents)
final tenantIncidentsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      tenantIncidents,
      name: r'tenantIncidentsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$tenantIncidentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TenantIncidentsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$contractorProfileHash() => r'ca02ad0ea6f17d97551fa720b2958bd2d7d9e4f0';

/// See also [contractorProfile].
@ProviderFor(contractorProfile)
final contractorProfileProvider =
    AutoDisposeFutureProvider<ContractorDetails?>.internal(
      contractorProfile,
      name: r'contractorProfileProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$contractorProfileHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorProfileRef = AutoDisposeFutureProviderRef<ContractorDetails?>;
String _$contractorJobsHash() => r'30158a37bc8143435fe40d3f12a93ebbe45d07f9';

/// See also [contractorJobs].
@ProviderFor(contractorJobs)
final contractorJobsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      contractorJobs,
      name: r'contractorJobsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$contractorJobsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorJobsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$availableJobsHash() => r'32ffdd2c901938a2d3804190f555a7a2fb7be046';

/// See also [availableJobs].
@ProviderFor(availableJobs)
final availableJobsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      availableJobs,
      name: r'availableJobsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$availableJobsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableJobsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$incidentActionsHash() => r'972cd83743dff6a4f27479b875b2fd3ba0215321';

/// See also [IncidentActions].
@ProviderFor(IncidentActions)
final incidentActionsProvider =
    AutoDisposeNotifierProvider<IncidentActions, AsyncValue<void>>.internal(
      IncidentActions.new,
      name: r'incidentActionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$incidentActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IncidentActions = AutoDisposeNotifier<AsyncValue<void>>;
String _$addTenancyHash() => r'c93a38e24361760ecd41b0387009ec9bac1a556e';

/// See also [AddTenancy].
@ProviderFor(AddTenancy)
final addTenancyProvider =
    AutoDisposeNotifierProvider<AddTenancy, AsyncValue<void>>.internal(
      AddTenancy.new,
      name: r'addTenancyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$addTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AddTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$deleteTenancyHash() => r'b4c9ab8adceb618f35fe9fac35a8de07abfbafd7';

/// See also [DeleteTenancy].
@ProviderFor(DeleteTenancy)
final deleteTenancyProvider =
    AutoDisposeNotifierProvider<DeleteTenancy, AsyncValue<void>>.internal(
      DeleteTenancy.new,
      name: r'deleteTenancyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$deleteTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DeleteTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$acceptInvitationHash() => r'266745233b10134276ff7324bbf3157935ad9ea8';

/// See also [AcceptInvitation].
@ProviderFor(AcceptInvitation)
final acceptInvitationProvider =
    AutoDisposeNotifierProvider<AcceptInvitation, AsyncValue<void>>.internal(
      AcceptInvitation.new,
      name: r'acceptInvitationProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$acceptInvitationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AcceptInvitation = AutoDisposeNotifier<AsyncValue<void>>;
String _$createIncidentHash() => r'0275ed347baf645f4501e3d63666b0583645b137';

/// See also [CreateIncident].
@ProviderFor(CreateIncident)
final createIncidentProvider =
    AutoDisposeNotifierProvider<CreateIncident, AsyncValue<void>>.internal(
      CreateIncident.new,
      name: r'createIncidentProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$createIncidentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CreateIncident = AutoDisposeNotifier<AsyncValue<void>>;
String _$tenantMarkCompleteHash() =>
    r'791018fc5a0944b06ed62d361cbb89edb72b52db';

/// See also [TenantMarkComplete].
@ProviderFor(TenantMarkComplete)
final tenantMarkCompleteProvider =
    AutoDisposeNotifierProvider<TenantMarkComplete, AsyncValue<void>>.internal(
      TenantMarkComplete.new,
      name: r'tenantMarkCompleteProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$tenantMarkCompleteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TenantMarkComplete = AutoDisposeNotifier<AsyncValue<void>>;
String _$submitQuoteHash() => r'89af478ff195f0a5324549c05a37e50902047f75';

/// See also [SubmitQuote].
@ProviderFor(SubmitQuote)
final submitQuoteProvider =
    AutoDisposeNotifierProvider<SubmitQuote, AsyncValue<void>>.internal(
      SubmitQuote.new,
      name: r'submitQuoteProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$submitQuoteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitQuote = AutoDisposeNotifier<AsyncValue<void>>;
String _$contractorMarkCompleteHash() =>
    r'6ac414d12a2a47306341b9019bccf3f76fd9ee8b';

/// See also [ContractorMarkComplete].
@ProviderFor(ContractorMarkComplete)
final contractorMarkCompleteProvider =
    AutoDisposeNotifierProvider<
      ContractorMarkComplete,
      AsyncValue<void>
    >.internal(
      ContractorMarkComplete.new,
      name: r'contractorMarkCompleteProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$contractorMarkCompleteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ContractorMarkComplete = AutoDisposeNotifier<AsyncValue<void>>;
String _$saveContractorDetailsHash() =>
    r'31cc1b98389509c6f4860eb852741fd5e7717c71';

/// See also [SaveContractorDetails].
@ProviderFor(SaveContractorDetails)
final saveContractorDetailsProvider =
    AutoDisposeNotifierProvider<
      SaveContractorDetails,
      AsyncValue<void>
    >.internal(
      SaveContractorDetails.new,
      name: r'saveContractorDetailsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$saveContractorDetailsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SaveContractorDetails = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
