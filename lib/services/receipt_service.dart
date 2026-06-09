import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ReceiptService {
  static Future<File> generateReceiptPdf({
    required String donorName,
    required double amount,
    required String campaignName,
    required String transactionId,
    required DateTime date,
    required String paymentMethod,
  }) async {
    final pdf = pw.Document();

    // Manual date formatting
    String getMonthName(int month) {
      const months = [
        'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
        'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember'
      ];
      return months[month - 1];
    }
    
    String getAmPm(int hour) {
      return hour >= 12 ? 'PTG' : 'PAGI';
    }
    
    int get12Hour(int hour) {
      int h = hour % 12;
      return h == 0 ? 12 : h;
    }

    final formattedDate = '${date.day} ${getMonthName(date.month)} ${date.year}, ${get12Hour(date.hour).toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${getAmPm(date.hour)}';
    final formattedAmount = 'RM ${amount.toStringAsFixed(2)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('SIGAP', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.SizedBox(height: 8),
                      pw.Text('Sistem Integrasi Gerak Awam Pantas', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('RESIT CUKAI DIGITAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Container(
                    padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                    decoration: pw.BoxDecoration(color: PdfColors.blue100, borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Text('RESIT SUMBANGAN', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ),
                ),
                pw.SizedBox(height: 20),
                _infoRow('No. Resit:', transactionId),
                _infoRow('Tarikh:', formattedDate),
                _infoRow('Kaedah Bayaran:', paymentMethod),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text('MAKLUMAT PENDERMA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 10),
                _infoRow('Nama Penderma:', donorName),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text('MAKLUMAT SUMBANGAN', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                pw.SizedBox(height: 10),
                _infoRow('Tujuan Sumbangan:', campaignName),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('JUMLAH SUMBANGAN:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(formattedAmount, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Column(
                    children: [
                      pw.Text('PENGECUALIAN CUKAI', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                      pw.SizedBox(height: 8),
                      pw.Text('Sumbangan ini layak mendapat pengecualian cukai di bawah\nSubseksyen 44(6) Akta Cukai Pendapatan 1967.', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Text('Terima kasih atas sokongan anda!\nwww.sigap.gov.my', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/receipt_$transactionId.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<void> shareReceipt(File pdfFile, String receiptNo) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: 'SIGAP Donation Receipt - $receiptNo\n\nTerima kasih atas sumbangan anda!',
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 120, child: pw.Text(label, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.normal))),
        ],
      ),
    );
  }
}