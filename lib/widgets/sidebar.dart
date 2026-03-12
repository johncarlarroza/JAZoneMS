import 'package:flutter/material.dart';
import 'package:jazone_monitoring_dashboard/auth/login_page.dart';

class Sidebar extends StatelessWidget {
  final int index;
  final Function(int) onSelect;

  const Sidebar({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF041626), Color(0xFF07243B), Color(0xFF0A2E4A)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 22),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Image.asset(
                      'assets/jzlogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'JAzone Monitoring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Admin System',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            _sectionLabel('MAIN MENU'),
            const SizedBox(height: 10),

            NavItem(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              itemIndex: 0,
              selectedIndex: index,
              onTap: onSelect,
            ),
            const SizedBox(height: 10),

            NavItem(
              label: 'Incidents',
              icon: Icons.warning_amber_rounded,
              itemIndex: 1,
              selectedIndex: index,
              onTap: onSelect,
            ),
            const SizedBox(height: 10),

            NavItem(
              label: 'Reports (PDF)',
              icon: Icons.picture_as_pdf_outlined,
              itemIndex: 2,
              selectedIndex: index,
              onTap: onSelect,
            ),
            const SizedBox(height: 10),

            NavItem(
              label: 'Citizen Management',
              icon: Icons.groups_outlined,
              itemIndex: 3,
              selectedIndex: index,
              onTap: onSelect,
            ),
            const SizedBox(height: 10),

            NavItem(
              label: 'Responder Management',
              icon: Icons.local_hospital_outlined,
              itemIndex: 4,
              selectedIndex: index,
              onTap: onSelect,
            ),

            const Spacer(),

            _sectionLabel('ACCOUNT'),
            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: NavItem(
                label: 'Logout',
                icon: Icons.logout_rounded,
                itemIndex: -1,
                selectedIndex: -999,
                onTap: (_) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.60),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
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
    final isActive = widget.itemIndex == widget.selectedIndex;
    final highlight = isActive || isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: highlight
                ? const LinearGradient(
                    colors: [Color(0xFF2D678F), Color(0xFF22597E)],
                  )
                : null,
            color: highlight ? null : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: highlight
                  ? Colors.white.withOpacity(0.16)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(highlight ? 0.18 : 0.10),
                blurRadius: highlight ? 14 : 8,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => widget.onTap(widget.itemIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: highlight
                            ? Colors.white.withOpacity(0.14)
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: highlight
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (highlight)
                      Container(
                        width: 6,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF59B7FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
