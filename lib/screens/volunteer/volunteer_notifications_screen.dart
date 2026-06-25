import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../core/constants/app_routes.dart';
import '../../models/sos_report_model.dart';
import 'package:easy_localization/easy_localization.dart';

class VolunteerNotificationsScreen extends StatefulWidget {
  const VolunteerNotificationsScreen({super.key});

  @override
  State<VolunteerNotificationsScreen> createState() => _VolunteerNotificationsScreenState();
}

class _VolunteerNotificationsScreenState extends State<VolunteerNotificationsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return AppStrings.volunteerBaruSahaja;
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.uid : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppStrings.volunteerPemberitahuanMisi,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppStrings.volunteerNotifikasiUmum,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamGlobalNotifications(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(AppStrings.volunteerTiadaNotifikasiUmum, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notif = docs[index].data() as Map<String, dynamic>;
                    final type = notif['type'] as String? ?? 'info';
                    
                    Color typeColor = AppColors.primary;
                    IconData typeIcon = Icons.info_outline_rounded;
                    if (type == 'warning') {
                      typeColor = AppColors.danger;
                      typeIcon = Icons.warning_rounded;
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(typeIcon, color: typeColor, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notif['title'] as String? ?? 'Notifikasi'.tr(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notif['message'] as String? ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDate(notif['timestamp'] as Timestamp?),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                AppStrings.volunteerMisiSosTerkini,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.streamActiveSOSReports(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.volunteerAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var reports = snapshot.data!.docs
                    .map((doc) => SosReportModel.fromDocument(doc))
                    .where((r) => !r.declinedBy.contains(uid))
                    .toList();

                reports.sort((a, b) {
                  return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
                });

                if (reports.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _buildNotificationCard(report);
                  },
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            AppStrings.volunteerTiadaPemberitahuanBaru,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.volunteerKawasanAndaSelamatBuat,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(SosReportModel report) {
    Color severityColor;
    switch (report.urgency) {
      case SosReportModel.urgencyKritikal:
        severityColor = const Color(0xFFDC2626);
        break;
      case SosReportModel.urgencyTinggi:
        severityColor = const Color(0xFFF97316);
        break;
      case SosReportModel.urgencySedang:
        severityColor = const Color(0xFFFBBF24);
        break;
      default:
        severityColor = const Color(0xFF22C55E);
    }

    return GestureDetector(
      onTap: () => context.push(AppRoutes.sosResponse, extra: report.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: severityColor.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_rounded, color: severityColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'volunteerNewmissiontype'.tr(args: [report.type]),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.address.isNotEmpty ? report.address : AppStrings.volunteerLokasiKoordinat,
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(report.createdAt != null ? Timestamp.fromDate(report.createdAt!) : null),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: severityColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
