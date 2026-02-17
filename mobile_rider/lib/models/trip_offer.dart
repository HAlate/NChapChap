class TripOffer {
  final String id;
  final String tripId;
  final String driverId;
  final int offeredPrice;
  final int? counterPrice;
  final int? finalPrice;
  final int etaMinutes;
  final String? vehicleType; // Type de véhicule demandé par le rider
  final String? driverVehicleType; // Type de véhicule du driver
  final String status;
  final bool tokenSpent;
  final DateTime createdAt;

  final String? driverName;
  final double? driverRating;
  final int? driverTotalTrips;
  final String? driverPhone;
  final String? driverVehiclePlate;

  final String? departure;
  final String? destination;
  // Ajout des coordonnées pour le débogage et les futures fonctionnalités
  final double? departureLat;
  final double? departureLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? driverLatAtOffer;
  final double? driverLngAtOffer;

  TripOffer({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.offeredPrice,
    this.counterPrice,
    this.finalPrice,
    required this.etaMinutes,
    this.vehicleType,
    this.driverVehicleType,
    required this.status,
    required this.tokenSpent,
    required this.createdAt,
    this.driverName,
    this.driverRating,
    this.driverTotalTrips,
    this.driverPhone,
    this.driverVehiclePlate,
    this.departure,
    this.destination,
    this.departureLat,
    this.departureLng,
    this.destinationLat,
    this.destinationLng,
    this.driverLatAtOffer,
    this.driverLngAtOffer,
  });

  factory TripOffer.fromJson(Map<String, dynamic> json) {
    return TripOffer(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      driverId: json['driver_id'] as String,
      offeredPrice: json['offered_price'] as int,
      counterPrice: json['counter_price'] as int?,
      finalPrice: json['final_price'] as int?,
      etaMinutes: json['eta_minutes'] as int,
      vehicleType: json['vehicle_type'] as String?,
      driverVehicleType: json['driver_vehicle_type'] as String?,
      status: json['status'] as String,
      tokenSpent: json['token_spent'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      driverName: json['driver_name'] as String?,
      driverRating: (json['driver_rating'] as num?)?.toDouble(),
      driverTotalTrips: json['driver_total_trips'] as int?,
      driverPhone: json['driver_phone'] as String?,
      driverVehiclePlate: json['driver_vehicle_plate'] as String?,
      // La vue SQL utilise departure_address et destination_address
      departure:
          json['departure_address'] as String? ?? json['departure'] as String?,
      destination: json['destination_address'] as String? ??
          json['destination'] as String?,
      departureLat: (json['departure_lat'] as num?)?.toDouble(),
      departureLng: (json['departure_lng'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      driverLatAtOffer: (json['driver_lat_at_offer'] as num?)?.toDouble(),
      driverLngAtOffer: (json['driver_lng_at_offer'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'driver_id': driverId,
      'offered_price': offeredPrice,
      'counter_price': counterPrice,
      'final_price': finalPrice,
      'eta_minutes': etaMinutes,
      'vehicle_type': vehicleType,
      'status': status,
      'token_spent': tokenSpent,
      'created_at': createdAt.toIso8601String(),
      'driver_name': driverName,
      'driver_rating': driverRating,
      'driver_total_trips': driverTotalTrips,
      'driver_phone': driverPhone,
      'driver_vehicle_plate': driverVehiclePlate,
      'departure': departure,
      'destination': destination,
      'departure_lat': departureLat,
      'departure_lng': departureLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'driver_lat_at_offer': driverLatAtOffer,
      'driver_lng_at_offer': driverLngAtOffer,
    };
  }

  TripOffer copyWith({
    String? id,
    String? tripId,
    String? driverId,
    int? offeredPrice,
    int? counterPrice,
    int? finalPrice,
    int? etaMinutes,
    String? vehicleType,
    String? status,
    bool? tokenSpent,
    DateTime? createdAt,
    String? driverName,
    double? driverRating,
    int? driverTotalTrips,
    String? driverPhone,
    String? driverVehiclePlate,
    String? departure,
    String? destination,
    double? departureLat,
    double? departureLng,
    double? destinationLat,
    double? destinationLng,
    double? driverLatAtOffer,
    double? driverLngAtOffer,
  }) {
    return TripOffer(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      driverId: driverId ?? this.driverId,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      counterPrice: counterPrice ?? this.counterPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      tokenSpent: tokenSpent ?? this.tokenSpent,
      createdAt: createdAt ?? this.createdAt,
      driverName: driverName ?? this.driverName,
      driverRating: driverRating ?? this.driverRating,
      driverTotalTrips: driverTotalTrips ?? this.driverTotalTrips,
      driverPhone: driverPhone ?? this.driverPhone,
      driverVehiclePlate: driverVehiclePlate ?? this.driverVehiclePlate,
      departure: departure ?? this.departure,
      destination: destination ?? this.destination,
      departureLat: departureLat ?? this.departureLat,
      departureLng: departureLng ?? this.departureLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      driverLatAtOffer: driverLatAtOffer ?? this.driverLatAtOffer,
      driverLngAtOffer: driverLngAtOffer ?? this.driverLngAtOffer,
    );
  }

  bool get isPending => status == 'pending';
  bool get isSelected => status == 'selected';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isNotSelected => status == 'not_selected';

  int get currentPrice => finalPrice ?? counterPrice ?? offeredPrice;

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'selected':
        return 'Sélectionné';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      case 'not_selected':
        return 'Non sélectionné';
      default:
        return status;
    }
  }
}
