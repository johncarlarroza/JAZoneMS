import 'package:cloud_firestore/cloud_firestore.dart';

class Incident {
  final String id;
  final String address;
  final String urgency;
  final String status; // human-readable
  final String statusCode; // machine-readable (new)
  final String description;
  final String imageUrl;
  final Timestamp? timestamp;
  final double latitude;
  final double longitude;
  final Map<String, bool> progress;

  // new fields (optional)
  final String? adminComment;
  final String? citizenId;
  final String? citizenName;
  final String? citizenPhone;

  final String? assignedResponderId;
  final String? assignedResponderName;
  final String? assignedResponderPhone;

  final String? responderDecision; // pending/accepted/denied
  final String? responderDeniedReason;
  final String? resolutionText;
  final String? solvedBy;

  Incident({
    required this.id,
    required this.address,
    required this.urgency,
    required this.status,
    required this.statusCode,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.progress,
    this.adminComment,
    this.citizenId,
    this.citizenName,
    this.citizenPhone,
    this.assignedResponderId,
    this.assignedResponderName,
    this.assignedResponderPhone,
    this.responderDecision,
    this.responderDeniedReason,
    this.resolutionText,
    this.solvedBy,
  });

  factory Incident.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};

    Map<String, bool> safeProgress = const {
      'accepted': false,
      'onAction': false,
      'solved': false,
    };

    final rawProgress = d['progress'];
    if (rawProgress is Map) {
      safeProgress = {
        'accepted': (rawProgress['accepted'] == true),
        'onAction': (rawProgress['onAction'] == true),
        'solved': (rawProgress['solved'] == true),
      };
    }

    String status = (d['status'] ?? 'Reported').toString();
    String statusCode = (d['statusCode'] ?? '').toString();

    // Backward compatible statusCode mapping (if missing)
    if (statusCode.isEmpty) {
      final s = status.toLowerCase();
      if (s == 'rejected' || s == 'denied') {
        statusCode = 'denied_by_admin';
      } else if (s == 'resolved' || s == 'solved') {
        statusCode = 'problem_solved';
      } else if (s == 'accepted') {
        statusCode = 'accepted_by_admin';
      } else if (s == 'under action') {
        statusCode = 'under_surveillance';
      } else {
        statusCode = 'pending_admin';
      }
    }

    double lat = 0, lng = 0;
    final rawLat = d['latitude'];
    final rawLng = d['longitude'];
    if (rawLat is num) lat = rawLat.toDouble();
    if (rawLng is num) lng = rawLng.toDouble();

    return Incident(
      id: doc.id,
      address: (d['address'] ?? '').toString(),
      urgency: (d['urgency'] ?? '').toString(),
      status: status,
      statusCode: statusCode,
      description: (d['description'] ?? '').toString(),
      imageUrl: (d['imageUrl'] ?? '').toString(),
      timestamp: d['timestamp'] is Timestamp
          ? d['timestamp'] as Timestamp
          : null,
      latitude: lat,
      longitude: lng,
      progress: safeProgress,
      adminComment: d['adminComment']?.toString(),
      citizenId: d['citizenId']?.toString(),
      citizenName: d['citizenName']?.toString(),
      citizenPhone: d['citizenPhone']?.toString(),
      assignedResponderId: d['assignedResponderId']?.toString(),
      assignedResponderName: d['assignedResponderName']?.toString(),
      assignedResponderPhone: d['assignedResponderPhone']?.toString(),
      responderDecision: d['responderDecision']?.toString(),
      responderDeniedReason: d['responderDeniedReason']?.toString(),
      resolutionText: d['resolutionText']?.toString(),
      solvedBy: d['solvedBy']?.toString(),
    );
  }
}
