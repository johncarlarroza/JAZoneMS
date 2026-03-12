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
  String dateFilter = 'All';

  final List<String> statusOptions = const [
    'All',
    'Pending',
    'Accepted',
    'Under Surveillance',
    'Responder Dispatched',
    'Reported to LGU',
    'Resolved',
    'Denied',
  ];

  final List<String> dateOptions = const [
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

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
    if (s == 'reported to lgu') return 'reported_to_lgu';
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

  String _readUrgency(Map<String, dynamic> d) {
    final u = d['urgencyLevel'] ?? d['urgency'] ?? '';
    return u.toString().trim();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Denied':
        return const Color(0xFFFF3131);
      case 'Resolved':
        return const Color(0xFF16C76B);
      case 'Accepted':
        return const Color(0xFF4A90E2);
      case 'Under Surveillance':
        return const Color(0xFF2816D8);
      case 'Responder Dispatched':
        return const Color(0xFFF7B23B);
      case 'Reported to LGU':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  bool _matchesDate(Timestamp? ts) {
    if (dateFilter == 'All' || ts == null) return true;

    final reportDate = ts.toDate();
    final now = DateTime.now();

    if (dateFilter == 'Today') {
      return reportDate.year == now.year &&
          reportDate.month == now.month &&
          reportDate.day == now.day;
    }

    if (dateFilter == 'This Week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      final end = start.add(const Duration(days: 7));
      return reportDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          reportDate.isBefore(end);
    }

    if (dateFilter == 'This Month') {
      return reportDate.year == now.year && reportDate.month == now.month;
    }

    return true;
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final month = _monthName(dt.month);
    return '$month ${dt.day}, ${dt.year} • $hour:$minute $ampm';
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3355),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            children: [
              _buildTopControls(),
              const SizedBox(height: 18),
              Expanded(child: _buildIncidentList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.trim()),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.black),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildDropdownBox(
          value: dateFilter,
          items: dateOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => dateFilter = value);
            }
          },
        ),
        const SizedBox(width: 12),
        _buildDropdownBox(
          value: statusFilter,
          items: statusOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => statusFilter = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdownBox({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      width: 150,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.black,
          ),
          dropdownColor: Colors.white,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIncidentList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              'Error loading reports.',
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        final q = searchQuery.toLowerCase();

        final filtered = docs.where((doc) {
          final d = doc.data();
          final statusCode = _normalizeStatus(d);
          final statusText = _statusDisplay(statusCode);
          final incidentName = (d['incidentName'] ?? '')
              .toString()
              .toLowerCase();
          final locationText = (d['locationText'] ?? '')
              .toString()
              .toLowerCase();
          final urgency = _readUrgency(d).toLowerCase();
          final ts = _readTimestamp(d);

          final matchesSearch =
              searchQuery.isEmpty ||
              incidentName.contains(q) ||
              locationText.contains(q) ||
              urgency.contains(q) ||
              statusText.toLowerCase().contains(q);

          final matchesStatus =
              statusFilter == 'All' || statusText == statusFilter;

          final matchesDate = _matchesDate(ts);

          return matchesSearch && matchesStatus && matchesDate;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No reports found.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final d = doc.data();

            final incidentName = (d['incidentName'] ?? 'Untitled Incident')
                .toString();
            final locationText = (d['locationText'] ?? 'Unknown location')
                .toString();
            final imageUrl = _readImageUrl(d);
            final statusText = _statusDisplay(_normalizeStatus(d));
            final urgency = _readUrgency(d);
            final ts = _readTimestamp(d);

            return InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailPage(docId: doc.id),
                  ),
                );
              },
              child: Container(
                height: 100,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF356B74),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    if (imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          imageUrl,
                          width: 66,
                          height: 66,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 66,
                            height: 66,
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            incidentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.90),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (urgency.isNotEmpty) 'Urgency: $urgency',
                              if (ts != null) _formatDateTime(ts.toDate()),
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      constraints: const BoxConstraints(minWidth: 118),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(statusText),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
