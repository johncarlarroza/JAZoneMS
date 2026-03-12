import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide LatLng, Marker, Polyline;
import 'package:latlong2/latlong.dart';

class IncidentLiveMap extends StatelessWidget {
  final String incidentId;

  /// If true, draw a simple straight line from responder -> incident (not turn-by-turn routing)
  final bool showSimpleRouteLine;

  /// If true, always show responder marker when available (even if not dispatched yet)
  final bool alwaysShowResponder;

  const IncidentLiveMap({
    super.key,
    required this.incidentId,
    this.showSimpleRouteLine = true,
    this.alwaysShowResponder = true,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ CHANGED: reports collection (shared with Jazone citizen app)
    final incRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(incidentId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: incRef.snapshots(),
      builder: (context, incSnap) {
        if (!incSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final inc = incSnap.data!.data() ?? <String, dynamic>{};

        // ✅ Support both:
        // - legacy: latitude/longitude fields
        // - new: location: [lat, lng]
        final incLat = _readLat(inc);
        final incLng = _readLng(inc);

        // If no coordinates, show placeholder
        if (incLat == null || incLng == null) {
          return _emptyState(
            'No location found',
            'This report has no latitude/longitude yet.',
          );
        }

        final incidentPoint = LatLng(incLat, incLng);

        // Responder fields stored on report doc
        final responderId = (inc['assignedResponderId'] ?? '')
            .toString()
            .trim();

        if (responderId.isEmpty) {
          // Only incident marker
          return _mapOnlyIncident(context, incidentPoint);
        }

        // ✅ Optional: if your responder app writes live location directly to report doc
        LatLng? responderPointFromReport;
        final repLive = inc['responderLiveLocation'];
        if (repLive is GeoPoint) {
          responderPointFromReport = LatLng(
            repLive.latitude,
            repLive.longitude,
          );
        }

        // Pull responder profile / live location (current setup)
        final responderRef = FirebaseFirestore.instance
            .collection('users')
            .doc(responderId);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: responderRef.snapshots(),
          builder: (context, rSnap) {
            if (!rSnap.hasData) {
              // If no user doc yet, still show incident (and maybe report live loc if available)
              if (responderPointFromReport != null) {
                return _mapIncidentAndResponder(
                  incidentPoint: incidentPoint,
                  responderPoint: responderPointFromReport,
                  locationEnabled: true,
                );
              }
              return _mapOnlyIncident(context, incidentPoint);
            }

            final r = rSnap.data!.data() ?? <String, dynamic>{};
            final locationEnabled = r['locationEnabled'] == true;

            // You can store responder current location as:
            // currentLocation: GeoPoint(lat, lng)
            final GeoPoint? gp = (r['currentLocation'] is GeoPoint)
                ? (r['currentLocation'] as GeoPoint)
                : null;

            // Prefer report live location if present, else user currentLocation
            LatLng? responderPoint = responderPointFromReport;
            if (responderPoint == null && gp != null) {
              responderPoint = LatLng(gp.latitude, gp.longitude);
            }

            // If location is off or no location data, show only incident marker
            if (!alwaysShowResponder && !locationEnabled) {
              return _mapOnlyIncident(context, incidentPoint);
            }

            final markers = <Marker>[_incidentMarker(incidentPoint)];
            final polylines = <Polyline>[];

            if (responderPoint != null &&
                (alwaysShowResponder || locationEnabled)) {
              markers.add(_responderMarker(responderPoint));

              if (showSimpleRouteLine) {
                polylines.add(
                  Polyline(
                    points: [responderPoint, incidentPoint],
                    strokeWidth: 4,
                    color: Colors.lightBlueAccent,
                  ),
                );
              }
            }

            // Center map between both points if possible
            final center = responderPoint == null
                ? incidentPoint
                : LatLng(
                    (incidentPoint.latitude + responderPoint.latitude) / 2,
                    (incidentPoint.longitude + responderPoint.longitude) / 2,
                  );

            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: responderPoint == null ? 15 : 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    // OpenStreetMap tiles (no API key)
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jazone.monitoring',
                  ),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                  _MapLegend(
                    locationEnabled: locationEnabled,
                    hasResponderLocation: responderPoint != null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Used when responder location comes from report doc only (no user doc)
  Widget _mapIncidentAndResponder({
    required LatLng incidentPoint,
    required LatLng responderPoint,
    required bool locationEnabled,
  }) {
    final markers = <Marker>[
      _incidentMarker(incidentPoint),
      _responderMarker(responderPoint),
    ];

    final polylines = <Polyline>[];
    if (showSimpleRouteLine) {
      polylines.add(
        Polyline(
          points: [responderPoint, incidentPoint],
          strokeWidth: 4,
          color: Colors.lightBlueAccent,
        ),
      );
    }

    final center = LatLng(
      (incidentPoint.latitude + responderPoint.latitude) / 2,
      (incidentPoint.longitude + responderPoint.longitude) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jazone.monitoring',
          ),
          if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
          MarkerLayer(markers: markers),
          _MapLegend(
            locationEnabled: locationEnabled,
            hasResponderLocation: true,
          ),
        ],
      ),
    );
  }

  Widget _mapOnlyIncident(BuildContext context, LatLng incidentPoint) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: incidentPoint,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jazone.monitoring',
          ),
          MarkerLayer(markers: [_incidentMarker(incidentPoint)]),
          const _MapLegend(locationEnabled: false, hasResponderLocation: false),
        ],
      ),
    );
  }

  Marker _incidentMarker(LatLng p) {
    return Marker(
      point: p,
      width: 48,
      height: 48,
      child: _markerIcon(
        icon: Icons.warning_rounded,
        bg: Colors.redAccent,
        border: Colors.white.withOpacity(0.85),
      ),
    );
  }

  Marker _responderMarker(LatLng p) {
    return Marker(
      point: p,
      width: 48,
      height: 48,
      child: _markerIcon(
        icon: Icons.local_hospital,
        bg: Colors.greenAccent.shade700,
        border: Colors.white.withOpacity(0.85),
      ),
    );
  }

  Widget _markerIcon({
    required IconData icon,
    required Color bg,
    required Color border,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(14),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.white70, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ✅ Read from:
  // - latitude field
  // - else location array: [lat, lng]
  double? _readLat(Map<String, dynamic> inc) {
    final v = inc['latitude'];
    final d = _toDouble(v);
    if (d != null) return d;

    final loc = inc['location'];
    if (loc is List && loc.isNotEmpty && loc.first is num) {
      return (loc.first as num).toDouble();
    }
    return null;
  }

  double? _readLng(Map<String, dynamic> inc) {
    final v = inc['longitude'];
    final d = _toDouble(v);
    if (d != null) return d;

    final loc = inc['location'];
    if (loc is List && loc.length >= 2 && loc[1] is num) {
      return (loc[1] as num).toDouble();
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
}

class _MapLegend extends StatelessWidget {
  final bool locationEnabled;
  final bool hasResponderLocation;

  const _MapLegend({
    required this.locationEnabled,
    required this.hasResponderLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 10,
      bottom: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rowDot(color: Colors.redAccent, label: 'Incident'),
            const SizedBox(height: 6),
            _rowDot(color: Colors.greenAccent.shade700, label: 'Responder'),
            const SizedBox(height: 10),
            Text(
              'Responder Location: ${locationEnabled ? "ON" : "OFF"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              hasResponderLocation
                  ? 'Live coordinates received'
                  : 'No live coordinates yet',
              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowDot({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
        ),
      ],
    );
  }
}
