import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sos_report_model.dart';
import '../../services/firestore_service.dart';
import 'package:easy_localization/easy_localization.dart';

class MissionChecklistScreen extends StatefulWidget {
  final String sosDocId;
  const MissionChecklistScreen({super.key, required this.sosDocId});

  @override
  State<MissionChecklistScreen> createState() => _MissionChecklistScreenState();
}

class _MissionChecklistScreenState extends State<MissionChecklistScreen> {
  final _firestoreService = FirestoreService();

  final List<String> _checklistItems = [
    'Peralatan kecemasan lengkap (First aid, dsb)'.tr(),
    'Dalam perjalanan ke lokasi insiden'.tr(),
    'Tiba di lokasi insiden'.tr(),
    'Menjalankan operasi menyelamat'.tr(),
    'Bantuan awal disalurkan kepada mangsa'.tr(),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.uid : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Senarai Semak Misi'.tr(),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_reports')
            .where('responderId', isEqualTo: uid)
            .where('status', isEqualTo: 'responded')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.volunteerAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildNoActiveMission();
          }

          // In case of multiple active missions, we use the first one or if a specific docId was passed, we find that one.
          SosReportModel? currentMission;
          if (widget.sosDocId.isNotEmpty) {
            try {
              currentMission = snapshot.data!.docs
                  .map((doc) => SosReportModel.fromDocument(doc))
                  .firstWhere((r) => r.id == widget.sosDocId);
            } catch (e) {
              currentMission = null;
            }
          }
          
          currentMission ??= SosReportModel.fromDocument(snapshot.data!.docs.first);

          final currentChecklist = currentMission.volunteerChecklist ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMissionHeader(currentMission),
              const SizedBox(height: 24),
              Text(
                'Tandai tugas yang telah diselesaikan:'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._checklistItems.map((item) {
                final bool isChecked = currentChecklist[item] == true;
                return _buildChecklistItem(item, isChecked, currentMission!);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoActiveMission() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Tiada Misi Aktif'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Senarai semak hanya tersedia untuk\nmisi yang sedang dijalankan.'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionHeader(SosReportModel report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.volunteerAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.volunteerAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.volunteerAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emergency_rounded, color: AppColors.volunteerAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Misi: ${report.type}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.address.isNotEmpty ? report.address : 'Lokasi koordinat'.tr(),
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isChecked, SosReportModel report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isChecked ? AppColors.safe.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? AppColors.safe : AppColors.divider,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
            color: isChecked ? AppColors.safe : AppColors.textPrimary,
            decoration: isChecked ? TextDecoration.lineThrough : null,
          ),
        ),
        value: isChecked,
        activeColor: AppColors.safe,
        checkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: (bool? value) async {
          if (value == null) return;
          
          final updatedChecklist = Map<String, dynamic>.from(report.volunteerChecklist ?? {});
          updatedChecklist[title] = value;
          
          try {
            await _firestoreService.updateSOSChecklist(report.id, updatedChecklist);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Gagal mengemas kini: $e'), backgroundColor: AppColors.danger),
              );
            }
          }
        },
      ),
    );
  }
}
