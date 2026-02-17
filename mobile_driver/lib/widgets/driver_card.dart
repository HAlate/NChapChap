import 'package:flutter/material.dart';

class DriverCard extends StatelessWidget {
  final String name;
  final String vehicle;
  final double rating;
  const DriverCard({super.key, required this.name, required this.vehicle, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(vehicle),
        trailing: Text(rating.toString()),
      ),
    );
  }
}
