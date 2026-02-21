import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CitizensManagementPage extends StatefulWidget {
  const CitizensManagementPage({super.key});

  @override
  State<CitizensManagementPage> createState() => _CitizensManagementPageState();
}

class _CitizensManagementPageState extends State<CitizensManagementPage> {
  final _search = TextEditingController();
  String _statusFilter = 'All'; // All / Online / Offline

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _pageShell(
      title: 'Citizens Management',
      subtitle: 'Manage all registered citizens',
      child: Column(
        children: [
          _topControls(),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'citizen')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final q = _search.text.trim().toLowerCase();
                final docs = snap.data!.docs.where((doc) {
                  final d = doc.data();
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  final phone = (d['phone'] ?? '').toString().toLowerCase();

                  final isOnline = d['isOnline'] == true;

                  final matchesSearch =
                      q.isEmpty ||
                      name.contains(q) ||
                      email.contains(q) ||
                      phone.contains(q);

                  final matchesStatus =
                      _statusFilter == 'All' ||
                      (_statusFilter == 'Online' && isOnline) ||
                      (_statusFilter == 'Offline' && !isOnline);

                  return matchesSearch && matchesStatus;
                }).toList();

                return _table(context: context, rows: docs, isResponder: false);
              },
            ),
          ),
        ],
      ),
    );
  }

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
        _statusDropdown(
          value: _statusFilter,
          items: const ['All', 'Online', 'Offline'],
          onChanged: (v) => setState(() => _statusFilter = v),
        ),
      ],
    );
  }

  Widget _table({
    required BuildContext context,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> rows,
    required bool isResponder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            Colors.white.withOpacity(0.10),
          ),
          dataRowMinHeight: 56,
          columns: const [
            DataColumn(
              label: Text('User ID', style: TextStyle(color: Colors.white)),
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
            final online = d['isOnline'] == true;

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
                DataCell(_statusPill(online ? 'Online' : 'Offline')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Update',
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed: () => _openEditDialog(
                          context: context,
                          userId: id,
                          data: d,
                          isResponder: false,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
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

  Future<void> _confirmDelete(BuildContext context, String userId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Citizen'),
        content: const Text(
          'This deletes the user profile document in Firestore.\n\n'
          'Note: This does NOT delete the FirebaseAuth account (needs Admin SDK / Cloud Function).',
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
    ).showSnackBar(const SnackBar(content: Text('Citizen profile deleted.')));
  }

  Future<void> _openEditDialog({
    required BuildContext context,
    required String userId,
    required Map<String, dynamic> data,
    required bool isResponder,
  }) async {
    final nameC = TextEditingController(text: (data['name'] ?? '').toString());
    final emailC = TextEditingController(
      text: (data['email'] ?? '').toString(),
    );
    final phoneC = TextEditingController(
      text: (data['phone'] ?? '').toString(),
    );
    bool isOnline = data['isOnline'] == true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Citizen'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: emailC,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneC,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Online Status'),
                value: isOnline,
                onChanged: (v) => isOnline = v,
              ),
            ],
          ),
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

    if (saved != true) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'name': nameC.text.trim(),
      'email': emailC.text.trim(),
      'phone': phoneC.text.trim(),
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Citizen updated.')));
  }

  // UI helpers
  Widget _pageShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A3A52), Color(0xFF2D5F7B)],
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
              fontWeight: FontWeight.bold,
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

  Widget _statusDropdown({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF2D5F7B),
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white),
        items: items
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
            .toList(),
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  Widget _statusPill(String text) {
    final isOnline = text.toLowerCase() == 'online';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.greenAccent.withOpacity(0.25)
            : Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
