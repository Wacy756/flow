class ServiceArea {
  final String name;
  final double lat;
  final double lng;
  final double radius; // stored in metres (matching Leaflet web app)

  const ServiceArea({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) => ServiceArea(
        name: json['name'] as String? ?? 'Area',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      };

  /// Radius in miles for display
  double get radiusMiles => radius / 1609.34;

  ServiceArea copyWith({String? name, double? lat, double? lng, double? radius}) =>
      ServiceArea(
        name: name ?? this.name,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radius: radius ?? this.radius,
      );
}
