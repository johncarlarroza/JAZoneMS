import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Shared collection used by Citizen App + Responder App + Admin Dashboard
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  Stream<QuerySnapshot<Map<String, dynamic>>> stream() => _reports.snapshots();

  /// Backward-compatible progress update
  Future<void> updateProgress(String id, Map<String, bool> progress) async {
    String status = 'Reported';
    String statusCode = 'pending_admin';

    if (progress['solved'] == true) {
      status = 'Resolved';
      statusCode = 'problem_solved';
    } else if (progress['onAction'] == true) {
      status = 'Under Surveillance';
      statusCode = 'under_surveillance';
    } else if (progress['accepted'] == true) {
      status = 'Accepted';
      statusCode = 'accepted_by_admin';
    }

    await _reports.doc(id).set({
      'progress': progress,
      'status': status,
      'statusCode': statusCode,

      if (statusCode == 'accepted_by_admin') 'adminDecision': 'accepted',
      if (statusCode == 'denied_by_admin') 'adminDecision': 'denied',
      if (statusCode == 'problem_solved') 'citizenSolved': true,

      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: statusCode,
      message: 'Status updated: $status',
      byRole: 'admin',
    );

    await _notifyCitizenIfPossible(
      incidentId: id,
      title: 'Status update',
      body: 'Update: $status',
      type: 'status_update',
    );
  }

  Future<void> acceptIncident(String id) async {
    final doc = await _reports.doc(id).get();
    final data = doc.data() ?? <String, dynamic>{};

    final Map<String, dynamic> oldProgress = (data['progress'] is Map)
        ? Map<String, dynamic>.from(data['progress'])
        : <String, dynamic>{};

    oldProgress['accepted'] = true;

    await _reports.doc(id).set({
      'adminDecision': 'accepted',
      'status': 'Accepted',
      'statusCode': 'accepted_by_admin',
      'progress': oldProgress,
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
    final c = (comment ?? '').trim();

    await _reports.doc(id).set({
      'adminDecision': 'denied',
      'adminComment': c,
      'status': 'Rejected',
      'statusCode': 'denied_by_admin',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: id,
      statusCode: 'denied_by_admin',
      message: c.isNotEmpty ? 'Denied by Admin: $c' : 'Denied by Admin',
      byRole: 'admin',
    );

    await _notifyCitizenIfPossible(
      incidentId: id,
      title: 'Report denied',
      body: c.isEmpty ? 'Your report was denied by the Admin.' : 'Denied: $c',
      type: 'denial',
    );
  }

  /// Allowed status codes:
  /// pending_admin
  /// accepted_by_admin
  /// reported_to_lgu
  /// under_surveillance
  /// responder_dispatched
  /// problem_solved
  /// denied_by_admin
  Future<void> setStatusCode(String id, String statusCode) async {
    final String statusLabel = _labelForStatusCode(statusCode);

    final Map<String, dynamic> payload = {
      'statusCode': statusCode,
      'status': statusLabel,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (statusCode == 'accepted_by_admin') {
      payload['adminDecision'] = 'accepted';
    } else if (statusCode == 'denied_by_admin') {
      payload['adminDecision'] = 'denied';
    } else if (statusCode == 'problem_solved') {
      payload['citizenSolved'] = true;
      payload['responderSolved'] = true;
    }

    await _reports.doc(id).set(payload, SetOptions(merge: true));

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
    await _reports.doc(incidentId).set({
      // keep both keys for compatibility while you finish cleanup
      'assignedResponderUid': responderId,
      'assignedResponderId': responderId,

      'assignedResponderName': responderName,
      'assignedResponderPhone': responderPhone,

      'responderDecision': 'pending',
      'responderDeniedReason': FieldValue.delete(),
      'assignedResponderStatus': 'pending_response',

      'statusCode': 'responder_dispatched',
      'status': _labelForStatusCode('responder_dispatched'),

      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_dispatched',
      message: 'Responder assigned: $responderName',
      byRole: 'admin',
    );

    await _db
        .collection('users')
        .doc(responderId)
        .collection('notifications')
        .add({
          'title': 'New assignment',
          'body': 'You have been assigned to a new report.',
          'type': 'assignment',
          'reportId': incidentId,
          'incidentId': incidentId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Responder assigned',
      body: '$responderName has been assigned to your report.',
      type: 'assignment',
    );
  }

  Future<void> addTimeline({
    required String incidentId,
    required String statusCode,
    required String message,
    required String byRole,
    String? byUid,
  }) async {
    await _reports.doc(incidentId).collection('timeline').add({
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

  Stream<QuerySnapshot<Map<String, dynamic>>> availableResponders() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .where('locationEnabled', isEqualTo: true)
        .where('availabilityStatus', isEqualTo: 'available')
        .snapshots();
  }

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
    final doc = await _reports.doc(incidentId).get();
    final data = doc.data() ?? <String, dynamic>{};

    // your citizen app writes citizenUid
    final citizenUid = (data['citizenUid'] ?? '').toString().trim();
    if (citizenUid.isEmpty) return;

    await _db
        .collection('users')
        .doc(citizenUid)
        .collection('notifications')
        .add({
          'title': title,
          'body': body,
          'type': type,
          'reportId': incidentId,
          'incidentId': incidentId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
