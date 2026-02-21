import 'dart:math';
import 'package:flutter/material.dart';

class ChartCard extends StatefulWidget {
  final String title;
  final Map<String, double> data; // expects >= 1 item
  final String chartType; // 'pie' or 'bar'

  const ChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.chartType,
  });

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _hover = false;

  // Keep a stable palette so charts look consistent
  final List<Color> _palette = const [
    Color(0xFF4CAF50), // green
    Color(0xFFFFC107), // amber
    Color(0xFF4DB8FF), // blue
    Color(0xFFFF5A5F), // red
    Color(0xFF8BC34A), // light green
    Color(0xFFFF9800), // orange
  ];

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                _pill(widget.chartType == 'pie' ? 'Donut' : 'Bars'),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 520;

                  // For wide cards: chart + legend side-by-side
                  // For narrow: chart then legend below
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Center(
                            child: widget.chartType == 'pie'
                                ? _buildPie(entries)
                                : _buildBar(entries),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: _Legend(entries: entries, palette: _palette),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: widget.chartType == 'pie'
                              ? _buildPie(entries)
                              : _buildBar(entries),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _Legend(entries: entries, palette: _palette),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPie(List<MapEntry<String, double>> entries) {
    final total = entries.fold<double>(0, (a, e) => a + e.value);
    final size = 180.0;

    return CustomPaint(
      size: Size(size, size),
      painter: _DonutPainter(entries: entries, colors: _palette, total: total),
    );
  }

  Widget _buildBar(List<MapEntry<String, double>> entries) {
    final maxValue = entries.isEmpty
        ? 1.0
        : entries
              .map((e) => e.value)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1.0, double.infinity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          final h = (e.value / maxValue) * 120; // bar height scale

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    e.value.toStringAsFixed(0),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    height: h.isNaN ? 0 : h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          _palette[i % _palette.length].withOpacity(0.90),
                          _palette[i % _palette.length].withOpacity(0.35),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: _palette[i % _palette.length].withOpacity(0.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _shortLabel(e.key),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _shortLabel(String s) {
    // Keep admin charts compact
    final trimmed = s.trim();
    if (trimmed.length <= 10) return trimmed;
    return '${trimmed.substring(0, 10)}…';
  }
}

class _Legend extends StatelessWidget {
  final List<MapEntry<String, double>> entries;
  final List<Color> palette;

  const _Legend({required this.entries, required this.palette});

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (a, e) => a + e.value);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = entries[i];
                final pct = total <= 0 ? 0 : (e.value / total) * 100;

                return Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${e.value.toStringAsFixed(0)} • ${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final List<Color> colors;
  final double total;

  _DonutPainter({
    required this.entries,
    required this.colors,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // background ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius * 0.72, bgPaint);

    if (entries.isEmpty || total <= 0) {
      _drawCenterText(canvas, center, 'Total', '0');
      return;
    }

    // donut arcs
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;

    double start = -pi / 2;
    for (int i = 0; i < entries.length; i++) {
      final v = entries[i].value;
      final sweep = (v / total) * 2 * pi;

      arcPaint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        start,
        sweep,
        false,
        arcPaint,
      );

      start += sweep;
    }

    _drawCenterText(canvas, center, 'Total', total.toStringAsFixed(0));
  }

  void _drawCenterText(
    Canvas canvas,
    Offset center,
    String top,
    String bottom,
  ) {
    final topPainter = TextPainter(
      text: TextSpan(
        text: top,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    topPainter.paint(
      canvas,
      Offset(center.dx - topPainter.width / 2, center.dy - 18),
    );

    final bottomPainter = TextPainter(
      text: TextSpan(
        text: bottom,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    bottomPainter.paint(
      canvas,
      Offset(center.dx - bottomPainter.width / 2, center.dy + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    // repaint when data changes
    return oldDelegate.total != total || oldDelegate.entries != entries;
  }
}
