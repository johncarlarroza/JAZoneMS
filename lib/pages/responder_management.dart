import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RespondersManagementPage extends StatefulWidget {
  const RespondersManagementPage({super.key});

  @override
  State<RespondersManagementPage> createState() =>
      _RespondersManagementPageState();
}

class _RespondersManagementPageState extends State<RespondersManagementPage> {
  final _search = TextEditingController();
  String _statusFilter = 'All'; // All / available / unavailable / on_dispatch

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _pageShell(
      title: 'Responder Management',
      subtitle: 'View, monitor, and manage all responder accounts',
      child: Column(
        children: [
          _topControls(),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'responder')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _search.text.trim().toLowerCase();
                final rows = snap.data!.docs.where((doc) {
                  final d = doc.data();
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  final phone = (d['phone'] ?? '').toString().toLowerCase();

                  final availability =
                      (d['availabilityStatus'] ?? 'unavailable')
                          .toString()
                          .toLowerCase();

                  final matchesSearch =
                      q.isEmpty ||
                      name.contains(q) ||
                      email.contains(q) ||
                      phone.contains(q);

                  final matchesStatus =
                      _statusFilter == 'All' ||
                      availability == _statusFilter.toLowerCase();

                  return matchesSearch && matchesStatus;
                }).toList();

                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No responders found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return _table(context: context, rows: rows);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED: added "Add Responder" button
  Widget _topControls() {
    return Row(
      children: [
        Expanded(
          child: _searchField(
            hint: 'Search by name, email, or phone...',
            controller: _search,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 14),
        _dropdown(
          value: _statusFilter,
          items: const ['All', 'available', 'unavailable', 'on_dispatch'],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
        const SizedBox(width: 14),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _openCreateResponderDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Responder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _table({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            Colors.white.withOpacity(0.10),
          ),

          // ✅ avoid web DataTable constraint issues
          columnSpacing: 22,
          horizontalMargin: 12,

          columns: const [
            DataColumn(
              label: Text(
                'Responder ID',
                style: TextStyle(color: Colors.white),
              ),
            ),
            DataColumn(
              label: Text('Name', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Email', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Phone', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Location', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Status', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Actions', style: TextStyle(color: Colors.white)),
            ),
          ],
          rows: rows.map((doc) {
            final d = doc.data();
            final id = doc.id;

            final name = (d['name'] ?? '—').toString();
            final email = (d['email'] ?? '—').toString();
            final phone = (d['phone'] ?? '—').toString();

            final locationEnabled = d['locationEnabled'] == true;
            final availability = (d['availabilityStatus'] ?? 'unavailable')
                .toString();

            return DataRow(
              cells: [
                DataCell(Text(id, style: const TextStyle(color: Colors.white))),
                DataCell(
                  Text(name, style: const TextStyle(color: Colors.white)),
                ),
                DataCell(
                  Text(email, style: const TextStyle(color: Colors.white70)),
                ),
                DataCell(
                  Text(phone, style: const TextStyle(color: Colors.white70)),
                ),
                DataCell(
                  _pill(
                    locationEnabled ? 'ON' : 'OFF',
                    positive: locationEnabled,
                  ),
                ),
                DataCell(
                  _pill(
                    availability,
                    positive: availability.toLowerCase() == 'available',
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Update',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed: () => _openEditDialog(
                          context: context,
                          userId: id,
                          data: d,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, id),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ===================== ✅ NEW: Create Responder =====================

  Future<void> _openCreateResponderDialog(BuildContext context) async {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Create Responder Account'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(
                      labelText: 'Responder Name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneC,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Note: This creates a Firestore profile only.\n'
                    'It does NOT create FirebaseAuth login credentials.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameC.text.trim();
                final phone = phoneC.text.trim();
                final email = emailC.text.trim();

                if (name.isEmpty || phone.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in Name, Phone, and Email.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogCtx, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) return;

    final name = nameC.text.trim();
    final phone = phoneC.text.trim();
    final email = emailC.text.trim();

    // Optional: prevent duplicates by phone or email
    final existing = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'responder')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A responder with this phone already exists.'),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('users').add({
      'role': 'responder',
      'name': name,
      'phone': phone,
      'email': email,
      'locationEnabled': false,
      'availabilityStatus': 'unavailable',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Responder profile created.')));
  }

  // ===================== Existing CRUD =====================

  Future<void> _confirmDelete(BuildContext context, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Responder'),
        content: const Text(
          'This deletes the responder profile document in Firestore.\n\n'
          'Note: It will NOT delete the FirebaseAuth account (needs Admin SDK / Cloud Function).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Responder profile deleted.')));
  }

  Future<void> _openEditDialog({
    required BuildContext context,
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final nameC = TextEditingController(text: (data['name'] ?? '').toString());
    final emailC = TextEditingController(
      text: (data['email'] ?? '').toString(),
    );
    final phoneC = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );

    bool locationEnabled = data['locationEnabled'] == true;
    String availability = (data['availabilityStatus'] ?? 'unavailable')
        .toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Update Responder'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameC,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: emailC,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneC,
                        decoration: const InputDecoration(labelText: 'Phone'),
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Location Enabled',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Switch(
                              value: locationEnabled,
                              onChanged: (v) =>
                                  setLocalState(() => locationEnabled = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: availability,
                        decoration: const InputDecoration(
                          labelText: 'Availability Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('available'),
                          ),
                          DropdownMenuItem(
                            value: 'unavailable',
                            child: Text('unavailable'),
                          ),
                          DropdownMenuItem(
                            value: 'on_dispatch',
                            child: Text('on_dispatch'),
                          ),
                        ],
                        onChanged: (v) => setLocalState(
                          () => availability = v ?? 'unavailable',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'name': nameC.text.trim(),
      'email': emailC.text.trim(),
      'phone': phoneC.text.trim(),
      'locationEnabled': locationEnabled,
      'availabilityStatus': availability,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Responder updated.')));
  }

  // ---------- UI helpers ----------
  Widget _pageShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2435), Color(0xFF163A52), Color(0xFF2D5F7B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _searchField({
    required String hint,
    required TextEditingController controller,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white60),
        prefixIcon: const Icon(Icons.search, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF2D5F7B),
        iconEnabledColor: Colors.white,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  Widget _pill(String text, {required bool positive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: positive
            ? Colors.greenAccent.withOpacity(0.25)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
