import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String address;
  final String urgency;
  final String status;
  final String description;
  final String imageUrl;
  final Timestamp timestamp;
  final double latitude;
  final double longitude;
  final Map<String, bool> progress;

  Incident.fromDoc(DocumentSnapshot doc)
    : id = doc.id,
      address = doc['address'],
      urgency = doc['urgency'],
      status = doc['status'],
      description = doc['description'],
      imageUrl = doc['imageUrl'],
      timestamp = doc['timestamp'],
      latitude = doc['latitude'],
      longitude = doc['longitude'],
      progress = Map<String, bool>.from(doc['progress']);
}
