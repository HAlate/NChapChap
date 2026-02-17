class Trip {
  final int id;
  final String origin;
  final double? originLat;
  final double? originLng;
  final String destination;
  final double? destLat;
  final double? destLng;
  final String vehicleType;
  final String status;
  final double? proposedPrice;

  Trip({
    required this.id,
    required this.origin,
    this.originLat,
    this.originLng,
    required this.destination,
    this.destLat,
    this.destLng,
    required this.vehicleType,
    required this.status,
    this.proposedPrice,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      origin: json['origin'],
      originLat: json['origin_lat']?.toDouble(),
      originLng: json['origin_lng']?.toDouble(),
      destination: json['destination'],
      destLat: json['dest_lat']?.toDouble(),
      destLng: json['dest_lng']?.toDouble(),
      vehicleType: json['vehicle_type'],
      status: json['status'],
      proposedPrice: json['proposed_price'] != null
          ? double.tryParse(json['proposed_price'].toString())
          : null,
    );
  }
}
