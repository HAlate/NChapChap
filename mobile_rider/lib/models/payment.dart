class Payment {
  final int id;
  final int userId;
  final int tripId;
  final double amount;
  final String method;
  final String status;

  Payment({required this.id, required this.userId, required this.tripId, required this.amount, required this.method, required this.status});
}
