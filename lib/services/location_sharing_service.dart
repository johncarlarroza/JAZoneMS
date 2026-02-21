import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'responder_service.dart';

class LocationSharingService {
  final ResponderService _responderService;

  LocationSharingService(this._responderService);

  StreamSubscription<Position>? _sub;

  Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> startIdleAvailabilityUpdates() async {
    final ok = await ensurePermission();
    if (!ok) return;

    await _sub?.cancel();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 25, // reduces spam writes
          ),
        ).listen((pos) async {
          await _responderService.setAvailability(
            locationEnabled: true,
            availabilityStatus: 'available',
            currentLocation: GeoPoint(pos.latitude, pos.longitude),
          );
        });
  }

  Future<void> startDispatchTracking({required String incidentId}) async {
    final ok = await ensurePermission();
    if (!ok) return;

    await _sub?.cancel();
    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen((pos) async {
          // update user location for admin availability as well
          await _responderService.setAvailability(
            locationEnabled: true,
            availabilityStatus: 'on_dispatch',
            currentLocation: GeoPoint(pos.latitude, pos.longitude),
          );

          // update incident live location for citizen/admin tracking
          await _responderService.updateResponderLiveLocation(
            incidentId: incidentId,
            lat: pos.latitude,
            lng: pos.longitude,
          );
        });
  }

  Future<void> stopAllLocation() async {
    await _sub?.cancel();
    _sub = null;

    await _responderService.setAvailability(
      locationEnabled: false,
      availabilityStatus: 'unavailable',
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
