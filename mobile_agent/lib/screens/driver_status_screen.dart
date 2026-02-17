import 'package:flutter/material.dart';

class DriverStatusScreen extends StatefulWidget {
  final bool initialAvailable;
  final ValueChanged<bool> onStatusChanged;
  const DriverStatusScreen({super.key, required this.initialAvailable, required this.onStatusChanged});

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  late bool _available;

  @override
  void initState() {
    super.initState();
    _available = widget.initialAvailable;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Statut : ', style: TextStyle(fontSize: 16)),
        Switch(
          value: _available,
          onChanged: (val) {
            setState(() => _available = val);
            widget.onStatusChanged(val);
          },
        ),
        Text(_available ? 'Disponible' : 'Indisponible', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
