import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class IncidentLiveMap extends StatefulWidget {
  final String incidentId;

  /// If true, draw a straight polyline between responder and incident.
  final bool showSimpleRouteLine;

  /// If true, show responder marker even if not dispatched.
  final bool alwaysShowResponder;

  const IncidentLiveMap({
    super.key,
    required this.incidentId,
    this.showSimpleRouteLine = true,
    this.alwaysShowResponder = false,
  });

  @override
  State<IncidentLiveMap> createState() => _IncidentLiveMapState();
}

class _IncidentLiveMapState extends State<IncidentLiveMap> {
  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _fitCamera({required LatLng incident, LatLng? responder}) {
    final c = _controller;
    if (c == null) return;

    // If only incident location exists, center there.
    if (responder == null) {
      c.animateCamera(CameraUpdate.newLatLngZoom(incident, 15));
      return;
    }

    final bounds = _latLngBounds(incident, responder);
    c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  LatLngBounds _latLngBounds(LatLng a, LatLng b) {
    final southWest = LatLng(
      min(a.latitude, b.latitude),
      min(a.longitude, b.longitude),
    );
    final northEast = LatLng(
      max(a.latitude, b.latitude),
      max(a.longitude, b.longitude),
    );
    return LatLngBounds(southwest: southWest, northeast: northEast);
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('incidents')
        .doc(widget.incidentId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final d = snap.data!.data() ?? <String, dynamic>{};

        // incident location
        final rawLat = d['latitude'];
        final rawLng = d['longitude'];
        final lat = (rawLat is num) ? rawLat.toDouble() : 0.0;
        final lng = (rawLng is num) ? rawLng.toDouble() : 0.0;

        final incidentValid = !(lat == 0.0 && lng == 0.0);
        if (!incidentValid) {
          return const Center(child: Text('Incident location not available.'));
        }

        final incidentPos = LatLng(lat, lng);

        // responder live location (GeoPoint)
        LatLng? responderPos;
        final rl = d['responderLiveLocation'];
        if (rl is GeoPoint) {
          responderPos = LatLng(rl.latitude, rl.longitude);
        }

        final statusCode = (d['statusCode'] ?? '').toString();
        final dispatched = statusCode == 'responder_dispatched';

        // Markers
        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('incident'),
            position: incidentPos,
            infoWindow: const InfoWindow(title: 'Incident Location'),
          ),
        };

        final showResponder = widget.alwaysShowResponder || dispatched;
        if (showResponder && responderPos != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('responder'),
              position: responderPos,
              infoWindow: const InfoWindow(title: 'Responder'),
            ),
          );
        }

        // Simple straight route line (no Directions API required)
        final polylines = <Polyline>{};
        if (widget.showSimpleRouteLine && dispatched && responderPos != null) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('simple_route'),
              points: [responderPos, incidentPos],
              width: 5,
            ),
          );
        }

        // After build, attempt to fit camera nicely
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitCamera(
            incident: incidentPos,
            responder: (showResponder ? responderPos : null),
          );
        });

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: incidentPos,
              zoom: 15,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (c) => _controller = c,
          ),
        );
      },
    );
  }
}
