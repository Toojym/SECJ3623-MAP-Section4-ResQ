import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';

class MissionCompletionScreen extends StatefulWidget {
  final String sosDocId;
  const MissionCompletionScreen({super.key, required this.sosDocId});

  @override
  State<MissionCompletionScreen> createState() => _MissionCompletionScreenState();
}

class _MissionCompletionScreenState extends State<MissionCompletionScreen> {
  final _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final _victimsController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _victimCondition = 'Selamat';
  bool _isSubmitting = false;

  final List<String> _conditions = ['Selamat', 'Kecederaan Ringan', 'Kecederaan Parah', 'Kritikal', 'Meninggal Dunia'];

  @override
  void dispose() {
    _victimsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitCompletion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final completionDetails = {
        'victimsRescued': int.tryParse(_victimsController.text) ?? 0,
        'victimCondition': _victimCondition,
        'notes': _notesController.text,
        'completedAt': DateTime.now().toIso8601String(),
      };

      await _firestoreService.resolveSOSReportByVolunteer(
        widget.sosDocId,
        completionDetails: completionDetails,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Misi diselesaikan dengan jaya!'),
            backgroundColor: AppColors.safe,
          ),
        );
        // Pop back to dashboard
        context.pop(); // Pop completion screen
        context.pop(); // Pop SOS response screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ralat menyelesaikan misi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Laporan Penyelesaian Misi',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lengkapkan laporan di bawah untuk menutup kes kecemasan ini.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Bilangan Mangsa
              Text(
                'Bilangan Mangsa Diselamatkan',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _victimsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Cth: 2',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Sila masukkan bilangan mangsa';
                  if (int.tryParse(val) == null) return 'Sila masukkan nombor yang sah';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Keadaan Mangsa
              Text(
                'Keadaan Umum Mangsa',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _victimCondition,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _conditions.map((String condition) {
                  return DropdownMenuItem<String>(
                    value: condition,
                    child: Text(condition, style: GoogleFonts.inter(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _victimCondition = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Nota Tambahan
              Text(
                'Nota Tambahan (Pilihan)',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Cth: Mangsa telah diserahkan kepada pihak ambulans...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCompletion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safe,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Sahkan & Selesaikan Misi', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
