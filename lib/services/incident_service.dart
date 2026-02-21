import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _incidents =>
      _db.collection('incidents');

  Stream<QuerySnapshot<Map<String, dynamic>>> stream() =>
      _incidents.snapshots();

  /// Backward compatible progress update (your existing feature)
  Future<void> updateProgress(String id, Map<String, bool> progress) async {
    String status = 'Reported';
    String statusCode = 'pending_admin';

    if (progress['solved'] == true) {
      status = 'Resolved';
      statusCode = 'problem_solved';
    } else if (progress['onAction'] == true) {
      status = 'Under Action';
      statusCode = 'under_surveillance';
    } else if (progress['accepted'] == true) {
      status = 'Accepted';
      statusCode = 'accepted_by_admin';
    }

    await _incidents.doc(id).set({
      'progress': progress,
      'status': status,
      'statusCode': statusCode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: statusCode,
      message: 'Status updated: $status',
      byRole: 'admin',
    );
  }

  Future<void> acceptIncident(String id) async {
    await _incidents.doc(id).set({
      'status': 'Accepted',
      'statusCode': 'accepted_by_admin',
      'progress.accepted': true,
      'adminComment': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: 'accepted_by_admin',
      message: 'Accepted by Admin',
      byRole: 'admin',
    );

    await _notifyCitizenIfPossible(
      incidentId: id,
      title: 'Report accepted',
      body: 'Your report was accepted by the Admin.',
      type: 'status_update',
    );
  }

  Future<void> denyIncident(String id, {String? comment}) async {
    await _incidents.doc(id).set({
      'status': 'Rejected',
      'statusCode': 'denied_by_admin',
      'adminComment': (comment ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: 'denied_by_admin',
      message:
          'Denied by Admin${(comment ?? '').trim().isNotEmpty ? ': ${comment!.trim()}' : ''}',
      byRole: 'admin',
    );

    await _notifyCitizenIfPossible(
      incidentId: id,
      title: 'Report denied',
      body: (comment ?? '').trim().isEmpty
          ? 'Your report was denied by the Admin.'
          : 'Denied: ${comment!.trim()}',
      type: 'denial',
    );
  }

  /// Admin can update these statuses:
  /// reported_to_lgu, under_surveillance, responder_dispatched, problem_solved
  Future<void> setStatusCode(String id, String statusCode) async {
    final String statusLabel = _labelForStatusCode(statusCode);

    await _incidents.doc(id).set({
      'statusCode': statusCode,
      'status': statusLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: statusCode,
      message: 'Status updated: $statusLabel',
      byRole: 'admin',
    );

    await _notifyCitizenIfPossible(
      incidentId: id,
      title: 'Status update',
      body: 'Update: $statusLabel',
      type: 'status_update',
    );
  }

  Future<void> assignResponder({
    required String incidentId,
    required String responderId,
    required String responderName,
    required String responderPhone,
  }) async {
    await _incidents.doc(incidentId).set({
      'assignedResponderId': responderId,
      'assignedResponderName': responderName,
      'assignedResponderPhone': responderPhone,
      'responderDecision': 'pending',
      'responderDeniedReason': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_assigned',
      message: 'Responder assigned: $responderName',
      byRole: 'admin',
    );

    // Notify responder
    await _db
        .collection('users')
        .doc(responderId)
        .collection('notifications')
        .add({
          'title': 'New assignment',
          'body': 'You have been assigned to a new incident.',
          'type': 'assignment',
          'incidentId': incidentId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> addTimeline({
    required String incidentId,
    required String statusCode,
    required String message,
    required String byRole,
    String? byUid,
  }) async {
    await _incidents.doc(incidentId).collection('timeline').add({
      'statusCode': statusCode,
      'message': message,
      'byRole': byRole,
      'byUid': byUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _labelForStatusCode(String code) {
    switch (code) {
      case 'pending_admin':
        return 'Reported';
      case 'accepted_by_admin':
        return 'Accepted';
      case 'reported_to_lgu':
        return 'Reported to LGU';
      case 'under_surveillance':
        return 'Under Surveillance';
      case 'responder_dispatched':
        return 'Responder Dispatched';
      case 'problem_solved':
        return 'Resolved';
      case 'denied_by_admin':
        return 'Rejected';
      default:
        return 'Reported';
    }
  }

  /// Get available responders (role=responder, locationEnabled=true, availabilityStatus=available)
  Stream<QuerySnapshot<Map<String, dynamic>>> availableResponders() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .where('locationEnabled', isEqualTo: true)
        .where('availabilityStatus', isEqualTo: 'available')
        .snapshots();
  }

  /// Optional helper: distance in meters (for sorting responders near incident)
  static double distanceMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  Future<void> _notifyCitizenIfPossible({
    required String incidentId,
    required String title,
    required String body,
    required String type,
  }) async {
    final doc = await _incidents.doc(incidentId).get();
    final data = doc.data() ?? <String, dynamic>{};
    final citizenId = data['citizenId']?.toString();

    if (citizenId == null || citizenId.trim().isEmpty) return;

    await _db
        .collection('users')
        .doc(citizenId)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': type,
          'incidentId': incidentId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
