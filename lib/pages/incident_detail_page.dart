import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentDetailPage extends StatelessWidget {
  final String docId;
  const IncidentDetailPage({super.key, required this.docId});

  void update(String field, bool value) {
    FirebaseFirestore.instance.collection('incidents').doc(docId).update({
      'progress.$field': value,
      if (field == 'accepted') 'status': 'Accepted',
      if (field == 'onAction') 'status': 'Under Action',
      if (field == 'solved') 'status': 'Resolved',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incident Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .doc(docId)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final d = snap.data!.data() as Map<String, dynamic>;
          final p = d['progress'];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['address'], style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Accepted'),
                  value: p['accepted'],
                  onChanged: (v) => update('accepted', v!),
                ),
                CheckboxListTile(
                  title: const Text('On Action'),
                  value: p['onAction'],
                  onChanged: (v) => update('onAction', v!),
                ),
                CheckboxListTile(
                  title: const Text('Solved'),
                  value: p['solved'],
                  onChanged: (v) => update('solved', v!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
