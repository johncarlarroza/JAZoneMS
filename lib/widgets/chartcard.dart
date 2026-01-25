import 'package:flutter/material.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final String chartType;

  const ChartCard({
    super.key,
    required this.title,
    required this.data,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A4D6D).withOpacity(0.8),
            const Color(0xFF0F3847).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF4DB8FF).withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: chartType == 'pie' ? _buildPieChart() : _buildBarChart(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final total = data.values.fold(0.0, (a, b) => a + b);
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFFFFC107),
      const Color(0xFF8BC34A),
      const Color(0xFFFF9800),
    ];

    return CustomPaint(
      painter: PieChartPainter(data, colors),
      size: const Size(150, 150),
    );
  }

  Widget _buildBarChart() {
    final maxValue = data.values.fold(0.0, (a, b) => a > b ? a : b);
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFFFFC107),
      const Color(0xFF8BC34A),
      const Color(0xFFFF9800),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(data.length, (index) {
        final entry = data.entries.elementAt(index);
        final height = (entry.value / maxValue) * 100;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.value.toStringAsFixed(0),
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
            const SizedBox(height: 4),
            Text(
              entry.key.split(' ')[0],
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 9),
            ),
          ],
        );
      }),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;

  PieChartPainter(this.data, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.values.fold(0.0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    double currentAngle = -90 * 3.14159 / 180;

    int index = 0;
    data.forEach((label, value) {
      final sweepAngle = (value / total) * 2 * 3.14159;

      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        true,
        paint,
      );

      currentAngle += sweepAngle;
      index++;
    });

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = const Color(0xFF1A3A52)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerPaint);

    // Draw total in center
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Total',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 8,
      ),
    );

    final valuePainter = TextPainter(
      text: TextSpan(
        text: total.toStringAsFixed(0),
        style: const TextStyle(
          color: Color(0xFF4DB8FF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    valuePainter.layout();
    valuePainter.paint(
      canvas,
      Offset(center.dx - valuePainter.width / 2, center.dy + 4),
    );
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) => false;
}
