import 'package:flutter/material.dart';

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0.0, _hover ? -3.0 : 0.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(_hover ? 0.13 : 0.10),
          border: Border.all(
            color: Colors.white.withOpacity(_hover ? 0.20 : 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hover ? 0.28 : 0.18),
              blurRadius: _hover ? 26 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      baseColor.withOpacity(0.35),
                      baseColor.withOpacity(0.14),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: baseColor.withOpacity(0.35)),
                ),
                child: Icon(widget.icon, color: baseColor, size: 24),
              ),
              const SizedBox(width: 14),

              // Text area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Accent bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 6,
                height: _hover ? 42 : 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: baseColor.withOpacity(_hover ? 0.85 : 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
