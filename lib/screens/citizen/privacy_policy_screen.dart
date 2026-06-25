import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/sigap_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SigapAppBar(
        title:'Dasar Privasi & PDPA'.tr(),
        showLogout: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notis Perlindungan Data Peribadi (PDPA)'.tr(),
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              'Selaras dengan Akta Perlindungan Data Peribadi 2010 ("PDPA") Malaysia, aplikasi SIGAP (Sistem Integrasi Gerak Awam Pantas) komited untuk melindungi data peribadi anda. Notis ini menerangkan bagaimana kami mengumpul dan memproses maklumat anda.',
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.6, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. Jenis Data Peribadi yang Dikumpul',
              'Kami mengumpul data seperti Nama, No. Kad Pengenalan (IC), Data Lokasi GPS, Nombor Telefon, dan Butiran Akaun Bank (hanya bagi tujuan Tuntutan Bantuan Wang Ihsan).'.tr(),
            ),
            _buildSection(
              '2. Tujuan Pengumpulan',
              'Data anda digunakan secara eksklusif untuk tujuan pengurusan bencana, termasuk koordinasi pasukan penyelamat (MKN Arahan 20), pengesahan identiti Ketua Isi Rumah (KIR), dan penyaluran bantuan kewangan (EFT).',
            ),
            _buildSection(
              '3. Pendedahan Kepada Pihak Ketiga',
              'Kami mungkin berkongsi data anda dengan agensi kerajaan yang berkaitan (contoh: NADMA, PDRM, Bomba, JKM) bagi tujuan menyelamat dan verifikasi tuntutan sahaja. Data anda tidak akan dijual kepada pihak ketiga untuk tujuan komersial.',
            ),
            _buildSection(
              '4. Pilihan dan Persetujuan (Consent)',
              'Dengan menggunakan fungsi SOS dan Tuntutan (Claim) di aplikasi ini, anda memberi persetujuan eksplisit kepada kami untuk mengakses lokasi anda dan memproses butiran pengenalan anda.'.tr(),
            ),
            _buildSection(
              '5. Keselamatan dan Penyimpanan',
              'Data akan disimpan secara selamat selagi diperlukan bagi memenuhi tujuan pelaporan dan audit rasmi oleh kerajaan. Selepas tempoh tersebut, data akan dilupuskan mengikut tatacara kerajaan.'.tr(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Text(
                'Nota: Pemberian maklumat palsu terutamanya bagi tujuan Tuntutan (BWI) adalah satu kesalahan dan boleh didakwa di bawah Akta Suruhanjaya Pencegahan Rasuah Malaysia (SPRM) 2009.'.tr(),
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppStrings.understandAndClose, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
                fontSize: 14, height: 1.6, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
