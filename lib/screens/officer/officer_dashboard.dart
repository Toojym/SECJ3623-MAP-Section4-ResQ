import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/sos_report_model.dart';
import '../../models/claim_model.dart';
import '../../models/campaign_model.dart';
import '../../models/volunteer_task_model.dart';
import '../../services/authority_routing_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/sigap_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class OfficerDashboard extends StatefulWidget {
  const OfficerDashboard({super.key});

  @override
  State<OfficerDashboard> createState() => _OfficerDashboardState();
}

class _OfficerDashboardState extends State<OfficerDashboard> {
  int _currentIndex = 0;
  String? _profileImageUrl;

  final _firestoreService = FirestoreService();

  final CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(3.1390, 101.6869), // KL Center
    zoom: 8.0,
  );

  // Filters State for Krisis Tab
  String _filterUrgency = 'Semua';
  String _filterType = 'Semua';
  String _filterDuration = 'Semua';

  // Disaster Zone State
  bool _isSelectingDisasterZone = false;
  LatLng? _selectedDisasterEpicenter;
  double _disasterRadius = 5000.0; // meters
  String _disasterType = 'Banjir';
  final TextEditingController _disasterNameController = TextEditingController();
  final List<Circle> _disasterZones = [];
  String? _selectedBulkClaimZone;

  // Live SOS reports from Firestore (replaces _mockIncidents)
  List<SosReportModel> _activeReports = [];

  @override
  void dispose() {
    _disasterNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOfficerData();
  }

  Future<void> _loadOfficerData() async {
    final state = context.read<AuthBloc>().state;
    if (state is AuthAuthenticated) {
      try {
        final data = await _firestoreService.getOfficerProfile(state.uid);
        if (data != null && mounted) {
          setState(() {
            _profileImageUrl = data['profileImageUrl'] as String?;
          });
        }
      } catch (e) {
        debugPrint('Error loading officer data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.displayName : '';
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: SigapAppBar(
            title: AppStrings.appName,
            showLogout: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded,
                    color: AppColors.warning),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => context.push(AppRoutes.officerProfile),
              ),
            ],
          ),
          body: _buildBody(name),
          bottomNavigationBar: _buildBottomAppBar(),
        );
      },
    );
  }

  Widget _buildBody(String name) {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab(name);
      case 1:
        return _buildCrisisTab();
      case 2:
        return _buildVolunteerTab();
      case 3:
        return _buildAwanisTab();
      case 4:
        return _buildClaimsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── BOTTOM APP BAR ───────────────────────────────────────────────
  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppColors.surface,
      elevation: 20,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: SizedBox(
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard_rounded, 'Utama', 0),
            _navItem(Icons.warning_amber_rounded, 'Krisis', 1),
            _navItem(Icons.group_rounded, 'Skuad', 2),
            _navItem(Icons.smart_toy_rounded, 'AWANIS', 3),
            _navItem(Icons.receipt_long_rounded, 'Tuntutan', 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color =
        isSelected ? AppColors.officerAccent : AppColors.textSecondary;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: color)),
          ],
        ),
      ),
    );
  }

  // ─── UTAMA (HOME) TAB ─────────────────────────────────────────────
  Widget _buildHomeTab(String name) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCommandCard(name),
        const SizedBox(height: 16),
        _buildStatsRow(),
        const SizedBox(height: 24),
        _sectionTitle('Modul & Ciri Tambahan'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _moduleCard('Laporan Analitik', Icons.analytics_rounded,
                    AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: _moduleCard(
                    'Modul Tambahan', Icons.extension_rounded, Colors.teal)),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Kempen Derma Aktif'),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamActiveCampaigns(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.hasData ? snapshot.data!.docs.toList() : [];
            if (docs.isEmpty) {
              return Container(
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text('Tiada kempen aktif',
                    style: GoogleFonts.inter(color: AppColors.textSecondary)),
              );
            }
            docs.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            return SizedBox(
              height: 262,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final campaign = CampaignModel.fromMap(docs[index].id, data);
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 320,
                      child: _donationCampaignCard(campaign),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _createCampaignDialog,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Cipta Kempen Baru'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle('Soalan Lazim (FAQ)'),
        const SizedBox(height: 12),
        _faqCard('Panduan Pengisytiharan Darurat'),
        _faqCard('Prosedur Penugasan Sukarelawan'),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _moduleCard(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _faqCard(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textPrimary)),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
  }

  // ─── KRISIS (SOS & MAP) TAB ───────────────────────────────────────
  Widget _buildCrisisTab() {
    return StreamBuilder(
      stream: _firestoreService.streamDisasterZones(),
      builder: (context, zoneSnapshot) {
        if (zoneSnapshot.hasData) {
          _disasterZones.clear();
          for (final doc in zoneSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lat = (data['epicenterLat'] as num).toDouble();
            final lng = (data['epicenterLng'] as num).toDouble();
            final rad = (data['radius'] as num).toDouble();
            _disasterZones.add(
              Circle(
                circleId: CircleId(doc.id),
                center: LatLng(lat, lng),
                radius: rad,
                fillColor: AppColors.danger.withValues(alpha: 0.2),
                strokeColor: AppColors.danger,
                strokeWidth: 2,
              ),
            );
          }
        }

        return StreamBuilder(
          stream: _firestoreService.streamAllActiveSOSReportsForOfficer(),
          builder: (context, snapshot) {
            // Update local state from stream
            if (snapshot.hasData) {
              _activeReports = snapshot.data!.docs
                  .map((doc) => SosReportModel.fromDocument(doc))
                  .toList();
              // Sort locally: newest first
              _activeReports.sort((a, b) {
                final aTime = a.createdAt ?? DateTime(2000);
                final bTime = b.createdAt ?? DateTime(2000);
                return bTime.compareTo(aTime);
              });
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Heatmap Krisis',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                // Declare Disaster Zone button / selection UI
                SizedBox(
                  width: double.infinity,
                  child: _isSelectingDisasterZone
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_selectedDisasterEpicenter == null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: AppColors.warning)),
                                child: Text(
                                    'Sila tap pada peta untuk memilih pusat zon darurat.',
                                    style: GoogleFonts.inter(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              )
                            else ...[
                              Text('Radius Zon: ${_disasterRadius / 1000} km',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textPrimary)),
                              Slider(
                                value: _disasterRadius,
                                min: 1000,
                                max: 20000,
                                divisions: 19,
                                activeColor: AppColors.danger,
                                label: '${_disasterRadius / 1000} km',
                                onChanged: (val) {
                                  setState(() {
                                    _disasterRadius = val;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _disasterType,
                                decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    labelText: 'Jenis Bencana',
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8)),
                                items: [
                                  'Banjir',
                                  'Tanah Runtuh',
                                  'Kebakaran',
                                  'Lain-lain'
                                ]
                                    .map((t) => DropdownMenuItem(
                                        value: t, child: Text(t)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _disasterType = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _disasterNameController,
                                decoration: InputDecoration(
                                    labelText: 'Nama / Butiran Zon',
                                    hintText: 'Contoh: Banjir Kilat Seksyen 7',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12)),
                                maxLines: 1,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isSelectingDisasterZone = false;
                                        _selectedDisasterEpicenter = null;
                                        _disasterRadius = 5000.0;
                                        _disasterNameController.clear();
                                      });
                                    },
                                    child: const Text('Batal'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        _selectedDisasterEpicenter == null ||
                                                _disasterNameController.text
                                                    .trim()
                                                    .isEmpty
                                            ? null
                                            : _confirmDisasterZone,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.danger),
                                    child: const Text('Teruskan',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: _declareDisasterZone,
                          icon: const Icon(Icons.campaign_rounded, size: 18),
                          label: const Text('Isytihar Darurat (Zon Bencana)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                ),
                // Filter row
                if (!_isSelectingDisasterZone)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterDropdown(
                          label: 'Tahap',
                          value: _filterUrgency,
                          items: [
                            'Semua',
                            SosReportModel.urgencyKritikal,
                            SosReportModel.urgencyTinggi,
                            SosReportModel.urgencySedang,
                            SosReportModel.urgencyRendah,
                          ],
                          onChanged: (v) => setState(() => _filterUrgency = v!),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterDropdown(
                          label: 'Jenis',
                          value: _filterType,
                          items: [
                            'Semua',
                            'Banjir',
                            'Tanah Runtuh',
                            'Kebakaran',
                            'Perubatan',
                            'Orang Hilang',
                          ],
                          onChanged: (v) => setState(() => _filterType = v!),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterDropdown(
                          label: 'Masa',
                          value: _filterDuration,
                          items: [
                            'Semua',
                            '< 1 Hari',
                            '< 3 Hari',
                            '> 3 Hari',
                          ],
                          onChanged: (v) =>
                              setState(() => _filterDuration = v!),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Google Maps
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E3DF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _isSelectingDisasterZone
                            ? AppColors.danger
                            : AppColors.divider,
                        width: _isSelectingDisasterZone ? 2 : 1),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: _kInitialPosition,
                        onMapCreated: (_) {},
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        mapToolbarEnabled: false,
                        zoomControlsEnabled: true,
                        markers:
                            _buildMarkersFromReports(_getFilteredReports()),
                        circles: _buildCircles(),
                        onTap: (LatLng location) {
                          if (_isSelectingDisasterZone) {
                            setState(() {
                              _selectedDisasterEpicenter = location;
                            });
                          }
                        },
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Text('Siaran Langsung',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle('Insiden Aktif & Penyelesaian'),
                    InkWell(
                      onTap: _showHistoryDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'History',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.officerAccent,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.officerAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stream loading / error / empty states
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                        color: AppColors.officerAccent),
                  ))
                else if (snapshot.hasError)
                  _buildFirestoreError(snapshot.error.toString())
                else
                  _buildIncidentList(_getFilteredReports()),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  List<SosReportModel> _getFilteredReports() {
    var reports = List<SosReportModel>.from(_activeReports);

    if (_filterUrgency != 'Semua') {
      reports = reports.where((r) => r.urgency == _filterUrgency).toList();
    }
    if (_filterType != 'Semua') {
      reports = reports.where((r) => r.type == _filterType).toList();
    }
    if (_filterDuration != 'Semua') {
      final now = DateTime.now();
      reports = reports.where((r) {
        if (r.createdAt == null) return true;
        final diff = now.difference(r.createdAt!);
        if (_filterDuration == '< 1 Hari') return diff.inDays < 1;
        if (_filterDuration == '< 3 Hari') return diff.inDays < 3;
        if (_filterDuration == '> 3 Hari') return diff.inDays >= 3;
        return true;
      }).toList();
    }
    return reports;
  }

  Widget _buildFirestoreError(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Text('Gagal memuatkan laporan Firestore',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(
              'Semak Firebase Security Rules anda: allow read di sos_reports bagi pengguna yang log masuk.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          // Fallback: show mock data
          Text('Menunjukkan data ujian sementara:',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildIncidentList(List<SosReportModel> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 48, color: AppColors.safe),
              const SizedBox(height: 12),
              Text('Tiada insiden aktif ditemui.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: reports
          .map((report) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Dismissible(
                  key: Key(report.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: AppColors.safe,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await _confirmResolveDialog(report);
                  },
                  onDismissed: (direction) {
                    _resolveIncident(report);
                  },
                  child: _resolvableSOSCard(report),
                ),
              ))
          .toList(),
    );
  }

  Set<Marker> _buildMarkersFromReports(List<SosReportModel> reports) {
    return reports.map((report) {
      double hue = BitmapDescriptor.hueRed; // KRITIKAL default
      if (report.urgency == SosReportModel.urgencyTinggi) {
        hue = BitmapDescriptor.hueOrange;
      } else if (report.urgency == SosReportModel.urgencySedang) {
        hue = BitmapDescriptor.hueYellow;
      } else if (report.urgency == SosReportModel.urgencyRendah) {
        hue = BitmapDescriptor.hueGreen;
      }

      Color markerColor = AppColors.danger;
      if (report.urgency == SosReportModel.urgencyTinggi) {
        markerColor = AppColors.warning;
      } else if (report.urgency == SosReportModel.urgencySedang) {
        markerColor = const Color(0xFFFBBF24);
      } else if (report.urgency == SosReportModel.urgencyRendah) {
        markerColor = AppColors.safe;
      }

      IconData icon = _typeIcon(report.type);

      return Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude, report.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: '${report.type} — ${report.urgency}',
          snippet: report.address.isNotEmpty
              ? report.address
              : '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
          onTap: () => _showSOSDetails(report, markerColor, icon),
        ),
      );
    }).toSet();
  }

  Set<Circle> _buildCircles() {
    final Set<Circle> circles = {};
    for (int i = 0; i < _disasterZones.length; i++) {
      circles.add(_disasterZones[i]);
    }

    // Add glowing halos for active SOS reports matching urgency levels
    for (final report in _getFilteredReports()) {
      Color markerColor = AppColors.danger;
      if (report.urgency == SosReportModel.urgencyTinggi) {
        markerColor = AppColors.warning;
      } else if (report.urgency == SosReportModel.urgencySedang) {
        markerColor = const Color(0xFFFBBF24);
      } else if (report.urgency == SosReportModel.urgencyRendah) {
        markerColor = AppColors.safe;
      }

      circles.add(
        Circle(
          circleId: CircleId('glow_sos_${report.id}'),
          center: LatLng(report.latitude, report.longitude),
          radius: 300,
          fillColor: markerColor.withValues(alpha: 0.18),
          strokeColor: markerColor.withValues(alpha: 0.5),
          strokeWidth: 1,
        ),
      );
    }

    if (_isSelectingDisasterZone && _selectedDisasterEpicenter != null) {
      circles.add(
        Circle(
          circleId: const CircleId('preview_zone'),
          center: _selectedDisasterEpicenter!,
          radius: _disasterRadius,
          fillColor: AppColors.danger.withValues(alpha: 0.3),
          strokeColor: AppColors.danger,
          strokeWidth: 2,
        ),
      );
    }
    return circles;
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: value != 'Semua'
            ? AppColors.officerAccent.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
            color:
                value != 'Semua' ? AppColors.officerAccent : AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.arrow_drop_down,
              color: value != 'Semua'
                  ? AppColors.officerAccent
                  : AppColors.textSecondary),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: value != 'Semua' ? FontWeight.w600 : FontWeight.w500,
            color: value != 'Semua'
                ? AppColors.officerAccent
                : AppColors.textSecondary,
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item == 'Semua' ? '$label: Semua' : item),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _declareDisasterZone() {
    setState(() {
      _isSelectingDisasterZone = true;
    });
  }

  void _confirmDisasterZone() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Isytihar Zon Darurat',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger)),
          ],
        ),
        content: Text(
          'Tindakan ini akan menghantar amaran kecemasan (push alerts) secara meluas kepada semua rakyat di dalam radius ${_disasterRadius / 1000}km dari pusat yang dipilih. Teruskan?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              final epicenter = _selectedDisasterEpicenter!;
              Navigator.pop(ctx);

              _firestoreService.createDisasterZone({
                'epicenterLat': epicenter.latitude,
                'epicenterLng': epicenter.longitude,
                'radius': _disasterRadius,
                'type': _disasterType,
                'name': _disasterNameController.text.trim(),
              }).then((_) {
                int affectedCount =
                    _calculateAffectedUsers(epicenter, _disasterRadius);
                if (mounted) {
                  setState(() {
                    _isSelectingDisasterZone = false;
                    _selectedDisasterEpicenter = null;
                    _disasterRadius = 5000.0;
                    _disasterNameController.clear();
                  });
                  _showGeofenceSuccessDialog(affectedCount);
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Ralat menyimpan zon: $e'),
                      backgroundColor: AppColors.danger));
                }
              });
            },
            child: Text('Sah & Hantar',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  int _calculateAffectedUsers(LatLng center, double radiusInMeters) {
    int affectedReports = 0;
    for (final report in _activeReports) {
      if (_calculateDistance(center.latitude, center.longitude, report.latitude,
              report.longitude) <=
          radiusInMeters) {
        affectedReports++;
      }
    }
    return affectedReports > 0
        ? (affectedReports * 124)
        : (radiusInMeters / 10).round();
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371e3;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  void _showGeofenceSuccessDialog(int totalReached) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.podcasts_rounded, color: AppColors.safe, size: 40),
            const SizedBox(height: 12),
            Text('Amaran Darurat Dihantar!',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          'Sistem geofencing SIGAP telah berjaya memancarkan Push Alerts kepada anggaran $totalReached peranti pengguna awam di dalam radius sasaran.',
          style:
              GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx),
            child: Text('Tutup',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveIncident(SosReportModel report) async {
    try {
      await _firestoreService.resolveSOSReportByOfficer(report.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Insiden ${report.type} di ${report.address.isNotEmpty ? report.address : "lokasi insiden"} diselesaikan.'),
            backgroundColor: AppColors.safe));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal menyelesaikan insiden: $e'),
            backgroundColor: AppColors.danger));
      }
    }
  }

  Future<bool> _confirmResolveDialog(SosReportModel report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Selesaikan Insiden?',
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text(
            'Adakah anda pasti ingin menyelesaikan kes ini?\n\n"${report.type} — ${report.address.isNotEmpty ? report.address : report.urgency}"',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.safe),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ya, Selesai',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSOSDetails(SosReportModel report, Color color, IconData icon) {
    String selectedSquad = 'Skuad Alpha';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateSheet) => DraggableScrollableSheet(
          initialChildSize:
              report.status == SosReportModel.statusActive ? 0.75 : 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.type,
                              style: GoogleFonts.poppins(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(
                              report.address.isNotEmpty
                                  ? report.address
                                  : '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _detailBadge('Keutamaan', report.urgency, color),
                    const SizedBox(width: 12),
                    _detailBadge(
                        'Status', report.status, AppColors.officerAccent),
                  ],
                ),
                const SizedBox(height: 16),
                if (report.description.isNotEmpty) ...[
                  Text('Keterangan',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text(report.description,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5)),
                  const SizedBox(height: 16),
                ],
                if (report.reporterName.isNotEmpty) ...[
                  Text('Pelapor: ${report.reporterName}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                ],
                if (report.imageUrl != null && report.imageUrl!.isNotEmpty) ...[
                  Text('Gambar Bukti Kecemasan',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
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
                                  style: GoogleFonts.inter(
                                      color: AppColors.textSecondary),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Show dispatch section if status is active
                if (report.status == SosReportModel.statusActive) ...[
                  const Divider(height: 32),
                  Text('Agih Skuad Bantuan (Manual Dispatch)',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSquad,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppColors.officerAccent),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'Skuad Alpha',
                          child: Text('Skuad Alpha (Penyelamat)')),
                      DropdownMenuItem(
                          value: 'Skuad Delta',
                          child: Text('Skuad Delta (Perubatan)')),
                      DropdownMenuItem(
                          value: 'Skuad Charlie',
                          child: Text('Skuad Charlie (Logistik)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setStateSheet(() {
                          selectedSquad = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        try {
                          await _firestoreService.respondToSOS(
                            report.id,
                            'officer_dispatch_${selectedSquad.replaceAll(" ", "_").toLowerCase()}',
                            selectedSquad,
                          );
                          if (navigator.mounted) {
                            navigator.pop();
                          }
                          scaffoldMessenger.showSnackBar(SnackBar(
                            content: Text(
                                'Berjaya mengagihkan $selectedSquad ke lokasi krisis.'),
                            backgroundColor: AppColors.safe,
                          ));
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(SnackBar(
                            content: Text('Gagal mengagihkan skuad: $e'),
                            backgroundColor: AppColors.danger,
                          ));
                        }
                      },
                      icon: const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Hantar Skuad Sekarang',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.officerAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Show responder details & backup warnings if status is responded
                if (report.status == SosReportModel.statusResponded) ...[
                  const Divider(height: 32),
                  Text('Maklumat Respon / Menyelamat',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.engineering_rounded,
                            color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RESPONDER',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                report.responderName ?? 'Sukarelawan',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (report.needBackup) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: AppColors.danger, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BANTUAN TAMBAHAN DIPERLUKAN',
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.danger),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Responder di lokasi telah meminta bantuan unit tambahan/squad sokongan segera.',
                                  style: GoogleFonts.inter(
                                      fontSize: 12, color: AppColors.danger),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Tutup',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sejarah Insiden Selesai',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder(
                stream: _firestoreService.streamResolvedSOSReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.officerAccent));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                        child: Text('Tiada sejarah insiden ditemui.',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary)));
                  }
                  final resolved =
                      docs.map((d) => SosReportModel.fromDocument(d)).toList();
                  return ListView.builder(
                    itemCount: resolved.length,
                    itemBuilder: (context, index) {
                      final r = resolved[index];
                      return ListTile(
                        leading: const Icon(Icons.check_circle_rounded,
                            color: AppColors.safe),
                        title: Text(r.type,
                            style:
                                GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            r.address.isNotEmpty ? r.address : r.reporterName,
                            style: GoogleFonts.inter(fontSize: 12)),
                        trailing: Text(r.urgency,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textPrimary)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resolvableSOSCard(SosReportModel report) {
    Color color = AppColors.primary;
    IconData icon = Icons.warning_amber_rounded;

    switch (report.urgency) {
      case SosReportModel.urgencyKritikal:
        color = AppColors.danger;
        break;
      case SosReportModel.urgencyTinggi:
        color = AppColors.warning;
        break;
      case SosReportModel.urgencySedang:
        color = const Color(0xFFFBBF24);
        break;
      case SosReportModel.urgencyRendah:
        color = AppColors.safe;
        break;
    }
    icon = _typeIcon(report.type);

    // Duration string
    String duration = '';
    if (report.createdAt != null) {
      final diff = DateTime.now().difference(report.createdAt!);
      if (diff.inMinutes < 60) {
        duration = '${diff.inMinutes} minit lalu';
      } else if (diff.inHours < 24) {
        duration = '${diff.inHours} jam lalu';
      } else {
        duration = '${diff.inDays} hari lalu';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showSOSDetails(report, color, icon),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${report.type}${report.address.isNotEmpty ? " — ${report.address}" : ""}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              duration.isNotEmpty
                                  ? 'Durasi: $duration'
                                  : 'Pelapor: ${report.reporterName}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99)),
                      child: Text(report.urgency,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Authority Routing Badge
                Builder(builder: (_) {
                  final authority = AuthorityRoutingService.instance.getAuthority(report.type);
                  return Row(
                    children: [
                      Icon(authority.icon, size: 13, color: authority.color),
                      const SizedBox(width: 4),
                      Text(
                        'Dihalakan: ${authority.shortName}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: authority.color),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => AuthorityRoutingService.instance.callAuthority(authority),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: authority.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: authority.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_rounded, size: 11, color: authority.color),
                              const SizedBox(width: 3),
                              Text(authority.phone, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: authority.color)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (report.status == SosReportModel.statusResponded ||
                    report.needBackup) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.engineering_rounded,
                              size: 14, color: AppColors.officerAccent),
                          const SizedBox(width: 4),
                          Text(
                            'Responded by: ${report.responderName ?? "Penyelamat"}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      if (report.needBackup)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.2))),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_rounded,
                                  size: 10, color: AppColors.danger),
                              const SizedBox(width: 4),
                              Text(
                                'Perlu Bantuan',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await _confirmResolveDialog(report);
                      if (confirm && mounted) {
                        _resolveIncident(report);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18),
                    label: const Text('Selesaikan Insiden'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.safe,
                      side: const BorderSide(color: AppColors.safe),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── SKUAD (VOLUNTEER) TAB ────────────────────────────────────────
  Widget _buildVolunteerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Penugasan Skuad',
            style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _assignVolunteerDialog,
            icon: const Icon(Icons.group_add_rounded, size: 18),
            label: const Text('Agih Skuad (Assign Squad)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.volunteerAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.streamVolunteerTasks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.hasData ? snapshot.data!.docs.toList() : [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider)),
                child: Text('Tiada skuad ditugaskan.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary)),
              );
            }
            docs.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final task = VolunteerTaskModel.fromMap(doc.id, data);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _volunteerSquadCard(task),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _assignVolunteerDialog() {
    String selectedSquad = 'Skuad Bravo (Pembersihan)';
    String selectedZone = 'Zon Banjir Ampang';
    String selectedPriority = 'Sederhana';
    final volunteerCtrl = TextEditingController();
    final taskCtrl = TextEditingController();
    final etaCtrl = TextEditingController(text: '15 min');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Agih Skuad Baru',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.volunteerAccent)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      labelText: 'Pilih Skuad'),
                  value: selectedSquad,
                  items: const [
                    DropdownMenuItem(
                        value: 'Skuad Bravo (Pembersihan)',
                        child: Text('Skuad Bravo (Pembersihan)')),
                    DropdownMenuItem(
                        value: 'Skuad Echo (Dapur Jalanan)',
                        child: Text('Skuad Echo (Dapur Jalanan)')),
                    DropdownMenuItem(
                        value: 'Skuad Delta (Perubatan)',
                        child: Text('Skuad Delta (Perubatan)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selectedSquad = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      labelText: 'Lokasi Tugasan'),
                  value: selectedZone,
                  items: const [
                    DropdownMenuItem(
                        value: 'Zon Banjir Ampang',
                        child: Text('Zon Banjir Ampang')),
                    DropdownMenuItem(
                        value: 'PPS Hulu Langat',
                        child: Text('PPS Hulu Langat')),
                    DropdownMenuItem(
                        value: 'Zon Tanah Runtuh Gombak',
                        child: Text('Zon Tanah Runtuh Gombak')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selectedZone = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      labelText: 'Keutamaan Insiden'),
                  value: selectedPriority,
                  items: const [
                    DropdownMenuItem(
                        value: 'Kritikal', child: Text('Kritikal')),
                    DropdownMenuItem(value: 'Tinggi', child: Text('Tinggi')),
                    DropdownMenuItem(
                        value: 'Sederhana', child: Text('Sederhana')),
                    DropdownMenuItem(value: 'Rendah', child: Text('Rendah')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selectedPriority = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: volunteerCtrl,
                  decoration: InputDecoration(
                      labelText: 'Nama / ID Sukarelawan Bertugas',
                      hintText: 'Contoh: Amir, Siti, Team Medic-02',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taskCtrl,
                  decoration: InputDecoration(
                      labelText: 'Tugasan Khusus',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: etaCtrl,
                  decoration: InputDecoration(
                      labelText: 'Anggaran Tiba (ETA)',
                      hintText: 'Contoh: 15 min',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal',
                    style: GoogleFonts.inter(color: AppColors.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.volunteerAccent),
              onPressed: () async {
                if (taskCtrl.text.isEmpty) return;
                final coords = _zoneCoordinates(selectedZone);
                final model = VolunteerTaskModel(
                  id: '',
                  squadName: selectedSquad,
                  zone: selectedZone,
                  priority: selectedPriority,
                  status: 'Menuju ke Lokasi',
                  progress: 0.1,
                  taskDescription: taskCtrl.text,
                  assignedVolunteer: volunteerCtrl.text.trim().isEmpty
                      ? 'Skuad penuh'
                      : volunteerCtrl.text.trim(),
                  eta: etaCtrl.text.trim().isEmpty ? '-' : etaCtrl.text.trim(),
                  lastKnownLocation: selectedZone,
                  currentLat: coords.latitude,
                  currentLng: coords.longitude,
                );
                await _firestoreService.createVolunteerTask(model.toMap());
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Skuad berjaya diagihkan!')));
                }
              },
              child: Text('Agih Pasukan',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }),
    );
  }

  LatLng _zoneCoordinates(String zone) {
    final normalized = zone.toLowerCase();
    if (normalized.contains('ampang')) return const LatLng(3.1490, 101.7620);
    if (normalized.contains('hulu langat')) {
      return const LatLng(3.0948, 101.8187);
    }
    if (normalized.contains('gombak')) return const LatLng(3.2521, 101.6530);
    if (normalized.contains('sri petaling')) {
      return const LatLng(3.0705, 101.6920);
    }
    return const LatLng(3.1390, 101.6869);
  }

  void _redirectVolunteerDialog(VolunteerTaskModel task) {
    String newZone = 'Kecemasan: Runtuhan Gombak';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tukar Lokasi Skuad',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Arahkan semula ${task.squadName} ke zon baharu?',
                    style: GoogleFonts.inter(fontSize: 14)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      labelText: 'Lokasi Baharu'),
                  value: newZone,
                  items: const [
                    DropdownMenuItem(
                        value: 'Kecemasan: Runtuhan Gombak',
                        child: Text('Kecemasan: Runtuhan Gombak')),
                    DropdownMenuItem(
                        value: 'Bantuan: PPS Sri Petaling',
                        child: Text('Bantuan: PPS Sri Petaling')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => newZone = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal',
                    style: GoogleFonts.inter(color: AppColors.textSecondary))),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () async {
                final coords = _zoneCoordinates(newZone);
                await _firestoreService.updateVolunteerTask(task.id, {
                  'zone': newZone,
                  'status': 'Menuju ke Lokasi',
                  'progress': 0.1,
                  'currentLat': coords.latitude,
                  'currentLng': coords.longitude,
                  'lastKnownLocation': newZone,
                  'eta': '20 min',
                });
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${task.squadName} diarahkan ke lokasi baharu.')));
                }
              },
              child: Text('Ubah Lokasi',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }),
    );
  }

  Widget _volunteerSquadCard(VolunteerTaskModel task) {
    Color statusColor = Colors.orange;
    if (task.status == 'Sedang Bertugas') statusColor = Colors.green;
    if (task.status == 'Selesai Tugas') statusColor = Colors.blue;
    final priorityColor =
        task.priority == 'Kritikal' || task.priority == 'Tinggi'
            ? AppColors.danger
            : task.priority == 'Rendah'
                ? AppColors.safe
                : AppColors.warning;
    final coordinates = task.currentLat != null && task.currentLng != null
        ? '${task.currentLat!.toStringAsFixed(4)}, ${task.currentLng!.toStringAsFixed(4)}'
        : 'Belum disegerakkan';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.group_rounded,
                        color: AppColors.volunteerAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(task.squadName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99)),
                child: Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(task.status,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _trackingChip(
                  Icons.priority_high_rounded, task.priority, priorityColor),
              _trackingChip(
                  Icons.person_pin_circle_rounded,
                  task.assignedVolunteer.isEmpty
                      ? 'Skuad penuh'
                      : task.assignedVolunteer,
                  AppColors.volunteerAccent),
              _trackingChip(
                  Icons.timer_rounded, 'ETA ${task.eta}', AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Lokasi: ${task.zone}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.radar_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Live Track: $coordinates',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Tugasan Semasa:',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(task.taskDescription,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: task.progress,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              color: statusColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _redirectVolunteerDialog(task),
                  icon: const Icon(Icons.alt_route_rounded, size: 16),
                  label: const Text('Tukar Lokasi',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // MOCK UPDATE PROGRESS
                    double newProg = task.progress + 0.3;
                    String newStatus = 'Sedang Bertugas';
                    if (newProg >= 1.0) {
                      newProg = 1.0;
                      newStatus = 'Selesai Tugas';
                    }
                    await _firestoreService.updateVolunteerTask(task.id, {
                      'progress': newProg,
                      'status': newStatus,
                      'lastKnownLocation': task.zone,
                    });
                  },
                  icon: const Icon(Icons.update_rounded, size: 16),
                  label:
                      const Text('Kemas Kini', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.volunteerAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trackingChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ─── AWANIS TAB ───────────────────────────────────────────────────
  Widget _buildAwanisTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4EE6).withValues(alpha: 0.05),
            Colors.white
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: const Color(0xFF6B4EE6).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_rounded,
                color: Color(0xFF6B4EE6), size: 80),
          ),
          const SizedBox(height: 32),
          Text('AWANIS',
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6B4EE6))),
          const SizedBox(height: 8),
          Text('Pembantu AI Pegawai',
              style: GoogleFonts.inter(
                  fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ─── TUNTUTAN (CLAIMS) TAB ────────────────────────────────────────
  Widget _buildClaimsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamClaimsForOfficerReview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final claims =
            snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
        claims.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // descending
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Semakan Tuntutan Bantuan',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
                'Semak bukti, beri maklum balas, atau luluskan tuntutan mengikut zon bencana.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _bulkApprovalPanel(claims),
            const SizedBox(height: 16),
            if (claims.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text('Tiada tuntutan untuk semakan buat masa ini.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              )
            else
              ...claims.map((doc) {
                final claim = ClaimModel.fromMap(
                    doc.id, doc.data() as Map<String, dynamic>);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _claimCard(claim),
                );
              }),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _bulkApprovalPanel(List<DocumentSnapshot> reviewClaims) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.streamDisasterZones(),
      builder: (context, zoneSnapshot) {
        final zones = zoneSnapshot.hasData
            ? zoneSnapshot.data!.docs
                .map((doc) =>
                    (doc.data() as Map<String, dynamic>)['name'] as String? ??
                    doc.id)
                .where((name) => name.trim().isNotEmpty)
                .toSet()
                .toList()
            : <String>[];
        zones.sort();

        final submittedClaims = reviewClaims
            .map((doc) =>
                ClaimModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .where((claim) => claim.status == 'submitted')
            .toList();
        final fallbackZones = submittedClaims
            .map((claim) => claim.location)
            .where((location) => location.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final selectableZones = zones.isNotEmpty ? zones : fallbackZones;

        if (_selectedBulkClaimZone != null &&
            !selectableZones.contains(_selectedBulkClaimZone)) {
          _selectedBulkClaimZone =
              selectableZones.isNotEmpty ? selectableZones.first : null;
        } else if (_selectedBulkClaimZone == null &&
            selectableZones.isNotEmpty) {
          _selectedBulkClaimZone = selectableZones.first;
        }

        final selectedZone = _selectedBulkClaimZone;
        final matchingCount = selectedZone == null
            ? 0
            : submittedClaims
                .where(
                    (claim) => _claimMatchesZone(claim.location, selectedZone))
                .length;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.done_all_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Kelulusan pukal zon bencana',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  Text('$matchingCount tuntutan',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedZone,
                decoration: InputDecoration(
                    labelText: 'Zon bencana',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
                items: selectableZones
                    .map((zone) => DropdownMenuItem(
                          value: zone,
                          child: Text(zone, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: selectableZones.isEmpty
                    ? null
                    : (zone) => setState(() => _selectedBulkClaimZone = zone),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: matchingCount == 0 || selectedZone == null
                      ? null
                      : () => _bulkApproveClaims(selectedZone, matchingCount),
                  icon: const Icon(Icons.verified_rounded, size: 18),
                  label: const Text('Lulus Semua Tuntutan Zon Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _claimMatchesZone(String claimLocation, String zoneName) {
    final location = claimLocation.toLowerCase();
    final zone = zoneName.toLowerCase();
    return location == zone ||
        location.contains(zone) ||
        zone.contains(location);
  }

  void _bulkApproveClaims(String zoneName, int matchingCount) {
    if (matchingCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiada tuntutan untuk diluluskan.')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.done_all_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Kelulusan Pukal',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
        content: Text(
          'Tindakan ini akan meluluskan $matchingCount tuntutan yang dihantar untuk zon bencana $zoneName. Teruskan?',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final officerId = _currentOfficerId();
                final approvedCount = await _firestoreService
                    .bulkApproveClaimsByZone(zoneName, officerId: officerId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '$approvedCount tuntutan dalam zon $zoneName telah diluluskan.'),
                      backgroundColor: AppColors.safe));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Gagal meluluskan tuntutan: $e'),
                      backgroundColor: AppColors.danger));
                }
              }
            },
            child: Text('Sah',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String? _currentOfficerId() {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state.uid : null;
  }

  void _reviewClaim(ClaimModel claim, String actionType) {
    if (actionType == 'approve') {
      _firestoreService
          .updateClaimStatus(claim.id, 'approved',
              officerId: _currentOfficerId())
          .then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Tuntutan ${claim.citizenName} diluluskan.'),
              backgroundColor: AppColors.safe));
        }
      });
      return;
    } else if (actionType == 'info') {
      _showClaimFeedbackDialog(
        claim: claim,
        title: 'Minta Maklumat Tambahan',
        actionLabel: 'Hantar Permintaan',
        status: 'under_review',
        color: AppColors.warning,
        hint: 'Contoh: Sila muat naik gambar kerosakan yang lebih jelas.',
      );
      return;
    }

    _showClaimFeedbackDialog(
      claim: claim,
      title: 'Tolak Tuntutan',
      actionLabel: 'Tolak',
      status: 'rejected',
      color: AppColors.danger,
      hint: 'Nyatakan sebab penolakan',
    );
  }

  void _showClaimFeedbackDialog({
    required ClaimModel claim,
    required String title,
    required String actionLabel,
    required String status,
    required Color color,
    required String hint,
  }) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: GoogleFonts.inter(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              if (ctrl.text.isEmpty) return;
              Navigator.pop(ctx);
              _firestoreService
                  .updateClaimStatus(
                claim.id,
                status,
                reason: ctrl.text.trim(),
                officerId: _currentOfficerId(),
              )
                  .then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(status == 'rejected'
                          ? 'Tuntutan ${claim.citizenName} ditolak.'
                          : 'Permintaan maklumat tambahan dihantar kepada ${claim.citizenName}.'),
                      backgroundColor: color));
                }
              });
            },
            child: Text(actionLabel,
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _claimCard(ClaimModel claim) {
    final isInfoRequested = claim.status == 'under_review';
    final statusColor = isInfoRequested ? Colors.purple : AppColors.warning;
    final statusLabel = isInfoRequested ? 'Info Diminta' : 'Menunggu';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(claim.citizenName,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99)),
                child: Text(statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.receipt_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(claim.type,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(claim.location,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.badge_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('IC: ${claim.icNumber}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textPrimary)),
              const SizedBox(width: 16),
              const Icon(Icons.family_restroom_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text('Isi Rumah: ${claim.householdSize}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: AppColors.danger),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('Kerosakan: ${claim.damageDescription}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textPrimary))),
            ],
          ),
          if (claim.infoRequestReason != null &&
              claim.infoRequestReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Maklumat diminta: ${claim.infoRequestReason}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.purple,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.photo_library_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        claim.photoEvidence.startsWith('data:image')
                            ? 'Gambar dimuat naik'
                            : claim.photoEvidence,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textPrimary))),
                TextButton(
                  onPressed: () async {
                    if (claim.photoEvidence.startsWith('data:image')) {
                      showDialog(
                          context: context,
                          builder: (ctx) {
                            try {
                              final base64String =
                                  claim.photoEvidence.split(',').last;
                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: Text('Bukti Bergambar',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                content: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                      base64Decode(base64String),
                                      fit: BoxFit.contain),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Tutup'))
                                ],
                              );
                            } catch (e) {
                              return AlertDialog(
                                  content:
                                      const Text('Ralat memaparkan gambar.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Tutup'))
                                  ]);
                            }
                          });
                    } else if (claim.photoEvidence.startsWith('http')) {
                      final url = Uri.parse(claim.photoEvidence);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Tiada pautan gambar disediakan.')));
                    }
                  },
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero, padding: EdgeInsets.zero),
                  child: Text('Lihat',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reviewClaim(claim, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reviewClaim(claim, 'info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Info', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _reviewClaim(claim, 'approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safe,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Lulus', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  // ─── SHARED HELPERS ───────────────────────────────────────────────

  ImageProvider? _getAvatarProvider() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      if (_profileImageUrl!.startsWith('data:image')) {
        final base64Str = _profileImageUrl!.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      }
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Widget _buildCommandCard(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), AppColors.officerAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.officerAccent.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pusat Kawalan Operasi',
                        style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(name.isNotEmpty ? name : 'Pegawai SIGAP',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context
                    .push(AppRoutes.officerProfile)
                    .then((_) => _loadOfficerData()),
                child: Hero(
                  tag: 'officer_avatar',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: _getAvatarProvider(),
                      child: (_profileImageUrl == null ||
                              _profileImageUrl!.isEmpty)
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 30)
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _statusPill(Icons.circle, '4 Daerah Aktif', Colors.amber),
              const SizedBox(width: 8),
              _statusPill(Icons.warning_rounded, 'Darurat Ditetapkan',
                  Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('247', 'Jumlah SOS', AppColors.danger, Icons.sos_rounded),
        const SizedBox(width: 12),
        _statCard('38', 'Sukarelawan', AppColors.safe, Icons.handshake_rounded),
        const SizedBox(width: 12),
        _statCard(
            '12', 'Zon Aktif', AppColors.officerAccent, Icons.map_rounded),
      ],
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Banjir':
        return Icons.water_rounded;
      case 'Kebakaran':
        return Icons.local_fire_department_rounded;
      case 'Tanah Runtuh':
        return Icons.landscape_rounded;
      case 'Perubatan':
      case 'Kecemasan Perubatan':
        return Icons.medical_services_rounded;
      case 'Orang Hilang':
        return Icons.person_search_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DONATION CAMPAIGN MANAGEMENT (Officer)
  // ─────────────────────────────────────────────────────────────────────────────

  /// Builds a rich campaign management card for the officer home tab.
  Widget _donationCampaignCard(CampaignModel campaign) {
    final isClosed = campaign.isClosed;
    final progress = campaign.progressFraction;

    return Container(
      height: 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isClosed ? AppColors.divider : AppColors.primary.withValues(alpha: 0.25),
          width: isClosed ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status badge
          SizedBox(
            height: 38,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    campaign.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.divider
                          : AppColors.safe.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isClosed ? 'Ditutup' : 'Aktif',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isClosed ? AppColors.textSecondary : AppColors.safe,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          
          // Purpose text
          SizedBox(
            height: 30,
            child: Text(
              campaign.purpose,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),

          // Amount + percent
          SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RM ${_fmtAmount(campaign.currentAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isClosed ? AppColors.textSecondary : AppColors.officerAccent,
                  ),
                ),
                Text(
                  '${campaign.progressPercent}% / RM ${_fmtAmount(campaign.targetAmount)}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Progress bar
          SizedBox(
            height: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isClosed ? AppColors.textSecondary : AppColors.officerAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Allocation chips (Standardized height of 24px)
          if (campaign.allocations.isNotEmpty)
            SizedBox(
              height: 24,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: campaign.allocations.entries.take(4).map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.officerAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.officerAccent.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key} ${e.value.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.officerAccent),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const SizedBox(height: 24),

          const Spacer(),

          // Action buttons (Standardized height of 34px)
          if (!isClosed)
            SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _allocateFundsDialog(campaign),
                      icon: const Icon(Icons.pie_chart_rounded, size: 14),
                      label: const Text('Peruntuk'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.officerAccent,
                        side: const BorderSide(color: AppColors.officerAccent),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle:
                            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _closeCampaignDialog(campaign),
                      icon: const Icon(Icons.lock_rounded, size: 14),
                      label: const Text('Tutup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 0,
                        textStyle:
                            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 34,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kempen ini telah ditutup',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Dialog to create a new donation campaign.
  void _createCampaignDialog() {
    final nameCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    bool isSubmitting = false;

    // Dynamic allocation key-value pairs
    final allocationKeys = [TextEditingController()];
    final allocationVals = [TextEditingController()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.campaign_rounded,
                        color: AppColors.officerAccent, size: 22),
                    const SizedBox(width: 10),
                    Text('Cipta Kempen Baru',
                        style: GoogleFonts.poppins(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),
                _officerField('Nama Kempen', nameCtrl,
                    hint: 'Contoh: Tabung Banjir Kelantan 2025'),
                const SizedBox(height: 12),
                _officerField('Tujuan / Keterangan', purposeCtrl,
                    hint: 'Terangkan tujuan kempen ini...', maxLines: 3),
                const SizedBox(height: 12),
                _officerField('Sasaran Jumlah (RM)', targetCtrl,
                    hint: '50000', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _officerField('URL Imej Kempen (Pilihan)', imageCtrl,
                    hint: 'https://...'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Pengagihan Dana (%)',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          allocationKeys.add(TextEditingController());
                          allocationVals.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Tambah'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.officerAccent,
                        textStyle:
                            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(allocationKeys.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: allocationKeys[i],
                            decoration: InputDecoration(
                              hintText: 'Kategori (cth: Makanan)',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: allocationVals[i],
                            decoration: InputDecoration(
                              hintText: '%',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                        if (allocationKeys.length > 1)
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                allocationKeys.removeAt(i);
                                allocationVals.removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.remove_circle_outline_rounded,
                                color: AppColors.danger, size: 20),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final purpose = purposeCtrl.text.trim();
                            final target = double.tryParse(targetCtrl.text) ?? 0.0;

                            if (name.isEmpty || purpose.isEmpty || target <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Sila lengkapkan semua medan wajib.')));
                              return;
                            }

                            // Build allocation map
                            final Map<String, double> allocations = {};
                            for (int i = 0; i < allocationKeys.length; i++) {
                              final key = allocationKeys[i].text.trim();
                              final val = double.tryParse(allocationVals[i].text) ?? 0.0;
                              if (key.isNotEmpty && val > 0) {
                                allocations[key] = val;
                              }
                            }

                            setModalState(() => isSubmitting = true);
                            await _firestoreService.createCampaign({
                              'name': name,
                              'purpose': purpose,
                              'targetAmount': target,
                              'currentAmount': 0.0,
                              'allocations': allocations,
                              'status': 'active',
                              if (imageCtrl.text.trim().isNotEmpty)
                                'imageUrl': imageCtrl.text.trim(),
                            });
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kempen "$name" berjaya dicipta!'),
                                  backgroundColor: AppColors.safe,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.officerAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Cipta Kempen',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog to edit fund allocation percentages of an existing campaign.
  void _allocateFundsDialog(CampaignModel campaign) {
    // Pre-fill existing allocations
    final keys = campaign.allocations.keys
        .map((k) => TextEditingController(text: k))
        .toList();
    final vals = campaign.allocations.values
        .map((v) => TextEditingController(text: v.toStringAsFixed(0)))
        .toList();
    if (keys.isEmpty) {
      keys.add(TextEditingController());
      vals.add(TextEditingController());
    }
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.pie_chart_rounded,
                        color: AppColors.officerAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kemaskini Pengagihan Dana',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(campaign.name,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kategori & Peratus',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          keys.add(TextEditingController());
                          vals.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Tambah'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.officerAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(keys.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: keys[i],
                            decoration: InputDecoration(
                              hintText: 'Kategori',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: vals[i],
                            decoration: InputDecoration(
                              hintText: '%',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                        if (keys.length > 1)
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                keys.removeAt(i);
                                vals.removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.remove_circle_outline_rounded,
                                color: AppColors.danger, size: 20),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final Map<String, double> newAllocations = {};
                            for (int i = 0; i < keys.length; i++) {
                              final k = keys[i].text.trim();
                              final v = double.tryParse(vals[i].text) ?? 0.0;
                              if (k.isNotEmpty && v > 0) newAllocations[k] = v;
                            }
                            setModalState(() => isSaving = true);
                            await _firestoreService.updateCampaign(
                                campaign.id, {'allocations': newAllocations});
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pengagihan dana berjaya dikemaskini.'),
                                  backgroundColor: AppColors.safe,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.officerAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Simpan Perubahan',
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Confirm dialog to close a campaign.
  void _closeCampaignDialog(CampaignModel campaign) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Text('Tutup Kempen',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campaign.name,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Kempen ini akan ditutup dan tidak lagi menerima sumbangan baru. Rekod derma sedia ada kekal disimpan.\n\nAdakah anda pasti?',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tindakan ini tidak boleh diundur.',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.closeCampaign(campaign.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kempen "${campaign.name}" telah ditutup.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Ya, Tutup Kempen',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Helper text field for officer dialogs.
  Widget _officerField(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.officerAccent, width: 1.5)),
          ),
          style: GoogleFonts.inter(fontSize: 13),
        ),
      ],
    );
  }

  String _fmtAmount(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}J';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}