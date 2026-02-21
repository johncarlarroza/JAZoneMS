import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/auth/login_page.dart';

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4DB8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'JZ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'JAzone\nMonitoring',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4DB8FF),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          NavItem(
            label: 'Dashboard',
            icon: Icons.dashboard,
            itemIndex: 0,
            selectedIndex: index,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),
          NavItem(
            label: 'Incidents',
            icon: Icons.list_alt,
            itemIndex: 1,
            selectedIndex: index,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),
          NavItem(
            label: 'Reports (PDF)',
            icon: Icons.picture_as_pdf,
            itemIndex: 2,
            selectedIndex: index,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),

          // ✅ requested tabs
          NavItem(
            label: 'Citizen Management',
            icon: Icons.people,
            itemIndex: 3,
            selectedIndex: index,
            onTap: onSelect,
          ),
          const SizedBox(height: 12),
          NavItem(
            label: 'Responder Management',
            icon: Icons.health_and_safety,
            itemIndex: 4,
            selectedIndex: index,
            onTap: onSelect,
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(12),
            child: NavItem(
              label: 'Logout',
              icon: Icons.logout,
              itemIndex: -1,
              selectedIndex: -2,
              onTap: (_) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NavItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final int itemIndex;
  final int selectedIndex;
  final Function(int) onTap;

  const NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.itemIndex,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.itemIndex == widget.selectedIndex;
    final bool showGradient = isActive || isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          width: 250,
          height: 56,
          decoration: BoxDecoration(
            gradient: showGradient
                ? const LinearGradient(
                    colors: [Color(0xFF4DB8FF), Color(0xFFFF8C42)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => widget.onTap(widget.itemIndex),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    widget.icon,
                    color: showGradient ? Colors.white : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: showGradient ? Colors.white : Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
