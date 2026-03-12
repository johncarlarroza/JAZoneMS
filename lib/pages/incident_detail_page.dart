import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/widgets/icident_live_map.dart';

import '../services/incident_service.dart';

// ✅ OpenStreetMap (no API key)
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

class IncidentDetailPage extends StatefulWidget {
  final String docId;
  const IncidentDetailPage({super.key, required this.docId});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  final IncidentService _service = IncidentService();

  String? _selectedResponderId;
  String? _selectedResponderName;
  String? _selectedResponderPhone;

  String? _selectedStatusCode;

  /// ✅ FIX: Supports both schemas:
  /// - imageUrls: ["https://..."] OR [{url:"https://..."}]
  /// - imageUrl: "https://..." OR {url:"https://..."}
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

    final other = d['photoUrl'] ?? d['photo'] ?? d['image'];
    if (other is String) return other.trim();

    return '';
  }

  GeoPoint? _readGeoPoint(Map<String, dynamic> d) {
    final loc = d['location'];
    if (loc is GeoPoint) return loc;
    return null;
  }

  Future<void> _denyWithComment(BuildContext context) async {
    final controller = TextEditingController();
    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deny Report'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional comment (reason for denial)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (res == null) return;

    await _service.denyIncident(widget.docId, comment: res);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incident denied')));
  }

  Future<void> _markAsSolved(
    BuildContext context, {
    String? defaultSolvedBy,
  }) async {
    final controller = TextEditingController();
    final solvedByController = TextEditingController(
      text: (defaultSolvedBy ?? '').trim().isEmpty ? '' : defaultSolvedBy!,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Solved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resolution details',
                hintText: 'Describe what was done / fixed...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: solvedByController,
              decoration: const InputDecoration(
                labelText: 'Solved by',
                hintText: 'Responder name / team',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok != true) return;

    final resolution = controller.text.trim();
    if (resolution.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a resolution.')),
      );
      return;
    }

    final solvedBy = solvedByController.text.trim();

    try {
      final doc = FirebaseFirestore.instance
          .collection('reports')
          .doc(widget.docId);

      await doc.set({
        'resolutionText': resolution,
        'solvedBy': solvedBy,
        'solvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _service.setStatusCode(widget.docId, 'problem_solved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to mark as solved: $e')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Incident marked as solved')));
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: your app uses "reports" collection (not "incidents")
    final incRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.docId);

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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: incRef.snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final d = snap.data!.data() ?? <String, dynamic>{};

            final status = (d['status'] ?? 'Reported').toString();
            final statusCode = (d['statusCode'] ?? '').toString();

            final adminComment = d['adminComment']?.toString();
            final responderDecision = d['responderDecision']?.toString();
            final responderDeniedReason = d['responderDeniedReason']
                ?.toString();

            final assignedResponderName = d['assignedResponderName']
                ?.toString();
            final assignedResponderPhone = d['assignedResponderPhone']
                ?.toString();

            final resolutionText = d['resolutionText']?.toString();
            final solvedBy = d['solvedBy']?.toString();

            // keep dropdown in sync
            _selectedStatusCode ??= statusCode.isNotEmpty
                ? statusCode
                : 'pending_admin';

            final bool isSolved =
                (_selectedStatusCode == 'problem_solved') ||
                (statusCode == 'problem_solved');

            // ✅ Image URL fix
            final imageUrl = _readImageUrl(d);

            // ✅ Location (GeoPoint fix)
            final geo = _readGeoPoint(d);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ Image (Supabase URL)
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          alignment: Alignment.center,
                          color: Colors.black.withOpacity(0.2),
                          child: const Text(
                            'Image failed to load',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  if (imageUrl.isNotEmpty) const SizedBox(height: 16),

                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (d['address'] ??
                                  d['locationText'] ??
                                  'Unknown location')
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (d['description'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _chip('Status: $status'),
                            _chip(
                              'Urgency: ${(d['urgency'] ?? d['urgencyLevel'] ?? '').toString()}',
                            ),
                          ],
                        ),

                        if (adminComment != null &&
                            adminComment.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow('Admin Comment', adminComment),
                        ],

                        if (assignedResponderName != null &&
                            assignedResponderName.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow('Assigned Responder', assignedResponderName),
                          if (assignedResponderPhone != null &&
                              assignedResponderPhone.isNotEmpty)
                            _infoRow('Responder Phone', assignedResponderPhone),
                        ],

                        if (responderDecision != null &&
                            responderDecision.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow('Responder Decision', responderDecision),
                          if (responderDecision == 'denied' &&
                              responderDeniedReason != null &&
                              responderDeniedReason.trim().isNotEmpty)
                            _infoRow('Denied Reason', responderDeniedReason),
                        ],

                        if (resolutionText != null &&
                            resolutionText.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _infoRow('Resolution', resolutionText),
                          if (solvedBy != null && solvedBy.isNotEmpty)
                            _infoRow('Solved By', solvedBy),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ✅ NEW: OpenStreetMap (no API key) - shows if GeoPoint exists
                  if (geo != null) ...[
                    _glassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OpenStreetMap',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 260,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: ll.LatLng(
                                    geo.latitude,
                                    geo.longitude,
                                  ),
                                  initialZoom: 16,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.example.jazone_admin',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: ll.LatLng(
                                          geo.latitude,
                                          geo.longitude,
                                        ),
                                        width: 44,
                                        height: 44,
                                        child: const Icon(
                                          Icons.location_pin,
                                          size: 44,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${geo.latitude.toStringAsFixed(6)} • Lng: ${geo.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ✅ Admin actions (UNCHANGED)
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Actions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // SizedBox(
                        //   height: 320,
                        //   width: double.infinity,
                        //   child: IncidentLiveMap(
                        //     incidentId: widget.docId,
                        //     showSimpleRouteLine: true,
                        //     alwaysShowResponder: true,
                        //   ),
                        // ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade400,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: isSolved
                                    ? null
                                    : () async {
                                        await _service.acceptIncident(
                                          widget.docId,
                                        );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Incident accepted'),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.shade200,
                                  foregroundColor: Colors.black,
                                ),
                                onPressed: isSolved
                                    ? null
                                    : () => _denyWithComment(context),
                                icon: const Icon(Icons.cancel),
                                label: const Text('Deny'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightGreenAccent.shade100,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _markAsSolved(
                              context,
                              defaultSolvedBy: assignedResponderName,
                            ),
                            icon: const Icon(Icons.verified),
                            label: const Text('Mark as Solved'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _dropdownLabel('Update Status'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedStatusCode,
                          decoration: _dropDeco(),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending_admin',
                              child: Text('Reported (Pending Admin)'),
                            ),
                            DropdownMenuItem(
                              value: 'accepted_by_admin',
                              child: Text('Accepted by Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'reported_to_lgu',
                              child: Text('Reported to LGU'),
                            ),
                            DropdownMenuItem(
                              value: 'under_surveillance',
                              child: Text('Under Surveillance'),
                            ),
                            DropdownMenuItem(
                              value: 'responder_dispatched',
                              child: Text('Responder Dispatched'),
                            ),
                            DropdownMenuItem(
                              value: 'problem_solved',
                              child: Text('Problem Solved'),
                            ),
                            DropdownMenuItem(
                              value: 'denied_by_admin',
                              child: Text('Denied by Admin'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedStatusCode = v),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final code =
                                  _selectedStatusCode ?? 'pending_admin';
                              await _service.setStatusCode(widget.docId, code);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Status updated')),
                              );
                            },
                            child: const Text('Apply Status'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _dropdownLabel('Assign Available Responder'),
                        const SizedBox(height: 6),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _service.availableResponders(),
                          builder: (context, rsSnap) {
                            if (!rsSnap.hasData) {
                              return const Text(
                                'Loading responders...',
                                style: TextStyle(color: Colors.white70),
                              );
                            }

                            final docs = rsSnap.data!.docs;

                            final incidentLat = (d['latitude'] is num)
                                ? (d['latitude'] as num).toDouble()
                                : 0.0;
                            final incidentLng = (d['longitude'] is num)
                                ? (d['longitude'] as num).toDouble()
                                : 0.0;

                            final items = docs.map((doc) {
                              final u = doc.data();
                              final name = (u['name'] ?? 'Responder')
                                  .toString();
                              final phone = (u['phone'] ?? '').toString();

                              double? meters;
                              final loc = u['currentLocation'];
                              if (loc is GeoPoint &&
                                  (incidentLat != 0 || incidentLng != 0)) {
                                meters = IncidentService.distanceMeters(
                                  lat1: incidentLat,
                                  lon1: incidentLng,
                                  lat2: loc.latitude,
                                  lon2: loc.longitude,
                                );
                              }

                              return {
                                'id': doc.id,
                                'name': name,
                                'phone': phone,
                                'meters': meters,
                              };
                            }).toList();

                            items.sort((a, b) {
                              final am = a['meters'];
                              final bm = b['meters'];
                              if (am == null && bm == null) return 0;
                              if (am == null) return 1;
                              if (bm == null) return -1;
                              return (am as double).compareTo(bm as double);
                            });

                            return Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: _selectedResponderId,
                                  decoration: _dropDeco(),
                                  items: items.map((r) {
                                    final label = (r['meters'] == null)
                                        ? '${r['name']} (${r['phone']})'
                                        : '${r['name']} (${r['phone']}) • ${(r['meters'] as double).toStringAsFixed(0)}m';
                                    return DropdownMenuItem(
                                      value: r['id'] as String,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _selectedResponderId = v;
                                      final picked = items.firstWhere(
                                        (e) => e['id'] == v,
                                        orElse: () => {},
                                      );
                                      _selectedResponderName = picked['name']
                                          ?.toString();
                                      _selectedResponderPhone = picked['phone']
                                          ?.toString();
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (_selectedResponderId == null ||
                                            isSolved)
                                        ? null
                                        : () async {
                                            await _service.assignResponder(
                                              incidentId: widget.docId,
                                              responderId:
                                                  _selectedResponderId!,
                                              responderName:
                                                  _selectedResponderName ??
                                                  'Responder',
                                              responderPhone:
                                                  _selectedResponderPhone ?? '',
                                            );

                                            await _service.setStatusCode(
                                              widget.docId,
                                              'responder_dispatched',
                                            );

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Responder assigned (status updated)',
                                                ),
                                              ),
                                            );
                                          },
                                    icon: const Icon(Icons.send),
                                    label: const Text('Assign Responder'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Timeline (UNCHANGED)
                  _glassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timeline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: incRef
                              .collection('timeline')
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, tSnap) {
                            if (!tSnap.hasData) {
                              return const Text(
                                'Loading timeline...',
                                style: TextStyle(color: Colors.white70),
                              );
                            }

                            final docs = tSnap.data!.docs;
                            if (docs.isEmpty) {
                              return const Text(
                                'No timeline entries yet.',
                                style: TextStyle(color: Colors.white70),
                              );
                            }

                            return Column(
                              children: docs.take(12).map((doc) {
                                final td = doc.data();
                                final msg = (td['message'] ?? '').toString();
                                final code = (td['statusCode'] ?? '')
                                    .toString();
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    msg,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    code,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _dropDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: child,
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _dropdownLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
