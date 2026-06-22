import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/data/emergency_guides_data.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class OfflineGuideScreen extends StatefulWidget {
  const OfflineGuideScreen({super.key});

  @override
  State<OfflineGuideScreen> createState() => _OfflineGuideScreenState();
}

class _OfflineGuideScreenState extends State<OfflineGuideScreen> {
  late Box _offlineBox;
  List<Map<String, dynamic>> _guides = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _offlineBox = Hive.box('offline_guides');
    
    // Seed data if empty
    if (_offlineBox.isEmpty) {
      for (var i = 0; i < EmergencyGuidesData.guides.length; i++) {
        _offlineBox.put('guide_\$i', EmergencyGuidesData.guides[i]);
      }
    }

    final List<Map<String, dynamic>> loaded = [];
    for (var key in _offlineBox.keys) {
      if (key.toString().startsWith('guide_')) {
        final data = _offlineBox.get(key);
        // Hive returns Map<dynamic, dynamic>, need to cast
        final map = Map<String, dynamic>.from(data as Map);
        map['items'] = List<String>.from(map['items'] as List);
        loaded.add(map);
      }
    }
    
    setState(() {
      _guides = loaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Panduan Luar Talian'.tr(),
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _guides.isEmpty 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _guides.length,
              itemBuilder: (context, index) {
                final guide = _guides[index];
                return _buildGuideCard(guide);
              },
            ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> guide) {
    final title = guide['title'] as String;
    final category = guide['category'] as String;
    final items = guide['items'] as List<String>;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: ExpansionTile(
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          category,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.safe, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
