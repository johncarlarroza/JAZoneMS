import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/responder_service.dart';
import '../services/location_sharing_service.dart';
import 'responder_dispatch_page.dart';

class ResponderHomePage extends StatefulWidget {
  const ResponderHomePage({super.key});

  @override
  State<ResponderHomePage> createState() => _ResponderHomePageState();
}

class _ResponderHomePageState extends State<ResponderHomePage> {
  final _service = ResponderService();
  late final LocationSharingService _locationService;

  bool _locationOn = false;
  bool _loadingToggle = false;

  @override
  void initState() {
    super.initState();
    _locationService = LocationSharingService(_service);
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_service.uid)
        .get();

    final data = doc.data() ?? <String, dynamic>{};
    final enabled = data['locationEnabled'] == true;

    if (mounted) setState(() => _locationOn = enabled);

    if (enabled) {
      // start idle updates so admin sees you nearby
      await _locationService.startIdleAvailabilityUpdates();
    }
  }

  Future<void> _toggleLocation(bool v) async {
    setState(() => _loadingToggle = true);

    if (v) {
      await _locationService.startIdleAvailabilityUpdates();
    } else {
      await _locationService.stopAllLocation();
    }

    if (mounted) {
      setState(() {
        _locationOn = v;
        _loadingToggle = false;
      });
    }
  }

  Future<void> _denyDialog(String incidentId) async {
    final c = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deny Assignment'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional reason (recommended)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    await _service.denyIncident(incidentId, reason: reason);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Assignment denied')));
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Responder Home')),
      body: Column(
        children: [
          // Availability toggle
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: ListTile(
                title: const Text('Availability'),
                subtitle: Text(
                  _locationOn
                      ? 'Available (Location ON)'
                      : 'Unavailable (Location OFF)',
                ),
                trailing: _loadingToggle
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _locationOn,
                        onChanged: (v) => _toggleLocation(v),
                      ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.assignedIncidentsStream(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('No assignments yet.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final id = docs[i].id;

                    final title =
                        (d['description'] ?? d['incidentTitle'] ?? 'Incident')
                            .toString();
                    final address = (d['address'] ?? '').toString();
                    final urgency = (d['urgency'] ?? '').toString();
                    final statusCode = (d['statusCode'] ?? '').toString();
                    final decision = (d['responderDecision'] ?? '').toString();

                    final canAct = decision.isEmpty || decision == 'pending';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(address),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Chip(label: Text('Urgency: $urgency')),
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    'Status: ${statusCode.isEmpty ? '—' : statusCode}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (canAct)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        // If location OFF, still allow accept but we force dispatch tracking
                                        await _service.acceptIncident(id);

                                        // Start dispatch tracking
                                        await _locationService
                                            .startDispatchTracking(
                                              incidentId: id,
                                            );

                                        if (!mounted) return;
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ResponderDispatchPage(
                                                  incidentId: id,
                                                ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text('Accept'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _denyDialog(id),
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Deny'),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text('Decision: $decision'),
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
    );
  }
}
