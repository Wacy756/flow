// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$platformSettingsHash() => r'4a780778a53bfaf9e0bc57a03e41918231c5e574';

/// See also [platformSettings].
@ProviderFor(platformSettings)
final platformSettingsProvider =
    AutoDisposeFutureProvider<PlatformSettings>.internal(
      platformSettings,
      name: r'platformSettingsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$platformSettingsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PlatformSettingsRef = AutoDisposeFutureProviderRef<PlatformSettings>;
String _$currentProfileHash() => r'd7683884d679685158c82b4414e6d3cf9377847b';

/// See also [currentProfile].
@ProviderFor(currentProfile)
final currentProfileProvider = AutoDisposeFutureProvider<UserProfile?>.internal(
  currentProfile,
  name: r'currentProfileProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentProfileRef = AutoDisposeFutureProviderRef<UserProfile?>;
String _$currentPlanHash() => r'3190b3bba7c30b845c79177fe9dc8ead04aafbd3';

/// Derives the current user's plan from their profile's selected_plan field.
///
/// Copied from [currentPlan].
@ProviderFor(currentPlan)
final currentPlanProvider = AutoDisposeFutureProvider<AbodePlan>.internal(
  currentPlan,
  name: r'currentPlanProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentPlanHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentPlanRef = AutoDisposeFutureProviderRef<AbodePlan>;
String _$landlordTenanciesHash() => r'b740aa6c8e96991ecca7594ccdfd3ad198817c51';

/// See also [landlordTenancies].
@ProviderFor(landlordTenancies)
final landlordTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      landlordTenancies,
      name: r'landlordTenanciesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$landlordTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LandlordTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$landlordPropertiesHash() =>
    r'36b8622ce274ad911e012006aa9c88d9bdc9d6ce';

/// See also [landlordProperties].
@ProviderFor(landlordProperties)
final landlordPropertiesProvider =
    AutoDisposeFutureProvider<List<PropertyRecord>>.internal(
      landlordProperties,
      name: r'landlordPropertiesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$landlordPropertiesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LandlordPropertiesRef =
    AutoDisposeFutureProviderRef<List<PropertyRecord>>;
String _$landlordIncidentsHash() => r'1c876fb2e7940bf5a498b2a65fd3795bd6b92a98';

/// See also [landlordIncidents].
@ProviderFor(landlordIncidents)
final landlordIncidentsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      landlordIncidents,
      name: r'landlordIncidentsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
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

String _$complianceSummaryHash() => r'faa79737250d3615942b176927ff263305600aad';

/// See also [complianceSummary].
@ProviderFor(complianceSummary)
final complianceSummaryProvider =
    AutoDisposeFutureProvider<ComplianceSummary>.internal(
      complianceSummary,
      name: r'complianceSummaryProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$complianceSummaryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ComplianceSummaryRef = AutoDisposeFutureProviderRef<ComplianceSummary>;
String _$endedTenanciesHash() => r'338ef369b3b6c043a2a1791d3e3b171bad3dba19';

/// See also [endedTenancies].
@ProviderFor(endedTenancies)
final endedTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      endedTenancies,
      name: r'endedTenanciesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$endedTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EndedTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$tenantTenanciesHash() => r'9d577e23dc9ee5608422639b401832b1a7ab84e1';

/// See also [tenantTenancies].
@ProviderFor(tenantTenancies)
final tenantTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      tenantTenancies,
      name: r'tenantTenanciesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$tenantTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TenantTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$tenantIncidentsHash() => r'91ced376a245ab1228f1d3b33ba470b1e16dd698';

/// See also [tenantIncidents].
@ProviderFor(tenantIncidents)
final tenantIncidentsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      tenantIncidents,
      name: r'tenantIncidentsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$tenantIncidentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TenantIncidentsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$tenantEndedTenanciesHash() =>
    r'c58b0eff52755d9ff24488176eeb60dfc0787de4';

/// See also [tenantEndedTenancies].
@ProviderFor(tenantEndedTenancies)
final tenantEndedTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      tenantEndedTenancies,
      name: r'tenantEndedTenanciesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$tenantEndedTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TenantEndedTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$contractorProfileHash() => r'ca02ad0ea6f17d97551fa720b2958bd2d7d9e4f0';

/// See also [contractorProfile].
@ProviderFor(contractorProfile)
final contractorProfileProvider =
    AutoDisposeFutureProvider<ContractorDetails?>.internal(
      contractorProfile,
      name: r'contractorProfileProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$contractorProfileHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorProfileRef = AutoDisposeFutureProviderRef<ContractorDetails?>;
String _$contractorJobsHash() => r'82a4e478b6a9962433a1707c7b8b67fa6e79fe77';

/// See also [contractorJobs].
@ProviderFor(contractorJobs)
final contractorJobsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      contractorJobs,
      name: r'contractorJobsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$contractorJobsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorJobsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$availableJobsHash() => r'0f2ebc0e7fa4dea98d45fa362eefbee5f08817c0';

/// See also [availableJobs].
@ProviderFor(availableJobs)
final availableJobsProvider =
    AutoDisposeFutureProvider<List<Incident>>.internal(
      availableJobs,
      name: r'availableJobsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$availableJobsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AvailableJobsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$propertyListingHash() => r'7290945e165061074077bbff36768d6c667718ae';

/// See also [propertyListing].
@ProviderFor(propertyListing)
const propertyListingProvider = PropertyListingFamily();

/// See also [propertyListing].
class PropertyListingFamily extends Family<AsyncValue<PropertyListing?>> {
  /// See also [propertyListing].
  const PropertyListingFamily();

  /// See also [propertyListing].
  PropertyListingProvider call(String propertyId) {
    return PropertyListingProvider(propertyId);
  }

  @override
  PropertyListingProvider getProviderOverride(
    covariant PropertyListingProvider provider,
  ) {
    return call(provider.propertyId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'propertyListingProvider';
}

/// See also [propertyListing].
class PropertyListingProvider
    extends AutoDisposeFutureProvider<PropertyListing?> {
  /// See also [propertyListing].
  PropertyListingProvider(String propertyId)
    : this._internal(
        (ref) => propertyListing(ref as PropertyListingRef, propertyId),
        from: propertyListingProvider,
        name: r'propertyListingProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$propertyListingHash,
        dependencies: PropertyListingFamily._dependencies,
        allTransitiveDependencies:
            PropertyListingFamily._allTransitiveDependencies,
        propertyId: propertyId,
      );

  PropertyListingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.propertyId,
  }) : super.internal();

  final String propertyId;

  @override
  Override overrideWith(
    FutureOr<PropertyListing?> Function(PropertyListingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PropertyListingProvider._internal(
        (ref) => create(ref as PropertyListingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        propertyId: propertyId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PropertyListing?> createElement() {
    return _PropertyListingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PropertyListingProvider && other.propertyId == propertyId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, propertyId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PropertyListingRef on AutoDisposeFutureProviderRef<PropertyListing?> {
  /// The parameter `propertyId` of this provider.
  String get propertyId;
}

class _PropertyListingProviderElement
    extends AutoDisposeFutureProviderElement<PropertyListing?>
    with PropertyListingRef {
  _PropertyListingProviderElement(super.provider);

  @override
  String get propertyId => (origin as PropertyListingProvider).propertyId;
}

String _$listingByTokenHash() => r'a2dfabd3467da5458d62ac7b98bc4cadbd7bb308';

/// See also [listingByToken].
@ProviderFor(listingByToken)
const listingByTokenProvider = ListingByTokenFamily();

/// See also [listingByToken].
class ListingByTokenFamily extends Family<AsyncValue<PropertyListing?>> {
  /// See also [listingByToken].
  const ListingByTokenFamily();

  /// See also [listingByToken].
  ListingByTokenProvider call(String token) {
    return ListingByTokenProvider(token);
  }

  @override
  ListingByTokenProvider getProviderOverride(
    covariant ListingByTokenProvider provider,
  ) {
    return call(provider.token);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'listingByTokenProvider';
}

/// See also [listingByToken].
class ListingByTokenProvider
    extends AutoDisposeFutureProvider<PropertyListing?> {
  /// See also [listingByToken].
  ListingByTokenProvider(String token)
    : this._internal(
        (ref) => listingByToken(ref as ListingByTokenRef, token),
        from: listingByTokenProvider,
        name: r'listingByTokenProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$listingByTokenHash,
        dependencies: ListingByTokenFamily._dependencies,
        allTransitiveDependencies:
            ListingByTokenFamily._allTransitiveDependencies,
        token: token,
      );

  ListingByTokenProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.token,
  }) : super.internal();

  final String token;

  @override
  Override overrideWith(
    FutureOr<PropertyListing?> Function(ListingByTokenRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListingByTokenProvider._internal(
        (ref) => create(ref as ListingByTokenRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        token: token,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PropertyListing?> createElement() {
    return _ListingByTokenProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListingByTokenProvider && other.token == token;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, token.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ListingByTokenRef on AutoDisposeFutureProviderRef<PropertyListing?> {
  /// The parameter `token` of this provider.
  String get token;
}

class _ListingByTokenProviderElement
    extends AutoDisposeFutureProviderElement<PropertyListing?>
    with ListingByTokenRef {
  _ListingByTokenProviderElement(super.provider);

  @override
  String get token => (origin as ListingByTokenProvider).token;
}

String _$myApplicationHash() => r'2194c76c799950501d41a289d27e31c56f8a29c3';

/// See also [myApplication].
@ProviderFor(myApplication)
const myApplicationProvider = MyApplicationFamily();

/// See also [myApplication].
class MyApplicationFamily extends Family<AsyncValue<Application?>> {
  /// See also [myApplication].
  const MyApplicationFamily();

  /// See also [myApplication].
  MyApplicationProvider call(String listingId) {
    return MyApplicationProvider(listingId);
  }

  @override
  MyApplicationProvider getProviderOverride(
    covariant MyApplicationProvider provider,
  ) {
    return call(provider.listingId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'myApplicationProvider';
}

/// See also [myApplication].
class MyApplicationProvider extends AutoDisposeFutureProvider<Application?> {
  /// See also [myApplication].
  MyApplicationProvider(String listingId)
    : this._internal(
        (ref) => myApplication(ref as MyApplicationRef, listingId),
        from: myApplicationProvider,
        name: r'myApplicationProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$myApplicationHash,
        dependencies: MyApplicationFamily._dependencies,
        allTransitiveDependencies:
            MyApplicationFamily._allTransitiveDependencies,
        listingId: listingId,
      );

  MyApplicationProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.listingId,
  }) : super.internal();

  final String listingId;

  @override
  Override overrideWith(
    FutureOr<Application?> Function(MyApplicationRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MyApplicationProvider._internal(
        (ref) => create(ref as MyApplicationRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        listingId: listingId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Application?> createElement() {
    return _MyApplicationProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MyApplicationProvider && other.listingId == listingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MyApplicationRef on AutoDisposeFutureProviderRef<Application?> {
  /// The parameter `listingId` of this provider.
  String get listingId;
}

class _MyApplicationProviderElement
    extends AutoDisposeFutureProviderElement<Application?>
    with MyApplicationRef {
  _MyApplicationProviderElement(super.provider);

  @override
  String get listingId => (origin as MyApplicationProvider).listingId;
}

String _$listingApplicationsHash() =>
    r'1a8e464711013b4a7485ec5988cdc9b455b0ba7d';

/// See also [listingApplications].
@ProviderFor(listingApplications)
const listingApplicationsProvider = ListingApplicationsFamily();

/// See also [listingApplications].
class ListingApplicationsFamily extends Family<AsyncValue<List<Application>>> {
  /// See also [listingApplications].
  const ListingApplicationsFamily();

  /// See also [listingApplications].
  ListingApplicationsProvider call(String listingId) {
    return ListingApplicationsProvider(listingId);
  }

  @override
  ListingApplicationsProvider getProviderOverride(
    covariant ListingApplicationsProvider provider,
  ) {
    return call(provider.listingId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'listingApplicationsProvider';
}

/// See also [listingApplications].
class ListingApplicationsProvider
    extends AutoDisposeFutureProvider<List<Application>> {
  /// See also [listingApplications].
  ListingApplicationsProvider(String listingId)
    : this._internal(
        (ref) => listingApplications(ref as ListingApplicationsRef, listingId),
        from: listingApplicationsProvider,
        name: r'listingApplicationsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$listingApplicationsHash,
        dependencies: ListingApplicationsFamily._dependencies,
        allTransitiveDependencies:
            ListingApplicationsFamily._allTransitiveDependencies,
        listingId: listingId,
      );

  ListingApplicationsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.listingId,
  }) : super.internal();

  final String listingId;

  @override
  Override overrideWith(
    FutureOr<List<Application>> Function(ListingApplicationsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListingApplicationsProvider._internal(
        (ref) => create(ref as ListingApplicationsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        listingId: listingId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Application>> createElement() {
    return _ListingApplicationsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListingApplicationsProvider && other.listingId == listingId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listingId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ListingApplicationsRef
    on AutoDisposeFutureProviderRef<List<Application>> {
  /// The parameter `listingId` of this provider.
  String get listingId;
}

class _ListingApplicationsProviderElement
    extends AutoDisposeFutureProviderElement<List<Application>>
    with ListingApplicationsRef {
  _ListingApplicationsProviderElement(super.provider);

  @override
  String get listingId => (origin as ListingApplicationsProvider).listingId;
}

String _$landlordApplicationsHash() =>
    r'77583e5600951bc3921a5e54126f344404b100d8';

/// See also [landlordApplications].
@ProviderFor(landlordApplications)
final landlordApplicationsProvider =
    AutoDisposeFutureProvider<List<Application>>.internal(
      landlordApplications,
      name: r'landlordApplicationsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$landlordApplicationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LandlordApplicationsRef =
    AutoDisposeFutureProviderRef<List<Application>>;
String _$notificationsStreamHash() =>
    r'64ff7a4f864f0a63b9ccf2abe4ee4374a895f8ab';

/// See also [notificationsStream].
@ProviderFor(notificationsStream)
final notificationsStreamProvider =
    AutoDisposeStreamProvider<List<NotificationItem>>.internal(
      notificationsStream,
      name: r'notificationsStreamProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$notificationsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationsStreamRef =
    AutoDisposeStreamProviderRef<List<NotificationItem>>;
String _$unreadNotificationCountHash() =>
    r'4effabb0d2f84430ef595f66dd5da61e21750b4e';

/// See also [unreadNotificationCount].
@ProviderFor(unreadNotificationCount)
final unreadNotificationCountProvider = AutoDisposeProvider<int>.internal(
  unreadNotificationCount,
  name: r'unreadNotificationCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$unreadNotificationCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationCountRef = AutoDisposeProviderRef<int>;
String _$incidentCommentsHash() => r'd44b2a566588f7a0ec5dd42c20447801579739fe';

/// See also [incidentComments].
@ProviderFor(incidentComments)
const incidentCommentsProvider = IncidentCommentsFamily();

/// See also [incidentComments].
class IncidentCommentsFamily extends Family<AsyncValue<List<IncidentComment>>> {
  /// See also [incidentComments].
  const IncidentCommentsFamily();

  /// See also [incidentComments].
  IncidentCommentsProvider call(String incidentId) {
    return IncidentCommentsProvider(incidentId);
  }

  @override
  IncidentCommentsProvider getProviderOverride(
    covariant IncidentCommentsProvider provider,
  ) {
    return call(provider.incidentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'incidentCommentsProvider';
}

/// See also [incidentComments].
class IncidentCommentsProvider
    extends AutoDisposeFutureProvider<List<IncidentComment>> {
  /// See also [incidentComments].
  IncidentCommentsProvider(String incidentId)
    : this._internal(
        (ref) => incidentComments(ref as IncidentCommentsRef, incidentId),
        from: incidentCommentsProvider,
        name: r'incidentCommentsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$incidentCommentsHash,
        dependencies: IncidentCommentsFamily._dependencies,
        allTransitiveDependencies:
            IncidentCommentsFamily._allTransitiveDependencies,
        incidentId: incidentId,
      );

  IncidentCommentsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.incidentId,
  }) : super.internal();

  final String incidentId;

  @override
  Override overrideWith(
    FutureOr<List<IncidentComment>> Function(IncidentCommentsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IncidentCommentsProvider._internal(
        (ref) => create(ref as IncidentCommentsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        incidentId: incidentId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<IncidentComment>> createElement() {
    return _IncidentCommentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncidentCommentsProvider && other.incidentId == incidentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, incidentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IncidentCommentsRef
    on AutoDisposeFutureProviderRef<List<IncidentComment>> {
  /// The parameter `incidentId` of this provider.
  String get incidentId;
}

class _IncidentCommentsProviderElement
    extends AutoDisposeFutureProviderElement<List<IncidentComment>>
    with IncidentCommentsRef {
  _IncidentCommentsProviderElement(super.provider);

  @override
  String get incidentId => (origin as IncidentCommentsProvider).incidentId;
}

String _$rentPaymentsHash() => r'db73ba8c68a743d1844b6f9ee5c70829302213a9';

/// See also [rentPayments].
@ProviderFor(rentPayments)
const rentPaymentsProvider = RentPaymentsFamily();

/// See also [rentPayments].
class RentPaymentsFamily extends Family<AsyncValue<List<RentPayment>>> {
  /// See also [rentPayments].
  const RentPaymentsFamily();

  /// See also [rentPayments].
  RentPaymentsProvider call(String tenancyId) {
    return RentPaymentsProvider(tenancyId);
  }

  @override
  RentPaymentsProvider getProviderOverride(
    covariant RentPaymentsProvider provider,
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
  String? get name => r'rentPaymentsProvider';
}

/// See also [rentPayments].
class RentPaymentsProvider
    extends AutoDisposeFutureProvider<List<RentPayment>> {
  /// See also [rentPayments].
  RentPaymentsProvider(String tenancyId)
    : this._internal(
        (ref) => rentPayments(ref as RentPaymentsRef, tenancyId),
        from: rentPaymentsProvider,
        name: r'rentPaymentsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$rentPaymentsHash,
        dependencies: RentPaymentsFamily._dependencies,
        allTransitiveDependencies:
            RentPaymentsFamily._allTransitiveDependencies,
        tenancyId: tenancyId,
      );

  RentPaymentsProvider._internal(
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
    FutureOr<List<RentPayment>> Function(RentPaymentsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RentPaymentsProvider._internal(
        (ref) => create(ref as RentPaymentsRef),
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
  AutoDisposeFutureProviderElement<List<RentPayment>> createElement() {
    return _RentPaymentsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RentPaymentsProvider && other.tenancyId == tenancyId;
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
mixin RentPaymentsRef on AutoDisposeFutureProviderRef<List<RentPayment>> {
  /// The parameter `tenancyId` of this provider.
  String get tenancyId;
}

class _RentPaymentsProviderElement
    extends AutoDisposeFutureProviderElement<List<RentPayment>>
    with RentPaymentsRef {
  _RentPaymentsProviderElement(super.provider);

  @override
  String get tenancyId => (origin as RentPaymentsProvider).tenancyId;
}

String _$incidentRatingHash() => r'2cabff40a2cfefe9279c387191cb658b46da82ca';

/// See also [incidentRating].
@ProviderFor(incidentRating)
const incidentRatingProvider = IncidentRatingFamily();

/// See also [incidentRating].
class IncidentRatingFamily extends Family<AsyncValue<JobRating?>> {
  /// See also [incidentRating].
  const IncidentRatingFamily();

  /// See also [incidentRating].
  IncidentRatingProvider call(String incidentId) {
    return IncidentRatingProvider(incidentId);
  }

  @override
  IncidentRatingProvider getProviderOverride(
    covariant IncidentRatingProvider provider,
  ) {
    return call(provider.incidentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'incidentRatingProvider';
}

/// See also [incidentRating].
class IncidentRatingProvider extends AutoDisposeFutureProvider<JobRating?> {
  /// See also [incidentRating].
  IncidentRatingProvider(String incidentId)
    : this._internal(
        (ref) => incidentRating(ref as IncidentRatingRef, incidentId),
        from: incidentRatingProvider,
        name: r'incidentRatingProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$incidentRatingHash,
        dependencies: IncidentRatingFamily._dependencies,
        allTransitiveDependencies:
            IncidentRatingFamily._allTransitiveDependencies,
        incidentId: incidentId,
      );

  IncidentRatingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.incidentId,
  }) : super.internal();

  final String incidentId;

  @override
  Override overrideWith(
    FutureOr<JobRating?> Function(IncidentRatingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IncidentRatingProvider._internal(
        (ref) => create(ref as IncidentRatingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        incidentId: incidentId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<JobRating?> createElement() {
    return _IncidentRatingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncidentRatingProvider && other.incidentId == incidentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, incidentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin IncidentRatingRef on AutoDisposeFutureProviderRef<JobRating?> {
  /// The parameter `incidentId` of this provider.
  String get incidentId;
}

class _IncidentRatingProviderElement
    extends AutoDisposeFutureProviderElement<JobRating?>
    with IncidentRatingRef {
  _IncidentRatingProviderElement(super.provider);

  @override
  String get incidentId => (origin as IncidentRatingProvider).incidentId;
}

String _$contractorDocumentsHash() =>
    r'da26ecdfeaf587e6ac68dacf78f60343202f4b1f';

/// See also [contractorDocuments].
@ProviderFor(contractorDocuments)
final contractorDocumentsProvider =
    AutoDisposeFutureProvider<List<ContractorDocument>>.internal(
      contractorDocuments,
      name: r'contractorDocumentsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$contractorDocumentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorDocumentsRef =
    AutoDisposeFutureProviderRef<List<ContractorDocument>>;
String _$adminPendingContractorsHash() =>
    r'5d690b2aa7145dfba89d5c102ad2b392f02895b3';

/// See also [adminPendingContractors].
@ProviderFor(adminPendingContractors)
final adminPendingContractorsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminPendingContractors,
      name: r'adminPendingContractorsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminPendingContractorsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminPendingContractorsRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$adminContractorDocsHash() =>
    r'84695a7fc96f6932ec73519e1f117e6ac27b58da';

/// See also [adminContractorDocs].
@ProviderFor(adminContractorDocs)
const adminContractorDocsProvider = AdminContractorDocsFamily();

/// See also [adminContractorDocs].
class AdminContractorDocsFamily
    extends Family<AsyncValue<List<ContractorDocument>>> {
  /// See also [adminContractorDocs].
  const AdminContractorDocsFamily();

  /// See also [adminContractorDocs].
  AdminContractorDocsProvider call(String contractorId) {
    return AdminContractorDocsProvider(contractorId);
  }

  @override
  AdminContractorDocsProvider getProviderOverride(
    covariant AdminContractorDocsProvider provider,
  ) {
    return call(provider.contractorId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'adminContractorDocsProvider';
}

/// See also [adminContractorDocs].
class AdminContractorDocsProvider
    extends AutoDisposeFutureProvider<List<ContractorDocument>> {
  /// See also [adminContractorDocs].
  AdminContractorDocsProvider(String contractorId)
    : this._internal(
        (ref) =>
            adminContractorDocs(ref as AdminContractorDocsRef, contractorId),
        from: adminContractorDocsProvider,
        name: r'adminContractorDocsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$adminContractorDocsHash,
        dependencies: AdminContractorDocsFamily._dependencies,
        allTransitiveDependencies:
            AdminContractorDocsFamily._allTransitiveDependencies,
        contractorId: contractorId,
      );

  AdminContractorDocsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.contractorId,
  }) : super.internal();

  final String contractorId;

  @override
  Override overrideWith(
    FutureOr<List<ContractorDocument>> Function(AdminContractorDocsRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AdminContractorDocsProvider._internal(
        (ref) => create(ref as AdminContractorDocsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        contractorId: contractorId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ContractorDocument>> createElement() {
    return _AdminContractorDocsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AdminContractorDocsProvider &&
        other.contractorId == contractorId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, contractorId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AdminContractorDocsRef
    on AutoDisposeFutureProviderRef<List<ContractorDocument>> {
  /// The parameter `contractorId` of this provider.
  String get contractorId;
}

class _AdminContractorDocsProviderElement
    extends AutoDisposeFutureProviderElement<List<ContractorDocument>>
    with AdminContractorDocsRef {
  _AdminContractorDocsProviderElement(super.provider);

  @override
  String get contractorId =>
      (origin as AdminContractorDocsProvider).contractorId;
}

String _$adminAllContractorsHash() =>
    r'55e309845de82e0a11c9394a7c9fd26efc6560eb';

/// See also [adminAllContractors].
@ProviderFor(adminAllContractors)
final adminAllContractorsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminAllContractors,
      name: r'adminAllContractorsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminAllContractorsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminAllContractorsRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$adminContractorInvitesHash() =>
    r'db56d9f11cac682cdcb7b066fc106bed146985dc';

/// See also [adminContractorInvites].
@ProviderFor(adminContractorInvites)
final adminContractorInvitesProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminContractorInvites,
      name: r'adminContractorInvitesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminContractorInvitesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminContractorInvitesRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$adminStatsHash() => r'7629da15c76197ee538e435c2f3fcd6a1430033c';

/// See also [adminStats].
@ProviderFor(adminStats)
final adminStatsProvider = AutoDisposeFutureProvider<AdminStats>.internal(
  adminStats,
  name: r'adminStatsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminStatsRef = AutoDisposeFutureProviderRef<AdminStats>;
String _$adminOpenDisputesHash() => r'b00a8f984f92f13645ff82c18785f3ade1cc6cda';

/// See also [adminOpenDisputes].
@ProviderFor(adminOpenDisputes)
final adminOpenDisputesProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminOpenDisputes,
      name: r'adminOpenDisputesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminOpenDisputesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminOpenDisputesRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$adminAllUsersHash() => r'82b7f73ee50f038ff2710d46203270fa69de94e9';

/// See also [adminAllUsers].
@ProviderFor(adminAllUsers)
final adminAllUsersProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminAllUsers,
      name: r'adminAllUsersProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminAllUsersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminAllUsersRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$adminPayoutLogHash() => r'a8298aad85cc6b23d753749041d93219bf5f8d49';

/// See also [adminPayoutLog].
@ProviderFor(adminPayoutLog)
final adminPayoutLogProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      adminPayoutLog,
      name: r'adminPayoutLogProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminPayoutLogHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminPayoutLogRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$incidentActionsHash() => r'890912b79349956515fbf11ae95862e341110937';

/// See also [IncidentActions].
@ProviderFor(IncidentActions)
final incidentActionsProvider =
    AutoDisposeNotifierProvider<IncidentActions, AsyncValue<void>>.internal(
      IncidentActions.new,
      name: r'incidentActionsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$incidentActionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$IncidentActions = AutoDisposeNotifier<AsyncValue<void>>;
String _$resolveDisputeHash() => r'8ba1689767c31c4f5b5d57a6b3c06df0f60cf63a';

/// See also [ResolveDispute].
@ProviderFor(ResolveDispute)
final resolveDisputeProvider =
    AutoDisposeNotifierProvider<ResolveDispute, AsyncValue<void>>.internal(
      ResolveDispute.new,
      name: r'resolveDisputeProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$resolveDisputeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ResolveDispute = AutoDisposeNotifier<AsyncValue<void>>;
String _$addTenancyHash() => r'51fa991f94700cab55cf8c4b2ab6382a84f2a4a9';

/// See also [AddTenancy].
@ProviderFor(AddTenancy)
final addTenancyProvider =
    AutoDisposeNotifierProvider<AddTenancy, AsyncValue<void>>.internal(
      AddTenancy.new,
      name: r'addTenancyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$addTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AddTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$serveNoticeHash() => r'ea945f6bd5ec763d330ffeaba528080445e7729f';

/// See also [ServeNotice].
@ProviderFor(ServeNotice)
final serveNoticeProvider =
    AutoDisposeNotifierProvider<ServeNotice, AsyncValue<void>>.internal(
      ServeNotice.new,
      name: r'serveNoticeProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$serveNoticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ServeNotice = AutoDisposeNotifier<AsyncValue<void>>;
String _$endTenancyHash() => r'297fa041964bc02989551eb4bc7194d3ee457585';

/// See also [EndTenancy].
@ProviderFor(EndTenancy)
final endTenancyProvider =
    AutoDisposeNotifierProvider<EndTenancy, AsyncValue<void>>.internal(
      EndTenancy.new,
      name: r'endTenancyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$endTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EndTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$deleteTenancyHash() => r'89658cea4922eef3761272f562ffa5c0e4a714d5';

/// See also [DeleteTenancy].
@ProviderFor(DeleteTenancy)
final deleteTenancyProvider =
    AutoDisposeNotifierProvider<DeleteTenancy, AsyncValue<void>>.internal(
      DeleteTenancy.new,
      name: r'deleteTenancyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$deleteTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DeleteTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$holdingDepositHash() => r'5275d53b39d76f028581811df320fd7656b8ffa5';

/// See also [HoldingDeposit].
@ProviderFor(HoldingDeposit)
final holdingDepositProvider =
    AutoDisposeNotifierProvider<HoldingDeposit, AsyncValue<void>>.internal(
      HoldingDeposit.new,
      name: r'holdingDepositProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$holdingDepositHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$HoldingDeposit = AutoDisposeNotifier<AsyncValue<void>>;
String _$acceptInvitationHash() => r'3fa7118245a65380d3dc006115ebe426a33173f5';

/// See also [AcceptInvitation].
@ProviderFor(AcceptInvitation)
final acceptInvitationProvider =
    AutoDisposeNotifierProvider<AcceptInvitation, AsyncValue<void>>.internal(
      AcceptInvitation.new,
      name: r'acceptInvitationProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$acceptInvitationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AcceptInvitation = AutoDisposeNotifier<AsyncValue<void>>;
String _$landlordOfferDecisionHash() =>
    r'eeb6dfde344bb5b32a995d0e9246354ebca606d0';

/// See also [LandlordOfferDecision].
@ProviderFor(LandlordOfferDecision)
final landlordOfferDecisionProvider = AutoDisposeNotifierProvider<
  LandlordOfferDecision,
  AsyncValue<void>
>.internal(
  LandlordOfferDecision.new,
  name: r'landlordOfferDecisionProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$landlordOfferDecisionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LandlordOfferDecision = AutoDisposeNotifier<AsyncValue<void>>;
String _$createIncidentHash() => r'b7e8d337ed325fbeac3689063f2fb388403970ee';

/// See also [CreateIncident].
@ProviderFor(CreateIncident)
final createIncidentProvider =
    AutoDisposeNotifierProvider<CreateIncident, AsyncValue<void>>.internal(
      CreateIncident.new,
      name: r'createIncidentProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$createIncidentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CreateIncident = AutoDisposeNotifier<AsyncValue<void>>;
String _$tenantMarkCompleteHash() =>
    r'db920620888a1a00b3e1abea5890c9b343222df8';

/// See also [TenantMarkComplete].
@ProviderFor(TenantMarkComplete)
final tenantMarkCompleteProvider =
    AutoDisposeNotifierProvider<TenantMarkComplete, AsyncValue<void>>.internal(
      TenantMarkComplete.new,
      name: r'tenantMarkCompleteProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$submitQuoteHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitQuote = AutoDisposeNotifier<AsyncValue<void>>;
String _$declineJobHash() => r'74f890294d709b2aff810b58108227fdb8a658fa';

/// See also [DeclineJob].
@ProviderFor(DeclineJob)
final declineJobProvider =
    AutoDisposeNotifierProvider<DeclineJob, AsyncValue<void>>.internal(
      DeclineJob.new,
      name: r'declineJobProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$declineJobHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DeclineJob = AutoDisposeNotifier<AsyncValue<void>>;
String _$releaseJobHash() => r'20e471de6b5ad9819130359c4af56118bd9f63c1';

/// See also [ReleaseJob].
@ProviderFor(ReleaseJob)
final releaseJobProvider =
    AutoDisposeNotifierProvider<ReleaseJob, AsyncValue<void>>.internal(
      ReleaseJob.new,
      name: r'releaseJobProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$releaseJobHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReleaseJob = AutoDisposeNotifier<AsyncValue<void>>;
String _$contractorMarkCompleteHash() =>
    r'902a05077fb62e8848ef79648b2efbb66d404069';

/// See also [ContractorMarkComplete].
@ProviderFor(ContractorMarkComplete)
final contractorMarkCompleteProvider = AutoDisposeNotifierProvider<
  ContractorMarkComplete,
  AsyncValue<void>
>.internal(
  ContractorMarkComplete.new,
  name: r'contractorMarkCompleteProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$contractorMarkCompleteHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ContractorMarkComplete = AutoDisposeNotifier<AsyncValue<void>>;
String _$manageListingHash() => r'6c445cf2eda244118245212090d0d6debdd675de';

/// See also [ManageListing].
@ProviderFor(ManageListing)
final manageListingProvider =
    AutoDisposeNotifierProvider<ManageListing, AsyncValue<void>>.internal(
      ManageListing.new,
      name: r'manageListingProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$manageListingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ManageListing = AutoDisposeNotifier<AsyncValue<void>>;
String _$toggleListingHash() => r'15df68115f3707c26a4aed090361f833a7d1bc63';

/// See also [ToggleListing].
@ProviderFor(ToggleListing)
final toggleListingProvider =
    AutoDisposeNotifierProvider<ToggleListing, AsyncValue<void>>.internal(
      ToggleListing.new,
      name: r'toggleListingProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$toggleListingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ToggleListing = AutoDisposeNotifier<AsyncValue<void>>;
String _$submitApplicationHash() => r'81ba74b4afe3996447d754224b9a2e61d34c890c';

/// See also [SubmitApplication].
@ProviderFor(SubmitApplication)
final submitApplicationProvider =
    AutoDisposeNotifierProvider<SubmitApplication, AsyncValue<void>>.internal(
      SubmitApplication.new,
      name: r'submitApplicationProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$submitApplicationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitApplication = AutoDisposeNotifier<AsyncValue<void>>;
String _$reviewApplicationHash() => r'6df72463581fee05f5ee87dc88b3c2e0ebb4e501';

/// See also [ReviewApplication].
@ProviderFor(ReviewApplication)
final reviewApplicationProvider =
    AutoDisposeNotifierProvider<ReviewApplication, AsyncValue<void>>.internal(
      ReviewApplication.new,
      name: r'reviewApplicationProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$reviewApplicationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReviewApplication = AutoDisposeNotifier<AsyncValue<void>>;
String _$markNotificationReadHash() =>
    r'7a3a539879345605defca81c737cdb365061417f';

/// See also [MarkNotificationRead].
@ProviderFor(MarkNotificationRead)
final markNotificationReadProvider = AutoDisposeNotifierProvider<
  MarkNotificationRead,
  AsyncValue<void>
>.internal(
  MarkNotificationRead.new,
  name: r'markNotificationReadProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$markNotificationReadHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MarkNotificationRead = AutoDisposeNotifier<AsyncValue<void>>;
String _$markAllNotificationsReadHash() =>
    r'2c2ba4c175793388b4f1193e7a9ca0d817ee69b3';

/// See also [MarkAllNotificationsRead].
@ProviderFor(MarkAllNotificationsRead)
final markAllNotificationsReadProvider = AutoDisposeNotifierProvider<
  MarkAllNotificationsRead,
  AsyncValue<void>
>.internal(
  MarkAllNotificationsRead.new,
  name: r'markAllNotificationsReadProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$markAllNotificationsReadHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MarkAllNotificationsRead = AutoDisposeNotifier<AsyncValue<void>>;
String _$postIncidentCommentHash() =>
    r'e1ec0a95d0bd6c464a2eff1852a18cccea571c04';

/// See also [PostIncidentComment].
@ProviderFor(PostIncidentComment)
final postIncidentCommentProvider =
    AutoDisposeNotifierProvider<PostIncidentComment, AsyncValue<void>>.internal(
      PostIncidentComment.new,
      name: r'postIncidentCommentProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$postIncidentCommentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PostIncidentComment = AutoDisposeNotifier<AsyncValue<void>>;
String _$logRentPaymentHash() => r'8d4e28ac23424adb5a837e4f9f88f45ee750626c';

/// See also [LogRentPayment].
@ProviderFor(LogRentPayment)
final logRentPaymentProvider =
    AutoDisposeNotifierProvider<LogRentPayment, AsyncValue<void>>.internal(
      LogRentPayment.new,
      name: r'logRentPaymentProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$logRentPaymentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LogRentPayment = AutoDisposeNotifier<AsyncValue<void>>;
String _$updateRentPaymentHash() => r'6bcf36dedfd3f72db8ced0ea950d01e0e244fe2d';

/// See also [UpdateRentPayment].
@ProviderFor(UpdateRentPayment)
final updateRentPaymentProvider =
    AutoDisposeNotifierProvider<UpdateRentPayment, AsyncValue<void>>.internal(
      UpdateRentPayment.new,
      name: r'updateRentPaymentProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$updateRentPaymentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UpdateRentPayment = AutoDisposeNotifier<AsyncValue<void>>;
String _$flagRentDiscrepancyHash() =>
    r'8dad8a41da5f297ac8c10c11d191e5d67d348612';

/// See also [FlagRentDiscrepancy].
@ProviderFor(FlagRentDiscrepancy)
final flagRentDiscrepancyProvider =
    AutoDisposeNotifierProvider<FlagRentDiscrepancy, AsyncValue<void>>.internal(
      FlagRentDiscrepancy.new,
      name: r'flagRentDiscrepancyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$flagRentDiscrepancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FlagRentDiscrepancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$resolveRentDiscrepancyHash() =>
    r'85ad5c6778b8ef92522b18036f87b1e7a04cfb76';

/// See also [ResolveRentDiscrepancy].
@ProviderFor(ResolveRentDiscrepancy)
final resolveRentDiscrepancyProvider = AutoDisposeNotifierProvider<
  ResolveRentDiscrepancy,
  AsyncValue<void>
>.internal(
  ResolveRentDiscrepancy.new,
  name: r'resolveRentDiscrepancyProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$resolveRentDiscrepancyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ResolveRentDiscrepancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$generateRentScheduleHash() =>
    r'7e692bce8c209d52128d29f7b6953d9ea859cd4d';

/// See also [GenerateRentSchedule].
@ProviderFor(GenerateRentSchedule)
final generateRentScheduleProvider = AutoDisposeNotifierProvider<
  GenerateRentSchedule,
  AsyncValue<void>
>.internal(
  GenerateRentSchedule.new,
  name: r'generateRentScheduleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$generateRentScheduleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GenerateRentSchedule = AutoDisposeNotifier<AsyncValue<void>>;
String _$markRentPaidHash() => r'33a2f462f0560bf54169209622c1b88818a93f47';

/// See also [MarkRentPaid].
@ProviderFor(MarkRentPaid)
final markRentPaidProvider =
    AutoDisposeNotifierProvider<MarkRentPaid, AsyncValue<void>>.internal(
      MarkRentPaid.new,
      name: r'markRentPaidProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$markRentPaidHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$MarkRentPaid = AutoDisposeNotifier<AsyncValue<void>>;
String _$saveContractorDetailsHash() =>
    r'636b2a94e247064b328c9b9a72a032e5eabafb3d';

/// See also [SaveContractorDetails].
@ProviderFor(SaveContractorDetails)
final saveContractorDetailsProvider = AutoDisposeNotifierProvider<
  SaveContractorDetails,
  AsyncValue<void>
>.internal(
  SaveContractorDetails.new,
  name: r'saveContractorDetailsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$saveContractorDetailsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SaveContractorDetails = AutoDisposeNotifier<AsyncValue<void>>;
String _$submitRatingHash() => r'e553297b8d31e1b03d6d4144c9d3d60259d6cef9';

/// See also [SubmitRating].
@ProviderFor(SubmitRating)
final submitRatingProvider =
    AutoDisposeNotifierProvider<SubmitRating, AsyncValue<void>>.internal(
      SubmitRating.new,
      name: r'submitRatingProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$submitRatingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitRating = AutoDisposeNotifier<AsyncValue<void>>;
String _$serveSection8NoticeHash() =>
    r'c00eb768fd26e499a81fffc9e06824431273f553';

/// See also [ServeSection8Notice].
@ProviderFor(ServeSection8Notice)
final serveSection8NoticeProvider =
    AutoDisposeNotifierProvider<ServeSection8Notice, AsyncValue<void>>.internal(
      ServeSection8Notice.new,
      name: r'serveSection8NoticeProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$serveSection8NoticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ServeSection8Notice = AutoDisposeNotifier<AsyncValue<void>>;
String _$serveSection13NoticeHash() =>
    r'318b13e635dceb9238de824f291b538435a019dd';

/// See also [ServeSection13Notice].
@ProviderFor(ServeSection13Notice)
final serveSection13NoticeProvider = AutoDisposeNotifierProvider<
  ServeSection13Notice,
  AsyncValue<void>
>.internal(
  ServeSection13Notice.new,
  name: r'serveSection13NoticeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$serveSection13NoticeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ServeSection13Notice = AutoDisposeNotifier<AsyncValue<void>>;
String _$submitForReviewHash() => r'6a447f5dd63c2f177e1a80a8cfcbee088b97dbb6';

/// See also [SubmitForReview].
@ProviderFor(SubmitForReview)
final submitForReviewProvider =
    AutoDisposeNotifierProvider<SubmitForReview, AsyncValue<void>>.internal(
      SubmitForReview.new,
      name: r'submitForReviewProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$submitForReviewHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitForReview = AutoDisposeNotifier<AsyncValue<void>>;
String _$adminVetContractorHash() =>
    r'6ef13e391e562ecccda2a312d9e0bf5ff01255fa';

/// See also [AdminVetContractor].
@ProviderFor(AdminVetContractor)
final adminVetContractorProvider =
    AutoDisposeNotifierProvider<AdminVetContractor, AsyncValue<void>>.internal(
      AdminVetContractor.new,
      name: r'adminVetContractorProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminVetContractorHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AdminVetContractor = AutoDisposeNotifier<AsyncValue<void>>;
String _$adminInviteContractorHash() =>
    r'92f868221474801530c51bd1c378014133cb1159';

/// See also [AdminInviteContractor].
@ProviderFor(AdminInviteContractor)
final adminInviteContractorProvider = AutoDisposeNotifierProvider<
  AdminInviteContractor,
  AsyncValue<void>
>.internal(
  AdminInviteContractor.new,
  name: r'adminInviteContractorProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$adminInviteContractorHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AdminInviteContractor = AutoDisposeNotifier<AsyncValue<void>>;
String _$resetForReapplyHash() => r'ea0a065e3e1af5a0e29e8393ee8a7e9549ccb11e';

/// See also [ResetForReapply].
@ProviderFor(ResetForReapply)
final resetForReapplyProvider =
    AutoDisposeNotifierProvider<ResetForReapply, AsyncValue<void>>.internal(
      ResetForReapply.new,
      name: r'resetForReapplyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$resetForReapplyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ResetForReapply = AutoDisposeNotifier<AsyncValue<void>>;
String _$adminResolveDisputeHash() =>
    r'72ad1e23e6e4627c3ac12073e046c5d0deb8f578';

/// See also [AdminResolveDispute].
@ProviderFor(AdminResolveDispute)
final adminResolveDisputeProvider =
    AutoDisposeNotifierProvider<AdminResolveDispute, AsyncValue<void>>.internal(
      AdminResolveDispute.new,
      name: r'adminResolveDisputeProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$adminResolveDisputeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AdminResolveDispute = AutoDisposeNotifier<AsyncValue<void>>;
String _$requestVisitHash() => r'6928728577cca1bbfdd581e87af48f9272733dba';

/// See also [RequestVisit].
@ProviderFor(RequestVisit)
final requestVisitProvider =
    AutoDisposeNotifierProvider<RequestVisit, AsyncValue<void>>.internal(
      RequestVisit.new,
      name: r'requestVisitProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$requestVisitHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RequestVisit = AutoDisposeNotifier<AsyncValue<void>>;
String _$confirmVisitHash() => r'92277b84863a213eafbacc8d06b684f01199147b';

/// See also [ConfirmVisit].
@ProviderFor(ConfirmVisit)
final confirmVisitProvider =
    AutoDisposeNotifierProvider<ConfirmVisit, AsyncValue<void>>.internal(
      ConfirmVisit.new,
      name: r'confirmVisitProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$confirmVisitHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ConfirmVisit = AutoDisposeNotifier<AsyncValue<void>>;
String _$respondToPetRequestHash() =>
    r'2dc539cad0c2da577cda5396f6f63df8e0f558de';

/// See also [RespondToPetRequest].
@ProviderFor(RespondToPetRequest)
final respondToPetRequestProvider =
    AutoDisposeNotifierProvider<RespondToPetRequest, AsyncValue<void>>.internal(
      RespondToPetRequest.new,
      name: r'respondToPetRequestProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$respondToPetRequestHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RespondToPetRequest = AutoDisposeNotifier<AsyncValue<void>>;
String _$setupDirectDebitHash() => r'0203d6f8ae275fff0aac4ec609f250c4c9301d13';

/// See also [SetupDirectDebit].
@ProviderFor(SetupDirectDebit)
final setupDirectDebitProvider =
    AutoDisposeNotifierProvider<SetupDirectDebit, AsyncValue<String?>>.internal(
      SetupDirectDebit.new,
      name: r'setupDirectDebitProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$setupDirectDebitHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SetupDirectDebit = AutoDisposeNotifier<AsyncValue<String?>>;
String _$collectDirectDebitHash() =>
    r'fea77acaba0fd9f70fc0a0f5162c33e01865679b';

/// See also [CollectDirectDebit].
@ProviderFor(CollectDirectDebit)
final collectDirectDebitProvider =
    AutoDisposeNotifierProvider<CollectDirectDebit, AsyncValue<void>>.internal(
      CollectDirectDebit.new,
      name: r'collectDirectDebitProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$collectDirectDebitHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CollectDirectDebit = AutoDisposeNotifier<AsyncValue<void>>;
String _$registerTdsDepositHash() =>
    r'035b0215e022d1a4eb35805bf829df5c419f801c';

/// See also [RegisterTdsDeposit].
@ProviderFor(RegisterTdsDeposit)
final registerTdsDepositProvider =
    AutoDisposeNotifierProvider<RegisterTdsDeposit, AsyncValue<void>>.internal(
      RegisterTdsDeposit.new,
      name: r'registerTdsDepositProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$registerTdsDepositHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RegisterTdsDeposit = AutoDisposeNotifier<AsyncValue<void>>;
String _$lookupEpcHash() => r'5d81f67163bdebbf7616ba7333bbd7f5b57fd46e';

/// See also [LookupEpc].
@ProviderFor(LookupEpc)
final lookupEpcProvider = AutoDisposeNotifierProvider<
  LookupEpc,
  AsyncValue<Map<String, dynamic>?>
>.internal(
  LookupEpc.new,
  name: r'lookupEpcProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$lookupEpcHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LookupEpc = AutoDisposeNotifier<AsyncValue<Map<String, dynamic>?>>;
String _$registerDpsDepositHash() =>
    r'3a9558d64dd44e5eacf33b8be68db31cf6bda08a';

/// See also [RegisterDpsDeposit].
@ProviderFor(RegisterDpsDeposit)
final registerDpsDepositProvider =
    AutoDisposeNotifierProvider<RegisterDpsDeposit, AsyncValue<void>>.internal(
      RegisterDpsDeposit.new,
      name: r'registerDpsDepositProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$registerDpsDepositHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RegisterDpsDeposit = AutoDisposeNotifier<AsyncValue<void>>;
String _$createRepositPolicyHash() =>
    r'770c850a3359e410939e60564216cbebe4ce8fe9';

/// See also [CreateRepositPolicy].
@ProviderFor(CreateRepositPolicy)
final createRepositPolicyProvider =
    AutoDisposeNotifierProvider<CreateRepositPolicy, AsyncValue<void>>.internal(
      CreateRepositPolicy.new,
      name: r'createRepositPolicyProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$createRepositPolicyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CreateRepositPolicy = AutoDisposeNotifier<AsyncValue<void>>;
String _$createStripeCheckoutHash() =>
    r'db352d4c4445590b2d61d54433c6eba5c40e1823';

/// Creates a Stripe Checkout Session and returns the hosted URL.
/// [interval] is 'monthly' (default) or 'annual'.
///
/// Copied from [CreateStripeCheckout].
@ProviderFor(CreateStripeCheckout)
final createStripeCheckoutProvider = AutoDisposeNotifierProvider<
  CreateStripeCheckout,
  AsyncValue<void>
>.internal(
  CreateStripeCheckout.new,
  name: r'createStripeCheckoutProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$createStripeCheckoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CreateStripeCheckout = AutoDisposeNotifier<AsyncValue<void>>;
String _$openCustomerPortalHash() =>
    r'3e3ed5dc1ee57faf04e791f04c8dfd559d689ae8';

/// Opens the Stripe Customer Portal (manage/cancel subscriptions).
///
/// Copied from [OpenCustomerPortal].
@ProviderFor(OpenCustomerPortal)
final openCustomerPortalProvider =
    AutoDisposeNotifierProvider<OpenCustomerPortal, AsyncValue<void>>.internal(
      OpenCustomerPortal.new,
      name: r'openCustomerPortalProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$openCustomerPortalHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$OpenCustomerPortal = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
