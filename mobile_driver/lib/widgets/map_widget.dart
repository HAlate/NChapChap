import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapWidget extends StatefulWidget {
  final LatLng? initialPosition;
  final double? height;
  final Set<Marker>? markers;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final double zoom;

  const MapWidget({
    super.key,
    this.initialPosition,
    this.height,
    this.markers,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
    this.zoomControlsEnabled = false,
    this.zoom = 16,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = widget.initialPosition ?? const LatLng(6.1725, 1.2314);

    return Container(
      height: widget.height ?? 300,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: position,
          zoom: widget.zoom,
        ),
        markers: widget.markers ?? {},
        myLocationEnabled: widget.myLocationEnabled,
        myLocationButtonEnabled: widget.myLocationButtonEnabled,
        zoomControlsEnabled: widget.zoomControlsEnabled,
        onMapCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
