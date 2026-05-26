import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../models/sos_report_model.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

/// Full-screen detail view for a volunteer to review and respond to an SOS.
class SosResponseScreen extends StatefulWidget {
  final String sosDocId;

  const SosResponseScreen({super.key, required this.sosDocId});

  @override
  State<SosResponseScreen> createState() => _SosResponseScreenState();
}

class _SosResponseScreenState extends State<SosResponseScreen> {
  final _firestoreService = FirestoreService();
  bool _isResponding = false;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final bool isOfficer = authState is AuthAuthenticated && authState.role == 'officer';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Detail Insiden',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sos_reports')
            .doc(widget.sosDocId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.volunteerAccent));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFound();
          }

          final report = SosReportModel.fromDocument(snapshot.data!);

          // If the user is an officer, let them view active or responded reports
          // If the report is resolved or cancelled, show inactive state
          if (isOfficer) {
            if (report.status == SosReportModel.statusResolved || report.status == SosReportModel.statusCancelled) {
              return _buildInactiveState(report);
            }
          } else {
            // For volunteers: If already cancelled or responded, show status
            if (report.status != SosReportModel.statusActive) {
              return _buildInactiveState(report);
            }
          }

          return _buildActiveReport(report);
        },
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text('Laporan tidak dijumpai',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Laporan SOS ini mungkin telah dibatalkan.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildInactiveState(SosReportModel report) {
    final authState = context.read<AuthBloc>().state;
    final bool isOfficer = authState is AuthAuthenticated && authState.role == 'officer';

    final isCancelled = report.status == SosReportModel.statusCancelled;
    final isResolved = report.status == SosReportModel.statusResolved;

    final Color color;
    if (isCancelled) {
      color = AppColors.textSecondary;
    } else if (isResolved) {
      color = AppColors.safe;
    } else {
      color = AppColors.volunteerAccent;
    }

    final IconData icon;
    if (isCancelled) {
      icon = Icons.cancel_rounded;
    } else if (isResolved) {
      icon = Icons.check_circle_rounded;
    } else {
      icon = Icons.handshake_rounded;
    }

    final String label;
    if (isCancelled) {
      label = 'Dibatalkan';
    } else if (isResolved) {
      label = 'Telah Diselesaikan';
    } else {
      label = 'Telah Direspons';
    }

    final String subtitle;
    if (isCancelled) {
      subtitle = report.cancelReason ?? 'Penggera palsu / Situasi terkawal';
    } else if (isResolved) {
      subtitle = 'Insiden ini telah selesai dan ditutup.';
    } else {
      subtitle = 'Direspons oleh ${report.responderName ?? 'sukarelawan'}';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 20),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOfficer ? AppColors.officerAccent : AppColors.volunteerAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  isOfficer ? 'Kembali ke Pusat Kawalan' : 'Kembali ke Papan Tugas',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveReport(SosReportModel report) {
    // Load volunteer skills for match display
    final authState = context.read<AuthBloc>().state;
    final volunteerSkills = <String>[];

    final urgencyColor = _urgencyColor(report.urgency);

    // Format time
    final timeAgo = report.createdAt != null
        ? _formatTimeAgo(report.createdAt!)
        : 'Baru sahaja';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Urgency banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: urgencyColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(_typeIcon(report.type), color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.type,
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(report.urgency,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(timeAgo,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Location & distance
        _detailCard(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.danger,
          title: 'Lokasi Insiden',
          children: [
            Text(report.address.isNotEmpty ? report.address : 'Tiada alamat',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
                'Koordinat: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),

        const SizedBox(height: 12),

        // Description
        _detailCard(
          icon: Icons.description_rounded,
          iconColor: AppColors.primary,
          title: 'Penerangan',
          children: [
            Text(
                report.description.isNotEmpty
                    ? report.description
                    : 'Tiada penerangan tambahan.',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.5)),
          ],
        ),

        const SizedBox(height: 12),

        // Required skills
        _detailCard(
          icon: Icons.psychology_rounded,
          iconColor: AppColors.volunteerAccent,
          title: 'Kemahiran Diperlukan',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.requiredSkills.map((skill) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.volunteerAccent.withOpacity(0.1),
                    border: Border.all(
                        color: AppColors.volunteerAccent.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(skill,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.volunteerAccent)),
                );
              }).toList(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Reporter info
        _detailCard(
          icon: Icons.person_rounded,
          iconColor: AppColors.safe,
          title: 'Maklumat Pelapor',
          children: [
            _infoRow('Nama', report.reporterName),
            if (report.reporterPhone.isNotEmpty)
              _infoRow('Telefon', report.reporterPhone),
            if (report.createdAt != null)
              _infoRow('Masa Laporan',
                  DateFormat('dd MMM yyyy, HH:mm').format(report.createdAt!)),
          ],
        ),

        const SizedBox(height: 32),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.divider, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Tolak',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                    _isResponding ? null : () => _confirmAccept(report),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.volunteerAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Terima Misi',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _detailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _confirmAccept(SosReportModel report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Terima Misi?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Anda akan direkodkan sebagai responder untuk insiden ${report.type} ini.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.volunteerAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.volunteerAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Tindakan ini tidak boleh dibatalkan setelah diterima.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.volunteerAccent)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tidak',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.volunteerAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _acceptMission(report);
            },
            child: Text('Ya, Terima',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptMission(SosReportModel report) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _isResponding = true);

    try {
      await _firestoreService.respondToSOS(
        report.id,
        authState.uid,
        authState.displayName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'Misi diterima! Sila bergerak ke lokasi insiden.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: AppColors.safe,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menerima misi: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case SosReportModel.urgencyKritikal:
        return const Color(0xFFDC2626);
      case SosReportModel.urgencyTinggi:
        return const Color(0xFFF97316);
      case SosReportModel.urgencySedang:
        return const Color(0xFFFBBF24);
      case SosReportModel.urgencyRendah:
        return const Color(0xFF22C55E);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Banjir':
        return Icons.water_drop_rounded;
      case 'Kebakaran':
        return Icons.local_fire_department_rounded;
      case 'Tanah Runtuh':
        return Icons.landscape_rounded;
      case 'Perubatan':
        return Icons.medical_services_rounded;
      case 'Orang Hilang':
        return Icons.person_search_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Baru sahaja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
