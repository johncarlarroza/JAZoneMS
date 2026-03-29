import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/incident_service.dart';

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

    final lat = d['latitude'];
    final lng = d['longitude'];
    if (lat is num && lng is num) {
      return GeoPoint(lat.toDouble(), lng.toDouble());
    }

    return null;
  }

  GeoPoint? _readResponderGeoPoint(Map<String, dynamic> d) {
    final loc = d['responderLiveLocation'];
    if (loc is GeoPoint) return loc;

    final responderLoc = d['responderLocation'];
    if (responderLoc is GeoPoint) return responderLoc;

    return null;
  }

  Future<void> _denyWithComment(BuildContext context) async {
    final controller = TextEditingController();

    final res = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Deny Report'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Optional reason for denial',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

    if (!mounted || res == null) return;

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
    final resolutionController = TextEditingController();
    final solvedByController = TextEditingController(
      text: (defaultSolvedBy ?? '').trim().isEmpty ? '' : defaultSolvedBy!,
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Mark as Solved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: resolutionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Resolution details',
                hintText: 'Describe what was done / fixed...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: solvedByController,
              decoration: InputDecoration(
                labelText: 'Solved by',
                hintText: 'Responder name / team',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

    if (!mounted || ok != true) return;

    final resolution = resolutionController.text.trim();
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
    final incRef = FirebaseFirestore.instance
        .collection('reports')
        .doc(widget.docId);

    return Scaffold(
      backgroundColor: const Color(0xFF0B2E4A),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Incident Details',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF123C5A),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B2E4A), Color(0xFF113E5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 4800),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: incRef.snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final d = snap.data!.data() ?? <String, dynamic>{};

                final status = (d['status'] ?? 'Reported').toString();
                final statusCode = (d['statusCode'] ?? '').toString();
                final liveStatusCode = statusCode.isNotEmpty
                    ? statusCode
                    : 'pending_admin';

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

                final effectiveStatusCode =
                    _selectedStatusCode ?? liveStatusCode;

                final isSolved =
                    effectiveStatusCode == 'problem_solved' ||
                    liveStatusCode == 'problem_solved';

                final imageUrl = _readImageUrl(d);
                final geo = _readGeoPoint(d);
                final responderGeo = _readResponderGeoPoint(d);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1050;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildLeftPanel(
                                d: d,
                                imageUrl: imageUrl,
                                geo: geo,
                                responderGeo: responderGeo,
                                status: status,
                                adminComment: adminComment,
                                assignedResponderName: assignedResponderName,
                                assignedResponderPhone: assignedResponderPhone,
                                responderDecision: responderDecision,
                                responderDeniedReason: responderDeniedReason,
                                resolutionText: resolutionText,
                                solvedBy: solvedBy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _buildRightPanel(
                                context: context,
                                d: d,
                                isSolved: isSolved,
                                incRef: incRef,
                                assignedResponderName: assignedResponderName,
                                liveStatusCode: liveStatusCode,
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _buildLeftPanel(
                            d: d,
                            imageUrl: imageUrl,
                            geo: geo,
                            responderGeo: responderGeo,
                            status: status,
                            adminComment: adminComment,
                            assignedResponderName: assignedResponderName,
                            assignedResponderPhone: assignedResponderPhone,
                            responderDecision: responderDecision,
                            responderDeniedReason: responderDeniedReason,
                            resolutionText: resolutionText,
                            solvedBy: solvedBy,
                          ),
                          const SizedBox(height: 12),
                          _buildRightPanel(
                            context: context,
                            d: d,
                            isSolved: isSolved,
                            incRef: incRef,
                            assignedResponderName: assignedResponderName,
                            liveStatusCode: liveStatusCode,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel({
    required Map<String, dynamic> d,
    required String imageUrl,
    required GeoPoint? geo,
    required GeoPoint? responderGeo,
    required String status,
    required String? adminComment,
    required String? assignedResponderName,
    required String? assignedResponderPhone,
    required String? responderDecision,
    required String? responderDeniedReason,
    required String? resolutionText,
    required String? solvedBy,
  }) {
    final citizenName = (d['citizenName'] ?? '').toString();
    final citizenPhone = (d['citizenPhone'] ?? '').toString();

    return Column(
      children: [
        if (geo != null)
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Incident Map'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 285,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: ll.LatLng(geo.latitude, geo.longitude),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.jazone_admin',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: ll.LatLng(geo.latitude, geo.longitude),
                              width: 120,
                              height: 56,
                              child: Column(
                                children: const [
                                  Icon(
                                    Icons.location_pin,
                                    color: Colors.redAccent,
                                    size: 34,
                                  ),
                                  SizedBox(height: 2),
                                  Flexible(
                                    child: Text(
                                      'Citizen',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (responderGeo != null)
                              Marker(
                                point: ll.LatLng(
                                  responderGeo.latitude,
                                  responderGeo.longitude,
                                ),
                                width: 120,
                                height: 56,
                                child: Column(
                                  children: const [
                                    Icon(
                                      Icons.directions_run,
                                      color: Colors.lightGreenAccent,
                                      size: 30,
                                    ),
                                    SizedBox(height: 2),
                                    Flexible(
                                      child: Text(
                                        'Responder',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (responderGeo != null)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: [
                                  ll.LatLng(geo.latitude, geo.longitude),
                                  ll.LatLng(
                                    responderGeo.latitude,
                                    responderGeo.longitude,
                                  ),
                                ],
                                strokeWidth: 4,
                                color: const Color(0xFF56C6F5),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Citizen Location: ${geo.latitude.toStringAsFixed(6)} | ${geo.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (responderGeo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Responder Location: ${responderGeo.latitude.toStringAsFixed(6)} | ${responderGeo.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        if (geo != null) const SizedBox(height: 12),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Incident Information'),
              const SizedBox(height: 12),
              if (imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 190,
                    color: const Color(0xFF0D344F),
                    alignment: Alignment.center,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Image failed to load',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                (d['address'] ?? d['locationText'] ?? 'Unknown location')
                    .toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (d['description'] ?? 'No description provided').toString(),
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.35,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _statusChip(Icons.flag, 'Status: $status'),
                  _statusChip(
                    Icons.priority_high,
                    'Urgency: ${(d['urgency'] ?? d['urgencyLevel'] ?? 'N/A').toString()}',
                  ),
                ],
              ),
              if (citizenName.isNotEmpty || citizenPhone.isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoBox(
                  'Citizen',
                  citizenName.isEmpty
                      ? citizenPhone
                      : citizenPhone.isEmpty
                      ? citizenName
                      : '$citizenName • $citizenPhone',
                ),
              ],
              if (adminComment != null && adminComment.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoBox('Admin Comment', adminComment),
              ],
              if (assignedResponderName != null &&
                  assignedResponderName.isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoBox('Assigned Responder', assignedResponderName),
                if (assignedResponderPhone != null &&
                    assignedResponderPhone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoBox('Responder Phone', assignedResponderPhone),
                ],
                if (responderGeo != null) ...[
                  const SizedBox(height: 8),
                  _infoBox(
                    'Responder Location',
                    '${responderGeo.latitude.toStringAsFixed(6)}, ${responderGeo.longitude.toStringAsFixed(6)}',
                  ),
                ],
              ],
              if (responderDecision != null &&
                  responderDecision.isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoBox('Responder Decision', responderDecision),
                if (responderDecision == 'denied' &&
                    responderDeniedReason != null &&
                    responderDeniedReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoBox('Denied Reason', responderDeniedReason),
                ],
              ],
              if (resolutionText != null &&
                  resolutionText.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _infoBox('Resolution', resolutionText),
                if (solvedBy != null && solvedBy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoBox('Solved By', solvedBy),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel({
    required BuildContext context,
    required Map<String, dynamic> d,
    required bool isSolved,
    required DocumentReference<Map<String, dynamic>> incRef,
    required String? assignedResponderName,
    required String liveStatusCode,
  }) {
    return Column(
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Admin Actions'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      label: 'Accept',
                      icon: Icons.check_circle,
                      color: const Color(0xFF23C483),
                      textColor: Colors.white,
                      onPressed: isSolved
                          ? null
                          : () async {
                              await _service.acceptIncident(widget.docId);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Incident accepted'),
                                ),
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionButton(
                      label: 'Deny',
                      icon: Icons.cancel,
                      color: const Color(0xFFEF3B2D),
                      textColor: Colors.white,
                      onPressed: isSolved
                          ? null
                          : () => _denyWithComment(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _actionButton(
                label: 'Mark as Solved',
                icon: Icons.verified,
                color: const Color(0xFFA9DE62),
                textColor: Colors.black,
                fullWidth: true,
                onPressed: isSolved
                    ? null
                    : () => _markAsSolved(
                        context,
                        defaultSolvedBy: assignedResponderName,
                      ),
              ),
              const SizedBox(height: 18),
              _label('Update Status'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStatusCode ?? liveStatusCode,
                decoration: _dropdownDecoration(),
                dropdownColor: Colors.white,
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
                onChanged: (v) {
                  setState(() {
                    _selectedStatusCode = v;
                  });
                },
              ),
              const SizedBox(height: 10),
              _actionButton(
                label: 'Apply Status',
                icon: Icons.sync,
                color: Colors.black,
                textColor: Colors.white,
                fullWidth: true,
                onPressed: isSolved
                    ? null
                    : () async {
                        final code = _selectedStatusCode ?? liveStatusCode;
                        await _service.setStatusCode(widget.docId, code);

                        if (!mounted) return;
                        setState(() {
                          _selectedStatusCode = null;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Status updated')),
                        );
                      },
              ),
              const SizedBox(height: 18),
              _label('Assign Available Responder'),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'responder')
                    .where('isOnline', isEqualTo: true)
                    .snapshots(),
                builder: (context, rsSnap) {
                  if (!rsSnap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Loading responders...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final docs = rsSnap.data!.docs;
                  if (docs.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Text(
                        'No online responders available.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  final geo = _readGeoPoint(d);
                  final incidentLat = geo?.latitude ?? 0.0;
                  final incidentLng = geo?.longitude ?? 0.0;

                  final items = docs.map((doc) {
                    final u = doc.data();
                    final uid = (u['uid'] ?? doc.id).toString();
                    final name = (u['name'] ?? 'Responder').toString();
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
                      'id': uid,
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

                  final selectedExists = items.any(
                    (e) => e['id'] == _selectedResponderId,
                  );
                  if (!selectedExists) {
                    _selectedResponderId = null;
                  }

                  return Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedResponderId,
                        isExpanded: true,
                        decoration: _dropdownDecoration(),
                        hint: const Text('Select available responder'),
                        items: items.map((r) {
                          final label = (r['meters'] == null)
                              ? '${r['name']} (${r['phone']})'
                              : '${r['name']} (${r['phone']}) • ${(r['meters'] as double).toStringAsFixed(0)}m';

                          return DropdownMenuItem<String>(
                            value: r['id'] as String,
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedResponderId = v;
                            final picked = items.firstWhere(
                              (e) => e['id'] == v,
                              orElse: () => <String, Object?>{},
                            );
                            _selectedResponderName = picked['name']?.toString();
                            _selectedResponderPhone = picked['phone']
                                ?.toString();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _actionButton(
                        label: 'Assign Responder',
                        icon: Icons.person_add_alt_1,
                        color: Colors.black,
                        textColor: Colors.white,
                        fullWidth: true,
                        onPressed: (_selectedResponderId == null || isSolved)
                            ? null
                            : () async {
                                await _service.assignResponder(
                                  incidentId: widget.docId,
                                  responderId: _selectedResponderId!,
                                  responderName:
                                      _selectedResponderName ?? 'Responder',
                                  responderPhone: _selectedResponderPhone ?? '',
                                );

                                if (!mounted) return;
                                setState(() {
                                  _selectedStatusCode = null;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Responder assigned successfully',
                                    ),
                                  ),
                                );
                              },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Timeline'),
              const SizedBox(height: 10),
              SizedBox(
                height: 240,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: incRef
                      .collection('timeline')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, tSnap) {
                    if (!tSnap.hasData) {
                      return const Center(
                        child: Text(
                          'Loading timeline...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    final docs = tSnap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No timeline entries yet.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length > 12 ? 12 : docs.length,
                      separatorBuilder: (_, __) => Divider(
                        color: Colors.white.withOpacity(0.08),
                        height: 14,
                      ),
                      itemBuilder: (context, index) {
                        final td = docs[index].data();
                        final msg = (td['message'] ?? '').toString();
                        final code = (td['statusCode'] ?? '').toString();

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: Color(0xFF56C6F5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    code,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C567B).withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  Widget _statusChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              height: 1.35,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback? onPressed,
    bool fullWidth = false,
  }) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: Size(fullWidth ? double.infinity : 0, 46),
        backgroundColor: color,
        foregroundColor: textColor,
        disabledBackgroundColor: Colors.grey.shade500,
        disabledForegroundColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.4),
      ),
    );
  }
}
