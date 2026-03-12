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
  String searchQuery = '';

  /// ✅ Reads first image from:
  /// - imageUrls: [ "https://..." ]
  /// - imageUrls: [ {url:"https://..."} ]
  /// - imageUrl: "https://..." (legacy)
  /// - imageUrl: { url: "https://..." } (legacy)
  String _readImageUrl(Map<String, dynamic> d) {
    final urls = d['imageUrls'];
    if (urls is List && urls.isNotEmpty) {
      final first = urls.first;
      if (first is String) return first.trim();
      if (first is Map) {
        final u = first['url'] ?? first['publicUrl'] ?? first['link'];
        if (u is String) return u.trim();
      }
    }

    final v = d['imageUrl'];
    if (v is String) return v.trim();
    if (v is Map) {
      final u = v['url'] ?? v['publicUrl'] ?? v['link'];
      if (u is String) return u.trim();
    }

    return '';
  }

  String _normalizeStatus(Map<String, dynamic> d) {
    final code = (d['statusCode'] ?? '').toString().toLowerCase().trim();
    if (code.isNotEmpty) return code;

    if (d['citizenSolved'] == true) return 'problem_solved';

    final adminDecision = (d['adminDecision'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    if (adminDecision == 'denied' || adminDecision == 'rejected') {
      return 'denied_by_admin';
    }

    if (adminDecision == 'accepted' || adminDecision == 'approved') {
      final assigned =
          (d['assignedResponderUid'] ?? d['assignedResponderId'] ?? '')
              .toString()
              .trim();
      if (assigned.isNotEmpty) return 'responder_dispatched';
      return 'accepted_by_admin';
    }

    final s = (d['status'] ?? '').toString().toLowerCase().trim();
    if (s == 'accepted') return 'accepted_by_admin';
    if (s == 'under action') return 'under_surveillance';
    if (s == 'resolved') return 'problem_solved';
    if (s == 'denied' || s == 'rejected') return 'denied_by_admin';
    if (s == 'reported') return 'pending_admin';
    if (s == 'okay') return 'pending_admin';

    return 'pending_admin';
  }

  String _statusDisplay(String codeOrLegacy) {
    switch (codeOrLegacy) {
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
        return 'Denied';
      default:
        return 'Pending';
    }
  }

  Timestamp? _readTimestamp(Map<String, dynamic> d) {
    if (d['updatedAt'] is Timestamp) return d['updatedAt'] as Timestamp;
    if (d['createdAt'] is Timestamp) return d['createdAt'] as Timestamp;
    if (d['timestamp'] is Timestamp) return d['timestamp'] as Timestamp;
    return null;
  }

  /// ✅ Urgency reader (supports both urgencyLevel and urgency)
  String _readUrgency(Map<String, dynamic> d) {
    final u = d['urgencyLevel'] ?? d['urgency'] ?? '';
    return u.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2435), Color(0xFF163A52), Color(0xFF0F2435)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1F3A),
          foregroundColor: Colors.white,
          title: const Text('Incidents / Reports'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search incident name, location...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => searchQuery = v.trim()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reports')
                    .orderBy('updatedAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data?.docs ?? [];
                  final q = searchQuery.toLowerCase();

                  final filtered = docs.where((doc) {
                    final d = doc.data();
                    final status = _normalizeStatus(d);
                    final incidentName = (d['incidentName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final locText = (d['locationText'] ?? '')
                        .toString()
                        .toLowerCase();

                    final matchesSearch =
                        searchQuery.isEmpty ||
                        incidentName.contains(q) ||
                        locText.contains(q);

                    final matchesFilter =
                        statusFilter == 'All' ||
                        _statusDisplay(status) == statusFilter;

                    return matchesSearch && matchesFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No reports found.',
                        style: TextStyle(color: Colors.white.withOpacity(0.8)),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final d = doc.data();

                      final incidentName = (d['incidentName'] ?? 'Untitled')
                          .toString();
                      final locationText =
                          (d['locationText'] ?? 'Unknown location').toString();

                      final img = _readImageUrl(d);
                      final statusCode = _normalizeStatus(d);
                      final statusText = _statusDisplay(statusCode);

                      final urgency = _readUrgency(d);

                      final ts = _readTimestamp(d);
                      final timeText = ts == null
                          ? ''
                          : '${ts.toDate().toLocal()}'.split('.').first;

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncidentDetailPage(docId: doc.id),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F3A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 64,
                                  width: 64,
                                  color: Colors.white.withOpacity(0.08),
                                  child: img.isEmpty
                                      ? Icon(
                                          Icons.image_not_supported,
                                          color: Colors.white.withOpacity(0.7),
                                        )
                                      : Image.network(
                                          img,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.broken_image,
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      incidentName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      locationText,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.75),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      // ✅ Removed "Has map", replaced with urgency
                                      '$statusText'
                                      '${urgency.isEmpty ? "" : " • Urgency: $urgency"}'
                                      '${timeText.isEmpty ? "" : " • $timeText"}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.65),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
