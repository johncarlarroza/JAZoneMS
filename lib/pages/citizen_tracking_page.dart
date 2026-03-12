import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/widgets/icident_live_map.dart';

class CitizenTrackingPage extends StatelessWidget {
  final String incidentId;
  const CitizenTrackingPage({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('reports')
        .doc(incidentId);

    return Scaffold(
      appBar: AppBar(title: const Text('Responder Tracking')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data() ?? <String, dynamic>{};
          final statusCode = (d['statusCode'] ?? '').toString();

          final hasAssignedResponder =
              (d['assignedResponderId'] != null &&
              d['assignedResponderId'].toString().trim().isNotEmpty);

          if (statusCode != 'responder_dispatched' && !hasAssignedResponder) {
            return const Center(
              child: Text('Tracking will appear when responder is dispatched.'),
            );
          }

          final responderName = (d['assignedResponderName'] ?? '').toString();
          final responderPhone = (d['assignedResponderPhone'] ?? '').toString();

          final hasResponderLoc = d['responderLiveLocation'] is GeoPoint;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (responderName.isNotEmpty || responderPhone.isNotEmpty)
                  Card(
                    child: ListTile(
                      title: Text(
                        responderName.isEmpty ? 'Responder' : responderName,
                      ),
                      subtitle: Text(
                        responderPhone.isEmpty ? '' : responderPhone,
                      ),
                      trailing: const Icon(Icons.directions_run),
                    ),
                  ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 360,
                  width: double.infinity,
                  child: IncidentLiveMap(
                    incidentId: incidentId,
                    showSimpleRouteLine: true,
                    alwaysShowResponder: true,
                  ),
                ),

                const SizedBox(height: 12),
                if (!hasResponderLoc)
                  const Text(
                    'Responder location temporarily unavailable.',
                    style: TextStyle(color: Colors.redAccent),
                  )
                else
                  const Text(
                    'Responder is on the way. Stay alert.',
                    style: TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
