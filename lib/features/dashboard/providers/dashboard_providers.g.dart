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
String _$landlordTenanciesHash() => r'b740aa6c8e96991ecca7594ccdfd3ad198817c51';

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
String _$landlordIncidentsHash() => r'1c876fb2e7940bf5a498b2a65fd3795bd6b92a98';

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

String _$complianceSummaryHash() => r'faa79737250d3615942b176927ff263305600aad';

/// See also [complianceSummary].
@ProviderFor(complianceSummary)
final complianceSummaryProvider =
    AutoDisposeFutureProvider<ComplianceSummary>.internal(
      complianceSummary,
      name: r'complianceSummaryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$endedTenanciesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EndedTenanciesRef = AutoDisposeFutureProviderRef<List<Tenancy>>;
String _$tenantTenanciesHash() => r'80e0134e6382f46074d0182d1a047e03bf792b1b';

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
String _$tenantIncidentsHash() => r'91ced376a245ab1228f1d3b33ba470b1e16dd698';

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
String _$tenantEndedTenanciesHash() =>
    r'c58b0eff52755d9ff24488176eeb60dfc0787de4';

/// See also [tenantEndedTenancies].
@ProviderFor(tenantEndedTenancies)
final tenantEndedTenanciesProvider =
    AutoDisposeFutureProvider<List<Tenancy>>.internal(
      tenantEndedTenancies,
      name: r'tenantEndedTenanciesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$contractorJobsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ContractorJobsRef = AutoDisposeFutureProviderRef<List<Incident>>;
String _$availableJobsHash() => r'3e7707cd589c8e8555f0b9ea8e6215533f292941';

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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
String _$addTenancyHash() => r'51fa991f94700cab55cf8c4b2ab6382a84f2a4a9';

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
String _$serveNoticeHash() => r'5a5f5632a4739a46e19c57de565d39d5369e4e97';

/// See also [ServeNotice].
@ProviderFor(ServeNotice)
final serveNoticeProvider =
    AutoDisposeNotifierProvider<ServeNotice, AsyncValue<void>>.internal(
      ServeNotice.new,
      name: r'serveNoticeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$serveNoticeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ServeNotice = AutoDisposeNotifier<AsyncValue<void>>;
String _$endTenancyHash() => r'd6f5e69b1e6eb47961462371aae7834a0fc8235d';

/// See also [EndTenancy].
@ProviderFor(EndTenancy)
final endTenancyProvider =
    AutoDisposeNotifierProvider<EndTenancy, AsyncValue<void>>.internal(
      EndTenancy.new,
      name: r'endTenancyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$endTenancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EndTenancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$deleteTenancyHash() => r'7dbe801a329de528e71a87cc468b9de3e4dbb87e';

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
String _$createIncidentHash() => r'6d9d3145bc324333a90195b74ea5a335aa58bcc4';

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
String _$declineJobHash() => r'01084d92053ed316787a94f740b9ccada9d9c80b';

/// See also [DeclineJob].
@ProviderFor(DeclineJob)
final declineJobProvider =
    AutoDisposeNotifierProvider<DeclineJob, AsyncValue<void>>.internal(
      DeclineJob.new,
      name: r'declineJobProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$declineJobHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$DeclineJob = AutoDisposeNotifier<AsyncValue<void>>;
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
String _$manageListingHash() => r'6c445cf2eda244118245212090d0d6debdd675de';

/// See also [ManageListing].
@ProviderFor(ManageListing)
final manageListingProvider =
    AutoDisposeNotifierProvider<ManageListing, AsyncValue<void>>.internal(
      ManageListing.new,
      name: r'manageListingProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
final markNotificationReadProvider =
    AutoDisposeNotifierProvider<
      MarkNotificationRead,
      AsyncValue<void>
    >.internal(
      MarkNotificationRead.new,
      name: r'markNotificationReadProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
final markAllNotificationsReadProvider =
    AutoDisposeNotifierProvider<
      MarkAllNotificationsRead,
      AsyncValue<void>
    >.internal(
      MarkAllNotificationsRead.new,
      name: r'markAllNotificationsReadProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
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
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$updateRentPaymentHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UpdateRentPayment = AutoDisposeNotifier<AsyncValue<void>>;
String _$flagRentDiscrepancyHash() =>
    r'fa89a0fcca291e14b5c2b9077c9bb07b92cc992a';

/// See also [FlagRentDiscrepancy].
@ProviderFor(FlagRentDiscrepancy)
final flagRentDiscrepancyProvider =
    AutoDisposeNotifierProvider<FlagRentDiscrepancy, AsyncValue<void>>.internal(
      FlagRentDiscrepancy.new,
      name: r'flagRentDiscrepancyProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$flagRentDiscrepancyHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FlagRentDiscrepancy = AutoDisposeNotifier<AsyncValue<void>>;
String _$saveContractorDetailsHash() =>
    r'8ca498ce5adb5c494030e3575c92106910d36edb';

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
String _$submitRatingHash() => r'e553297b8d31e1b03d6d4144c9d3d60259d6cef9';

/// See also [SubmitRating].
@ProviderFor(SubmitRating)
final submitRatingProvider =
    AutoDisposeNotifierProvider<SubmitRating, AsyncValue<void>>.internal(
      SubmitRating.new,
      name: r'submitRatingProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$submitRatingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubmitRating = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
