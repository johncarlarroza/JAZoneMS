import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:jazone_monitoring_dashboard/widgets/icident_live_map.dart';

class ResponderDispatchPage extends StatefulWidget {
  final String incidentId;
  const ResponderDispatchPage({super.key, required this.incidentId});

  @override
  State<ResponderDispatchPage> createState() => _ResponderDispatchPageState();
}

class _ResponderDispatchPageState extends State<ResponderDispatchPage> {
  StreamSubscription<Position>? _positionSub;
  bool _trackingStarted = false;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('reports').doc(widget.incidentId);

  @override
  void initState() {
    super.initState();
    _startLiveTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _startLiveTracking() async {
    if (_trackingStarted) return;
    _trackingStarted = true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSub =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (pos) async {
            await _ref.set({
              'responderLiveLocation': GeoPoint(pos.latitude, pos.longitude),
              'responderLastUpdatedAt': FieldValue.serverTimestamp(),
              'statusCode': 'responder_dispatched',
              'status': 'Responder Dispatched',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          },
        );
  }

  Future<void> _solve(BuildContext context) async {
    final c = TextEditingController();
    final resolution = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Problem Solved'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter resolution provided (required)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (resolution == null) return;
    if (resolution.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolution text is required.')),
      );
      return;
    }

    await _positionSub?.cancel();

    await _ref.set({
      'citizenSolved': true,
      'responderSolved': true,
      'resolutionText': resolution.trim(),
      'resolutionProvidedByResponder': resolution.trim(),
      'solvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'statusCode': 'problem_solved',
      'status': 'Resolved',
    }, SetOptions(merge: true));

    await _ref.collection('timeline').add({
      'message': 'Responder marked this report as solved.',
      'statusCode': 'problem_solved',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('On Dispatch')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data() ?? <String, dynamic>{};
          final address = (d['locationText'] ?? d['address'] ?? '').toString();
          final urgency = (d['urgencyLevel'] ?? d['urgency'] ?? '').toString();
          final status = (d['status'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address.isEmpty ? 'Incident' : address,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('Urgency: $urgency')),
                    Chip(label: Text('Status: $status')),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: IncidentLiveMap(
                    incidentId: widget.incidentId,
                    showSimpleRouteLine: true,
                    alwaysShowResponder: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Live tracking is running while you are on dispatch.',
                  style: TextStyle(color: Colors.black54),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _solve(context),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Problem Solved'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
