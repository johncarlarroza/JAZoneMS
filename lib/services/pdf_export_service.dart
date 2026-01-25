import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/incident_model.dart';

class PdfExportService {
  static Future<void> export(List<Incident> incidents) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            'Incident Reports',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated: ${DateFormat.yMMMd().add_jm().format(DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Address', 'Urgency', 'Status', 'Date'],
            data: incidents
                .map(
                  (i) => [
                    i.address,
                    i.urgency,
                    i.status,
                    DateFormat.yMd().add_jm().format(i.timestamp.toDate()),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }
}
