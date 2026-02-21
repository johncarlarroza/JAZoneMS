import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/responder_service.dart';

class ResponderDispatchPage extends StatelessWidget {
  final String incidentId;
  const ResponderDispatchPage({super.key, required this.incidentId});

  Future<void> _solve(BuildContext context) async {
    final c = TextEditingController();
    final resolution = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Problem Solved'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter resolution provided (required)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (resolution == null) return;
    if (resolution.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resolution text is required.')),
      );
      return;
    }

    await ResponderService().markProblemSolved(
      incidentId: incidentId,
      resolutionText: resolution,
    );

    if (!context.mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('incidents')
        .doc(incidentId);

    return Scaffold(
      appBar: AppBar(title: const Text('On Dispatch')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final d = snap.data!.data() ?? <String, dynamic>{};
          final address = (d['address'] ?? '').toString();
          final urgency = (d['urgency'] ?? '').toString();
          final status = (d['status'] ?? '').toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('Urgency: $urgency')),
                    Chip(label: Text('Status: $status')),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Live tracking is running while this screen is open.',
                  style: TextStyle(color: Colors.black54),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _solve(context),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Problem Solved'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
