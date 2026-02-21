import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponderService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get uid => _auth.currentUser!.uid;

  /// Stream incidents assigned to this responder
  Stream<QuerySnapshot<Map<String, dynamic>>> assignedIncidentsStream() {
    return _db
        .collection('incidents')
        .where('assignedResponderId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  /// Stream incidents for history (accepted or denied)
  Stream<QuerySnapshot<Map<String, dynamic>>> historyStream() {
    return _db
        .collection('incidents')
        .where('assignedResponderId', isEqualTo: uid)
        .where('responderDecision', whereIn: ['accepted', 'denied'])
        .orderBy('responderDecisionAt', descending: true)
        .snapshots();
  }

  Future<void> acceptIncident(String incidentId) async {
    final incidentRef = _db.collection('incidents').doc(incidentId);

    // Force dispatch state
    await incidentRef.set({
      'responderDecision': 'accepted',
      'responderDecisionAt': FieldValue.serverTimestamp(),
      'status': 'Responder Dispatched',
      'statusCode': 'responder_dispatched',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_dispatched',
      message: 'Responder accepted and dispatched',
      byRole: 'responder',
      byUid: uid,
    );

    // Optional: notify citizen (only if citizenId exists)
    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Responder dispatched',
      body: 'A responder is on the way.',
      type: 'status_update',
    );
  }

  Future<void> denyIncident(String incidentId, {String? reason}) async {
    final incidentRef = _db.collection('incidents').doc(incidentId);

    await incidentRef.set({
      'responderDecision': 'denied',
      'responderDeniedReason': (reason ?? '').trim(),
      'responderDecisionAt': FieldValue.serverTimestamp(),
      // keep status as accepted_by_admin or whatever admin set
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'responder_denied',
      message: (reason ?? '').trim().isEmpty
          ? 'Responder denied the assignment'
          : 'Responder denied: ${(reason ?? '').trim()}',
      byRole: 'responder',
      byUid: uid,
    );

    // Optional: notify citizen that assignment was denied (admin can reassign)
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
    final incidentRef = _db.collection('incidents').doc(incidentId);

    await incidentRef.set({
      'status': 'Resolved',
      'statusCode': 'problem_solved',
      'resolutionText': resolutionText.trim(),
      'solvedBy': 'responder',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _addTimeline(
      incidentId: incidentId,
      statusCode: 'problem_solved',
      message: 'Problem solved by responder',
      byRole: 'responder',
      byUid: uid,
    );

    await _notifyCitizenIfPossible(
      incidentId: incidentId,
      title: 'Problem solved',
      body: 'Resolution: ${resolutionText.trim()}',
      type: 'solved',
    );
  }

  Future<void> updateResponderLiveLocation({
    required String incidentId,
    required double lat,
    required double lng,
  }) async {
    await _db.collection('incidents').doc(incidentId).set({
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
      'lastLocationUpdate': FieldValue.serverTimestamp(),
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
    await _db
        .collection('incidents')
        .doc(incidentId)
        .collection('timeline')
        .add({
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
    final doc = await _db.collection('incidents').doc(incidentId).get();
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
