import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔥 GET DATA FROM `incidents`
  Future<Map<String, dynamic>> _getReportsData() async {
    final snapshot = await _firestore.collection('incidents').get();

    int total = snapshot.docs.length;
    int reported = 0;
    int solved = 0;
    int rejected = 0;

    for (var doc in snapshot.docs) {
      final status = (doc['status'] ?? '').toString().toLowerCase();

      if (status == 'reported') {
        reported++;
      } else if (status == 'solved') {
        solved++;
      } else if (status == 'rejected') {
        rejected++;
      }
    }

    return {
      'total': total,
      'reported': reported,
      'solved': solved,
      'rejected': rejected,
    };
  }

  /// ---------------- PDF EXPORT ----------------
  Future<void> _exportPdf({
    required int total,
    required int reported,
    required int solved,
    required int rejected,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Incident Reports',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              _pdfRow('Total Incidents', total),
              _pdfRow('Reported', reported),
              _pdfRow('Solved', solved),
              _pdfRow('Rejected', rejected),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateTime.now()}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfRow(String label, int value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
            value.toString(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A2332), Color(0xFF0F1419)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Incident analytics overview',
              style: TextStyle(color: Color(0xFF90A3B1), fontSize: 14),
            ),
            const SizedBox(height: 24),

            /// DATA
            FutureBuilder<Map<String, dynamic>>(
              future: _getReportsData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4DB8FF),
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                final total = data['total'];
                final reported = data['reported'];
                final solved = data['solved'];
                final rejected = data['rejected'];

                return Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        /// EXPORT BUTTON
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _exportPdf(
                                total: total,
                                reported: reported,
                                solved: solved,
                                rejected: rejected,
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Export PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4DB8FF),
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        /// SUMMARY CARDS
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _reportCard(
                              title: 'Total',
                              value: total.toString(),
                              icon: Icons.warning,
                              color: Colors.blue,
                            ),
                            _reportCard(
                              title: 'Reported',
                              value: reported.toString(),
                              icon: Icons.report,
                              color: Colors.orange,
                            ),
                            _reportCard(
                              title: 'Solved',
                              value: solved.toString(),
                              icon: Icons.check_circle,
                              color: Colors.green,
                            ),
                            _reportCard(
                              title: 'Rejected',
                              value: rejected.toString(),
                              icon: Icons.cancel,
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2E3E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A3F52)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF90A3B1), fontSize: 11),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
