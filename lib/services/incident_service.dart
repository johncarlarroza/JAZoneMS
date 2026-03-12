import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentService {
  final _db = FirebaseFirestore.instance;

  /// ✅ reports collection (shared with Jazone citizen app)
  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  Stream<QuerySnapshot<Map<String, dynamic>>> stream() => _reports.snapshots();

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

    await _reports.doc(id).set({
      'progress': progress,
      'status': status,
      'statusCode': statusCode,

      // ✅ match report schema
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
  }

  Future<void> acceptIncident(String id) async {
    // ✅ keep existing progress map keys if any, but ensure accepted=true
    final doc = await _reports.doc(id).get();
    final data = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> oldProgress = (data['progress'] is Map)
        ? Map<String, dynamic>.from(data['progress'])
        : {};
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

  /// Admin can update these statuses:
  /// pending_admin, accepted_by_admin, reported_to_lgu, under_surveillance,
  /// responder_dispatched, problem_solved, denied_by_admin
  Future<void> setStatusCode(String id, String statusCode) async {
    final String statusLabel = _labelForStatusCode(statusCode);

    await _reports.doc(id).set({
      'statusCode': statusCode,
      'status': statusLabel,

      // ✅ keep reports schema in sync
      if (statusCode == 'accepted_by_admin') 'adminDecision': 'accepted',
      if (statusCode == 'denied_by_admin') 'adminDecision': 'denied',
      if (statusCode == 'problem_solved') 'citizenSolved': true,

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
    await _reports.doc(incidentId).set({
      'assignedResponderId': responderId,
      'assignedResponderName': responderName,
      'assignedResponderPhone': responderPhone,

      'responderDecision': 'pending',
      'responderDeniedReason': FieldValue.delete(),
      'assignedResponderStatus': 'on_dispatch',

      // ✅ AUTO UPDATE STATUS ON ASSIGN
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

    // Notify responder
    await _db
        .collection('users')
        .doc(responderId)
        .collection('notifications')
        .add({
          'title': 'New assignment',
          'body': 'You have been assigned to a new report.',
          'type': 'assignment',
          'reportId': incidentId,
          'incidentId': incidentId, // keep old key too
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

    // ✅ FIXED: your schema uses reporterId (but keep citizenId support too)
    final citizenId = (data['citizenId'] ?? data['reporterId'] ?? '')
        .toString()
        .trim();

    if (citizenId.isEmpty) return;

    await _db
        .collection('users')
        .doc(citizenId)
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
