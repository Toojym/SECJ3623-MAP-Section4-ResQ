import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'package:easy_localization/easy_localization.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Pusat Bantuan & FAQ',
          style: GoogleFonts.poppins(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCategory(
            title:'Sebelum Bencana (Before Disaster)'.tr(),
            items: [
              _buildFaqItem('Apakah persiapan awal?', 'Sediakan kit kecemasan, kenal pasti pusat pemindahan, dan peka pada amaran kaji cuaca.'),
              _buildFaqItem('Bagaimana mengetahui zon risiko?', 'Rujuk peta interaktif dalam aplikasi SIGAP atau portal NADMA.'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            title:'Semasa Bencana (During Disaster)'.tr(),
            items: [
              _buildFaqItem('Bagaimana hantar SOS?', 'Tekan butang SOS merah di skrin utama dan pilih jenis kecemasan. Lokasi anda akan dihantar kepada penyelamat.'),
              _buildFaqItem('Saya tiada internet, apa perlu buat?', 'Gunakan Panduan Luar Talian di aplikasi SIGAP. Jika perlu bantuan segera, hubungi 999.'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            title:'Tuntutan & Bantuan (Claims)'.tr(),
            items: [
              _buildFaqItem('Bagaimana mohon tuntutan?', 'Pergi ke tab Tuntutan (Claims) dan isikan borang berserta gambar bukti.'),
              _buildFaqItem('Berapa lama proses kelulusan?', 'Biasanya mengambil masa 7-14 hari bekerja bergantung pada pengesahan wakil kerajaan.'),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategory(
            title:'Sukarelawan (Volunteer)'.tr(),
            items: [
              _buildFaqItem('Bagaimana kumpul SIGAP Mata?', 'Anda akan menerima mata setelah berjaya menyelesaikan misi SOS yang diterima.'),
              _buildFaqItem('Bolehkah saya tukar mata?', 'Ya, mata boleh ditebus untuk sijil penghargaan dari NADMA/Bomba di skrin Leaderboard.'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategory({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        title: Text(
          question,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              answer,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
