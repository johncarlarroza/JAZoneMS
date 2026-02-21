import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/incident_model.dart';

class PdfExportService {
  static Future<void> export(List<Incident> incidents) async {
    final pdf = pw.Document();

    final generatedAt = DateFormat.yMMMd().add_jm().format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            'Incident Reports',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Generated: $generatedAt'),
          pw.SizedBox(height: 16),

          pw.Table.fromTextArray(
            headers: const ['Address', 'Urgency', 'Status', 'Date'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.6),
            },
            data: incidents.map((i) {
              final address = (i.address).trim().isEmpty
                  ? '—'
                  : i.address.trim();
              final urgency = (i.urgency).trim().isEmpty
                  ? '—'
                  : i.urgency.trim();
              final status = (i.status).trim().isEmpty ? '—' : i.status.trim();

              final dt = i.timestamp?.toDate();
              final dateText = dt == null
                  ? '—'
                  : DateFormat.yMd().add_jm().format(dt);

              return [address, urgency, status, dateText];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}
