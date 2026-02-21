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
  String searchQuery = '';
  bool flash = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (mounted) setState(() => flash = !flash);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _normalizeStatus(Map<String, dynamic> d) {
    final code = (d['statusCode'] ?? '').toString().toLowerCase().trim();
    if (code.isNotEmpty) return code;

    // Backward compatible with legacy "status"
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
    // Turn normalized code into nice label
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2435), Color(0xFF163A52), Color(0xFF2D5F7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _topBar(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('incidents')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // Filter by status
                if (statusFilter != 'All') {
                  docs = docs.where((doc) {
                    final d = doc.data();
                    final normalized = _normalizeStatus(d);
                    final label = _statusDisplay(normalized).toLowerCase();
                    return label == statusFilter.toLowerCase();
                  }).toList();
                }

                // Search filter
                final q = searchQuery.trim().toLowerCase();
                if (q.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data();
                    final address = (d['address'] ?? '')
                        .toString()
                        .toLowerCase();
                    final desc = (d['description'] ?? '')
                        .toString()
                        .toLowerCase();
                    final urg = (d['urgency'] ?? '').toString().toLowerCase();
                    final st = _statusDisplay(
                      _normalizeStatus(d),
                    ).toLowerCase();
                    return address.contains(q) ||
                        desc.contains(q) ||
                        urg.contains(q) ||
                        st.contains(q);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No incidents found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _incidentCard(context, docs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Web-style top bar
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Incidents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _pill('Realtime', icon: Icons.circle, iconSize: 10),
            ],
          ),
          const SizedBox(height: 12),

          // Search + filter row
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search address, description, status, urgency...',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: DropdownButton<String>(
                  value: statusFilter,
                  dropdownColor: const Color(0xFF2D5F7B),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  underline: const SizedBox(),
                  iconEnabledColor: Colors.white,
                  items:
                      const [
                            'All',
                            'Pending',
                            'Accepted',
                            'Under Surveillance',
                            'Responder Dispatched',
                            'Resolved',
                            'Denied',
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => statusFilter = v ?? 'All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Aesthetic incident card
  Widget _incidentCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    final address = (d['address'] ?? 'Unknown location').toString();
    final description = (d['description'] ?? '—').toString();
    final urgency = (d['urgency'] ?? 'Normal').toString();

    final statusNorm = _normalizeStatus(d);
    final statusLabel = _statusDisplay(statusNorm);

    final Timestamp? ts = d['timestamp'] is Timestamp
        ? d['timestamp'] as Timestamp
        : null;
    final elapsed = ts == null ? null : DateTime.now().difference(ts.toDate());

    final isUrgent = urgency.toLowerCase() == 'urgent';

    final imageUrl = (d['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.trim().isNotEmpty;

    // SLA color
    final slaColor = elapsed == null
        ? Colors.white54
        : (elapsed.inHours >= 2 ? Colors.redAccent : Colors.greenAccent);

    return _glassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailPage(docId: doc.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withOpacity(0.15),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),
              ),

              const SizedBox(width: 14),

              // Text area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row (address + urgent badge)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isUrgent)
                          AnimatedOpacity(
                            opacity: flash ? 1 : 0.35,
                            duration: const Duration(milliseconds: 420),
                            child: _badge(
                              text: 'URGENT',
                              bg: Colors.redAccent.withOpacity(0.85),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _badge(
                          text: 'Status: $statusLabel',
                          bg: Colors.white.withOpacity(0.10),
                        ),
                        _badge(
                          text: 'Urgency: $urgency',
                          bg: Colors.white.withOpacity(0.10),
                        ),
                        _badge(
                          text: elapsed == null
                              ? 'SLA: —'
                              : 'SLA: ${elapsed.inHours}h ${elapsed.inMinutes % 60}m',
                          bg: slaColor.withOpacity(0.18),
                          border: slaColor.withOpacity(0.35),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Actions (no Google Maps)
              Column(
                children: [
                  IconButton(
                    tooltip: 'Location details',
                    icon: const Icon(
                      Icons.my_location,
                      color: Colors.lightBlueAccent,
                    ),
                    onPressed: () => _showGeoPreview(context, d),
                  ),
                  const SizedBox(height: 2),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Center(
      child: Icon(Icons.image, color: Colors.white.withOpacity(0.55), size: 26),
    );
  }

  // ✅ Geolocation preview (no map API)
  void _showGeoPreview(BuildContext context, Map<String, dynamic> d) {
    final lat = d['latitude'];
    final lng = d['longitude'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF163A52),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incident Location (Geolocation)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _geoRow('Latitude', lat?.toString() ?? '—'),
              const SizedBox(height: 8),
              _geoRow('Longitude', lng?.toString() ?? '—'),
              const SizedBox(height: 14),
              const Text(
                'Map preview is disabled (no Google Maps API key).',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _geoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // UI helpers
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _badge({
    required String text,
    required Color bg,
    Color? border,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _pill(String text, {required IconData icon, double iconSize = 16}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
