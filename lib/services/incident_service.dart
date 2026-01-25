import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentService {
  final _ref = FirebaseFirestore.instance.collection('incidents');

  Stream<QuerySnapshot> stream() => _ref.snapshots();

  Future<void> updateProgress(String id, Map<String, bool> progress) async {
    String status = 'Reported';

    if (progress['solved'] == true) {
      status = 'Resolved';
    } else if (progress['onAction'] == true) {
      status = 'Under Action';
    } else if (progress['accepted'] == true) {
      status = 'Accepted';
    }

    await _ref.doc(id).update({'progress': progress, 'status': status});
  }
}
