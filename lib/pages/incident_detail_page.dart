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
      appBar: AppBar(
        title: const Text('Incident Details'),
        backgroundColor: const Color(0xFF1A3A52),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A3A52), Color(0xFF2D5F7B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('incidents')
              .doc(docId)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final d = snap.data!.data() as Map<String, dynamic>;
            final p = d['progress'];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (d['imageUrl'] != null && d['imageUrl'] != '')
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        d['imageUrl'],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),

                  const SizedBox(height: 20),

                  Text(
                    d['address'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    d['description'] ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 24),

                  // Progress
                  _checkTile('Accepted', p['accepted'], 'accepted'),
                  _checkTile('On Action', p['onAction'], 'onAction'),
                  _checkTile('Solved', p['solved'], 'solved'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _checkTile(String title, bool value, String field) {
    return Card(
      child: CheckboxListTile(
        title: Text(title),
        value: value,
        onChanged: (v) => update(field, v!),
      ),
    );
  }
}
