import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  /// Stream reports assigned to this responder
  Stream<QuerySnapshot<Map<String, dynamic>>> assignedIncidentsStream() {
    return _reports
        .where('assignedResponderUid', isEqualTo: uid)
        .where('adminDecision', isEqualTo: 'accepted')
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Stream history for this responder
  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream() {
    return _reports
        .where('assignedResponderUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> acceptIncident(String incidentId) async {
    final reportRef = _reports.doc(incidentId);

    await reportRef.set({
      'responderDecision': 'accepted',
      'responderDecisionAt': FieldValue.serverTimestamp(),
      'statusCode': 'responder_dispatched',
      'status': 'Responder Dispatched',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_dispatched',
      message: 'Responder accepted and is now dispatched.',
      byRole: 'responder',
      byUid: uid,
    );

    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Responder dispatched',
      body: 'A responder is on the way.',
      type: 'status_update',
    );
  }

  Future<void> denyIncident(String incidentId, {String? reason}) async {
    final reportRef = _reports.doc(incidentId);
    final cleanReason = (reason ?? '').trim();

    await reportRef.set({
      'responderDecision': 'denied',
      'responderDeniedReason': cleanReason,
      'responderDecisionAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_denied',
      message: cleanReason.isEmpty
          ? 'Responder denied the assignment.'
          : 'Responder denied the assignment: $cleanReason',
      byRole: 'responder',
      byUid: uid,
    );

    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Responder unavailable',
      body: 'A responder denied the assignment. Admin will reassign.',
      type: 'assignment_denied',
    );
  }

  Future<void> markProblemSolved({
    required String incidentId,
    required String resolutionText,
  }) async {
    final reportRef = _reports.doc(incidentId);
    final cleanResolution = resolutionText.trim();

    await reportRef.set({
      'responderSolved': true,
      'citizenSolved': false,
      'resolutionText': cleanResolution,
      'resolutionProvidedByResponder': cleanResolution,
      'solvedBy': 'responder',
      'resolvedAt': FieldValue.serverTimestamp(),
      'statusCode': 'problem_solved',
      'status': 'Resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'problem_solved',
      message: 'Responder marked the report as solved.',
      byRole: 'responder',
      byUid: uid,
    );

    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Problem solved',
      body: 'Resolution: $cleanResolution',
      type: 'solved',
    );
  }

  Future<void> updateResponderLiveLocation({
    required String incidentId,
    required double lat,
    required double lng,
  }) async {
    await _reports.doc(incidentId).set({
      'responderLiveLocation': GeoPoint(lat, lng),
      'responderLocationUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setAvailability({
    required bool locationEnabled,
    required String availabilityStatus, // available/unavailable/on_dispatch
    GeoPoint? currentLocation,
  }) async {
    final userRef = _db.collection('users').doc(uid);

    final update = <String, dynamic>{
      'locationEnabled': locationEnabled,
      'availabilityStatus': availabilityStatus,
      'isOnline': locationEnabled,
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (currentLocation != null) {
      update['currentLocation'] = currentLocation;
    }

    await userRef.set(update, SetOptions(merge: true));
  }

  Future<void> _addTimeline({
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

  Future<void> _notifyCitizenIfPossible({
    required String incidentId,
    required String title,
    required String body,
    required String type,
  }) async {
    final doc = await _reports.doc(incidentId).get();
    final data = doc.data() ?? <String, dynamic>{};

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
          'incidentId': incidentId, // keep old key too for compatibility
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
