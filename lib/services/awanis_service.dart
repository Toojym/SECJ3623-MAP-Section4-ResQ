import 'dart:async';

class AwanisService {
  AwanisService();

  Future<String> chatWithCitizen(String message) async {
    await Future.delayed(
        const Duration(seconds: 1)); // Simulate network latency

    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains("banjir") ||
        lowerMsg.contains("air naik") ||
        lowerMsg.contains("flood")) {
      return "Sila bertenang. Jika air sudah naik ke paras berbahaya, pastikan anda segera berpindah ke pusat pemindahan terdekat. Jangan lupa bawa dokumen penting dan ubat-ubatan.";
    } else if (lowerMsg.contains("pusat pemindahan") ||
        lowerMsg.contains("shelter") ||
        lowerMsg.contains("pps")) {
      return "Anda boleh semak senarai pusat pemindahan di bahagian 'Pusat Pemindahan Terdekat' di papan pemuka utama anda. Sila kemaskini status keselamatan anda kepada 'Berpindah' setelah tiba di sana.";
    } else if (lowerMsg.contains("tuntutan") ||
        lowerMsg.contains("bantuan") ||
        lowerMsg.contains("claim")) {
      return "Untuk membuat tuntutan bantuan, anda boleh pergi ke halaman 'Tuntutan' dan muat naik dokumen sokongan seperti gambar kerosakan dan laporan polis. Tuntutan anda akan diproses oleh pegawai bertugas.";
    } else if (lowerMsg.contains("sos")) {
      return "Untuk menghantar laporan SOS, sila tekan butang kecemasan merah (SOS) yang terletak di tengah-tengah menu bawah aplikasi (bottom bar). Ini akan serta-merta memberi isyarat kepada sukarelawan berdekatan.";
    } else if (lowerMsg.contains("keluarga") || lowerMsg.contains("kesan")) {
      return "Anda boleh mengesan status keselamatan ahli keluarga anda di halaman 'Profil'. Pastikan anda telah menambah mereka ke dalam senarai 'Ahli Keluarga'.";
    } else if (lowerMsg.contains("cuaca") || lowerMsg.contains("amaran")) {
      return "Amaran cuaca terkini: Hujan lebat berterusan (Amaran Bahaya) dijangka melanda kawasan utara dan timur. Sila sentiasa berwaspada dan pantau notis Jabatan Meteorologi Malaysia.";
    } else if (lowerMsg.contains("hai") ||
        lowerMsg.contains("hello") ||
        lowerMsg.contains("salam")) {
      return "Hai! Saya AWANIS, pembantu AI bencana anda. Ada apa-apa yang boleh saya bantu hari ini?";
    } else if (lowerMsg.contains("batal") || lowerMsg.contains("silap")) {
      return "Tiada masalah. Anda sentiasa boleh membatalkan laporan atau tuntutan jika tersilap. Saya sedia membantu perkara lain.";
    } else if (lowerMsg.contains("nadma")) {
      return "NADMA (Agensi Pengurusan Bencana Negara) merupakan agensi peneraju pengurusan bencana di Malaysia. Talian Hotline Bencana NADMA ialah 03-8064 2400. Sila hubungi mereka untuk penyelarasan bantuan kecemasan berskala besar.";
    } else if (lowerMsg.contains("bomba") || lowerMsg.contains("penyelamat")) {
      return "Jabatan Bomba dan Penyelamat Malaysia sedia membantu dalam operasi mencari dan menyelamat. Sila hubungi talian MERS 999 untuk tindakan segera dari pihak Bomba jika anda terperangkap.";
    } else if (lowerMsg.contains("polis") || lowerMsg.contains("pdrm")) {
      return "Polis Diraja Malaysia (PDRM) bertanggungjawab memastikan keselamatan dan kawalan lalu lintas di kawasan bencana. Hubungi 999 atau balai polis berhampiran untuk kes keselamatan atau kecemasan.";
    } else if (lowerMsg.contains("hospital") ||
        lowerMsg.contains("ambulans") ||
        lowerMsg.contains("kkm") ||
        lowerMsg.contains("klinik") ||
        lowerMsg.contains("kecemasan perubatan")) {
      return "Untuk sebarang kecemasan perubatan atau mangsa cedera, fasiliti Kementerian Kesihatan Malaysia (KKM) sentiasa bersiap sedia. Sila hubungi talian MERS 999 untuk memanggil ambulans dengan segera.";
    } else if (lowerMsg.contains("jkm") ||
        lowerMsg.contains("jabatan kebajikan")) {
      return "Jabatan Kebajikan Masyarakat (JKM) menguruskan hal ehwal pengagihan makanan, pendaftaran mangsa, dan bekalan keperluan asas di Pusat Pemindahan Sementara (PPS). Sila lapor kepada pegawai JKM di PPS anda.";
    } else if (lowerMsg.contains("apm") ||
        lowerMsg.contains("pertahanan awam")) {
      return "Angkatan Pertahanan Awam Malaysia (APM) sentiasa bersedia memberi bantuan menyelamat awal dan pengurusan pemindahan. Anda boleh menghubungi APM melalui talian 999.";
    } else if (lowerMsg.contains("jkr") ||
        lowerMsg.contains("tanah runtuh") ||
        lowerMsg.contains("jalan ditutup") ||
        lowerMsg.contains("jalan raya")) {
      return "Jabatan Kerja Raya (JKR) bertanggungjawab memantau penutupan jalan dan kes tanah runtuh akibat bencana. Anda boleh menyemak status jalan raya yang selamat dilalui melalui Portal Bencana JKR.";
    } else {
      return "I only assist with questions related to disasters, safety, and claims. Please ask questions related to emergencies or evacuations.";
    }
  }

  Future<String> generateVolunteerBriefing(
      String sosType, String location, int victimCount) async {
    await Future.delayed(const Duration(seconds: 1));
    return '''Taklimat Misi Keselamatan:
1. Insiden: Terdapat $victimCount mangsa yang terlibat dalam kes $sosType di $location. Pasukan perlu bersiap sedia untuk operasi menyelamat segera.
2. Persediaan: Sila pastikan anda membawa kit kecemasan, jaket keselamatan, tali, dan lampu suluh yang mencukupi.
3. Keselamatan: Utamakan keselamatan pasukan anda terlebih dahulu. Sentiasa patuhi arahan ketua komander di lapangan dan jangan mengambil risiko berbahaya tanpa peralatan yang sesuai.''';
  }

  Future<String> getVolunteerBriefing() async {
    await Future.delayed(const Duration(seconds: 1));
    return '''Taklimat Pra-Misi Terkini:
Berdasarkan pangkalan data, terdapat beberapa laporan SOS aktif di sekitar kawasan anda. 
Pasukan sukarelawan diingatkan untuk sentiasa bersiap sedia, mengutamakan keselamatan fizikal dan mental, serta memeriksa keadaan kenderaan dan aset penyelamat.
Terus berhubung melalui sistem pemantauan SIGAP dan tunggu arahan selanjutnya daripada pegawai bertugas.''';
  }

  Future<String> queryOfficerAnalytics(
      String question, Map<String, dynamic> firestoreData) async {
    await Future.delayed(const Duration(seconds: 1));
    final lowerQ = question.toLowerCase();
    final sosCount = firestoreData['jumlah_sos_aktif'] ?? 0;
    final volCount = firestoreData['jumlah_sukarelawan_aktif'] ?? 0;

    if (lowerQ.contains('sos') || lowerQ.contains('kecemasan')) {
      return "Pada masa ini, terdapat $sosCount laporan SOS yang aktif dalam sistem. Sila pantau peta untuk melihat taburan mangsa dan arahkan sukarelawan berdekatan.";
    } else if (lowerQ.contains('sukarelawan') || lowerQ.contains('volunteer')) {
      return "Setakat ini, terdapat $volCount sukarelawan yang bersedia dan aktif di lapangan. Anda boleh menugaskan mereka ke kawasan yang terjejas melalui Papan Pemuka.";
    } else if (lowerQ.contains('tuntutan') ||
        lowerQ.contains('claim') ||
        lowerQ.contains('bwi') ||
        lowerQ.contains('dana')) {
      return "Untuk memantau dan meluluskan tuntutan bantuan BWI, sila ke tab 'Tuntutan'. Setakat ini lebih RM500,000 dana bantuan telah disalurkan.";
    } else if (lowerQ.contains('laporan') ||
        lowerQ.contains('analisa') ||
        lowerQ.contains('trend')) {
      return "Berdasarkan analisa data sistem SIGAP terkini, trend laporan menunjukkan $sosCount kes SOS sedang diuruskan oleh $volCount sukarelawan aktif. Sumber logistik dan anggota adalah mencukupi setakat ini.";
    } else if (lowerQ.contains('zon') || lowerQ.contains('bencana')) {
      return "Anda boleh mengisytiharkan zon bencana baharu atau memantau zon sedia ada di tab 'Zon Bencana'.";
    } else if (lowerQ.contains('mangsa') ||
        lowerQ.contains('gombak') ||
        lowerQ.contains('jumlah mangsa')) {
      return "Berdasarkan rekod pusat pemindahan, terdapat 450 mangsa di kawasan Gombak yang ditempatkan di 3 Pusat Pemindahan Sementara (PPS).";
    } else if (lowerQ.contains('hai') ||
        lowerQ.contains('hello') ||
        lowerQ.contains('salam')) {
      return "Hai Tuan/Puan Pegawai! Saya AWANIS, pembantu AI pusat kawalan anda. Boleh saya bantu paparkan status SOS, sukarelawan, atau analisa semasa?";
    } else {
      return "Maaf, saya hanya membantu dengan info pusat kawalan. Anda boleh bertanya saya tentang 'status SOS', 'jumlah sukarelawan', 'tuntutan', atau 'analisa laporan'.";
    }
  }

  Future<String> generateIncidentSummary(Map<String, dynamic> zoneData) async {
    await Future.delayed(const Duration(seconds: 1));
    return '''Ringkasan Laporan Zon Bencana (Penutupan Operasi):
Operasi di zon ini telah ditutup secara rasmi. Seramai purata 50 orang mangsa berjaya dipindahkan dengan selamat, dan sejumlah SOS telah berjaya diselesaikan hasil paduan tenaga pelbagai agensi dan sukarelawan SIGAP. Bantuan susulan sedang diselaraskan untuk fasa pemulihan.''';
  }
}
