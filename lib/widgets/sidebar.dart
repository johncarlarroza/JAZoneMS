import 'package:flutter/material.dart';

class Sidebar extends StatelessWidget {
  final int index;
  final Function(int) onSelect;

  const Sidebar({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B132B), Color(0xFF1C2541)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DB8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'IR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Incident\nReports',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4DB8FF),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Navigation Items
          _navItem('Dashboard', Icons.dashboard, 0),
          const SizedBox(height: 12),
          _navItem('Requests', Icons.list_alt, 1),
          const SizedBox(height: 12),
          _navItem('Reports', Icons.picture_as_pdf, 2),
        ],
      ),
    );
  }

  Widget _navItem(String label, IconData icon, int i) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: 250,
        height: 60,
        decoration: BoxDecoration(
          color: index == i ? const Color(0xFF4DB8FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: index == i ? Colors.white : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: index == i ? Colors.white : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
