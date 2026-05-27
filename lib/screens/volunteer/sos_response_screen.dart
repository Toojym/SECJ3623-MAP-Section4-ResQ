import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final _locationService = LocationService();
  bool _isResponding = false;
  Position? _volunteerPosition;
  bool _isTogglingBackup = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _initVolunteerLocation();
  }

  Future<void> _initVolunteerLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _volunteerPosition = pos;
        });
      }
    } catch (_) {
      // Gracefully handle if GPS permission is not given
    }
  }

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
              if (report.status == SosReportModel.statusResponded &&
                  report.responderId == (authState is AuthAuthenticated ? authState.uid : '')) {
                return _buildAcceptedReport(report);
              }
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
                            color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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

        // Specific Details Card
        if (report.formattedSpecificDetails.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailCard(
            icon: Icons.assignment_turned_in_rounded,
            iconColor: AppColors.primary,
            title: 'Spesifikasi Darurat',
            children: [
              ...report.formattedSpecificDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      Text(entry.value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],

        if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailCard(
            icon: Icons.image_rounded,
            iconColor: Colors.teal,
            title: 'Gambar Bukti Kecemasan',
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: report.imageUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(report.imageUrl!.split(',').last),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      )
                    : Image.network(
                        report.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey[100],
                            alignment: Alignment.center,
                            child: Text(
                              'Gagal memuatkan gambar bukti.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],

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
                    color: AppColors.volunteerAccent.withValues(alpha: 0.1),
                    border: Border.all(
                        color: AppColors.volunteerAccent.withValues(alpha: 0.3)),
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
              color: Colors.black.withValues(alpha: 0.04),
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
                  color: iconColor.withValues(alpha: 0.1),
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
                color: AppColors.volunteerAccent.withValues(alpha: 0.08),
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

  Widget _buildAcceptedReport(SosReportModel report) {
    final urgencyColor = _urgencyColor(report.urgency);

    double distanceKm = 0.0;
    String distanceStr = 'Mengira jarak...';
    String etaStr = 'Anggaran masa ketibaan...';
    if (_volunteerPosition != null) {
      distanceKm = LocationService.calculateDistanceKm(
        _volunteerPosition!.latitude,
        _volunteerPosition!.longitude,
        report.latitude,
        report.longitude,
      );
      distanceStr = LocationService.formatDistance(distanceKm);
      final double travelTimeMinutes = (distanceKm / 40.0) * 60.0;
      final int roundedMinutes = travelTimeMinutes.round().clamp(2, 60);
      etaStr = '$roundedMinutes minit';
    }

    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('citizen_loc'),
        position: LatLng(report.latitude, report.longitude),
        infoWindow: InfoWindow(title: 'Mangsa: ${report.reporterName}', snippet: report.type),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (_volunteerPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('volunteer_loc'),
          position: LatLng(_volunteerPosition!.latitude, _volunteerPosition!.longitude),
          infoWindow: const InfoWindow(title: 'Lokasi Anda (Skuad Penyelamat)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.volunteerAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.volunteerAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_run_rounded, color: AppColors.volunteerAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Misi Sedang Berlangsung',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.volunteerAccent)),
                    const SizedBox(height: 2),
                    Text('Sila bergerak ke lokasi mangsa dengan berhati-hati.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Peta Navigasi Misi',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E3DF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          clipBehavior: Clip.hardEdge,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(report.latitude, report.longitude),
              zoom: 13.5,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: markers,
            onMapCreated: (_) {},
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Jarak ke Mangsa',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(distanceStr,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
              Container(width: 1.5, height: 36, color: AppColors.divider),
              Column(
                children: [
                  Text('Anggaran Masa Tiba',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(etaStr,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: report.needBackup
                ? AppColors.danger.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: report.needBackup
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                report.needBackup ? Icons.warning_amber_rounded : Icons.group_add_rounded,
                color: report.needBackup ? AppColors.danger : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bantuan Tambahan',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: report.needBackup ? AppColors.danger : AppColors.textPrimary)),
                    Text(
                      report.needBackup
                          ? 'Permintaan bantuan tambahan aktif. Pegawai kawalan telah dimaklumkan.'
                          : 'Adakah keadaan memerlukan lebih ramai penyelamat?',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _isTogglingBackup
                    ? null
                    : () async {
                        setState(() => _isTogglingBackup = true);
                        try {
                          await _firestoreService.updateSOSReportBackupRequest(
                              report.id, !report.needBackup);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(!report.needBackup
                                    ? 'Permintaan bantuan tambahan dihantar kepada Pegawai!'
                                    : 'Permintaan bantuan tambahan dibatalkan.'),
                                backgroundColor: !report.needBackup ? AppColors.danger : AppColors.safe,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ralat: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isTogglingBackup = false);
                        }
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: report.needBackup ? AppColors.danger : AppColors.primary,
                  side: BorderSide(
                    color: report.needBackup ? AppColors.danger : AppColors.primary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  report.needBackup ? 'Batal' : 'Minta',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _detailCard(
          icon: Icons.info_outline_rounded,
          iconColor: urgencyColor,
          title: 'Perincian Misi SOS',
          children: [
            _infoRow('Jenis Kecemasan', report.type),
            _infoRow('Alamat/Lokasi', report.address.isNotEmpty ? report.address : 'Koordinat Sahaja'),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Penerangan Mangsa:',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(report.description,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
            ],
            if (report.reporterPhone.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('tel:${report.reporterPhone}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tidak dapat membuka panggilan telefon.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.call_rounded, size: 20),
                  label: Text('Hubungi Mangsa', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safe,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),

        // Specific Details Card
        if (report.formattedSpecificDetails.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailCard(
            icon: Icons.assignment_turned_in_rounded,
            iconColor: AppColors.primary,
            title: 'Spesifikasi Darurat',
            children: [
              ...report.formattedSpecificDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      Text(entry.value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
        if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailCard(
            icon: Icons.image_rounded,
            iconColor: Colors.teal,
            title: 'Gambar Bukti Kecemasan',
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: report.imageUrl!.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(report.imageUrl!.split(',').last),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      )
                    : Image.network(
                        report.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey[100],
                            alignment: Alignment.center,
                            child: Text(
                              'Gagal memuatkan gambar bukti.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _detailCard(
          icon: Icons.person_rounded,
          iconColor: AppColors.safe,
          title: 'Hubungi Mangsa',
          children: [
            _infoRow('Nama Mangsa', report.reporterName),
            if (report.reporterPhone.isNotEmpty)
              _infoRow('No. Telefon', report.reporterPhone),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showCallingSimulationOverlay(context, report.reporterName);
                },
                icon: const Icon(Icons.phone_rounded, size: 16),
                label: const Text('Panggil Telefon Mangsa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.safe,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isCompleting
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Selesaikan Misi?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        content: Text('Adakah semua tindakan menyelamat telah diambil dan kes ini boleh ditutup?',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.safe,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Ya, Selesai', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      setState(() => _isCompleting = true);
                      try {
                        await _firestoreService.resolveSOSReportByVolunteer(report.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Misi diselesaikan dengan jaya!'),
                              backgroundColor: AppColors.safe,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ralat: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isCompleting = false);
                      }
                    }
                  },
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
            label: const Text('SELESAIKAN MISI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.safe,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ── Voice Call Simulation Overlay ─────────────────────────────────────────

  void _showCallingSimulationOverlay(BuildContext context, String targetName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return _CallSimulationScreen(
          targetName: targetName,
          roleAccent: AppColors.volunteerAccent,
        );
      },
    );
  }
}

class _CallSimulationScreen extends StatefulWidget {
  final String targetName;
  final Color roleAccent;

  const _CallSimulationScreen({
    required this.targetName,
    required this.roleAccent,
  });

  @override
  State<_CallSimulationScreen> createState() => _CallSimulationScreenState();
}

class _CallSimulationScreenState extends State<_CallSimulationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Simulate connection delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isConnected ? 'PANGGILAN AKTIF' : 'MENYAMBUNGKAN TALIAN...';
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'SIGAP VOICE BROADCAST',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white60,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isConnected ? AppColors.safe.withValues(alpha: 0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isConnected ? AppColors.safe.withValues(alpha: 0.5) : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isConnected ? AppColors.safe : AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Animated Sound Waves and Contact avatar
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer concentric ripple circles
                  ...List.generate(3, (index) {
                    final double delay = index * 0.5;
                    return AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        final double progress = (_rippleController.value + delay) % 1.0;
                        final double size = 120 + (progress * 160);
                        final double opacity = (1.0 - progress) * 0.4;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.roleAccent.withValues(alpha: opacity),
                          ),
                        );
                      },
                    );
                  }),
                  
                  // Central contact circle
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, color: widget.roleAccent, size: 40),
                          if (_isConnected) ...[
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(_secondsElapsed),
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Contact Name & Info
              Column(
                children: [
                  Text(
                    widget.targetName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Menghubungkan anda dengan penyelamat berhampiran melalui talian audio satelit.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                ],
              ),

              // Interactive Call Buttons
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      _buildRoundOptionButton(
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        isActive: _isMuted,
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                      ),
                      
                      // Hang up Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                        ),
                      ),

                      // Speaker Button
                      _buildRoundOptionButton(
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        isActive: _isSpeaker,
                        onTap: () {
                          setState(() {
                            _isSpeaker = !_isSpeaker;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundOptionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black.withValues(alpha: 0.8) : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
