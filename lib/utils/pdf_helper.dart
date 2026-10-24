import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfHelper {
  static Future<void> generateAttendanceReport({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    String? subtitle,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("EduGuard Attendance System",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.blue900)),
                      pw.Text(title,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      if (subtitle != null) pw.Text(subtitle),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Generated on:"),
                      pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellHeight: 30,
              cellAlignments: {
                for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
              },
            ),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              trailing: pw.Text("Page ${context.pageNumber} of ${context.pagesCount}"),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
