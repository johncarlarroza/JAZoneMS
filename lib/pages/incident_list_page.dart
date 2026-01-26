import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'incident_detail_page.dart';

class IncidentListPage extends StatefulWidget {
  const IncidentListPage({super.key});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  String statusFilter = 'All';
  bool flash = true;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted) setState(() => flash = !flash);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A3A52), Color(0xFF2D5F7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _topBar(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                if (statusFilter != 'All') {
                  docs = docs
                      .where((d) => (d.data() as Map)['status'] == statusFilter)
                      .toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _incidentTile(doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 TOP BAR WITH FILTER
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Incidents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          DropdownButton<String>(
            value: statusFilter,
            dropdownColor: const Color(0xFF2D5F7B),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: [
              'All',
              'okay',
              'Accepted',
              'Under Action',
              'Resolved',
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => statusFilter = v!),
          ),
        ],
      ),
    );
  }

  // 🔹 INCIDENT TILE
  Widget _incidentTile(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final urgency = d['urgency'] ?? 'Normal';
    final timestamp = d['timestamp'] as Timestamp;
    final elapsed = DateTime.now().difference(timestamp.toDate());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),

        // 🖼 IMAGE (LEFT, FIXED)
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            d['imageUrl'],
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          ),
        ),

        title: Row(
          children: [
            Expanded(
              child: Text(
                d['address'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            // 🔥 URGENT BADGE
            if (urgency == 'Urgent')
              AnimatedOpacity(
                opacity: flash ? 1 : 0.3,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              d['description'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // ⏱ SLA TIMER
            Text(
              'SLA: ${elapsed.inHours}h ${elapsed.inMinutes % 60}m',
              style: TextStyle(
                color: elapsed.inHours >= 2 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        trailing: IconButton(
          icon: const Icon(Icons.map),
          onPressed: () => _showMap(d),
        ),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailPage(docId: doc.id),
            ),
          );
        },
      ),
    );
  }

  // 📍 MAP PREVIEW DRAWER
  void _showMap(Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incident Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Latitude: ${d['latitude']}'),
              Text('Longitude: ${d['longitude']}'),
              const SizedBox(height: 12),
              const Text(
                'Map preview ready for Google Maps integration',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}
