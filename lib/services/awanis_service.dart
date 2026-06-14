import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AwanisService {
  static const String _apiKey = 'YOUR_API_KEY_HERE'; // Replace with your actual API key or use environment variables
  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  AwanisService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: _apiKey,
      systemInstruction: Content.system('''You are AWANIS, an intelligent and calm disaster management AI assistant for SIGAP (Sistem Integrasi Gerak Awam Pantas) in Malaysia. 
Your goal is to provide accurate, calm assistance to citizens, volunteers, and officers.
If the user speaks in English, reply in English. If they speak in Bahasa Malaysia, reply in Bahasa Malaysia.
You can provide step-by-step survival guidance, shelter recommendations, and claim filing help.
For officers, you provide data-driven insights. For volunteers, you provide pre-mission briefings.
Always be concise, reassuring, and clear.'''),
    );
    _chatSession = _model.startChat();
  }

  Future<String> chatWithCitizen(String message) async {
    try {
      final response = await _chatSession.sendMessage(Content.text(message));
      return response.text ?? "Maaf, saya tidak dapat memproses permintaan anda buat masa ini.";
    } catch (e) {
      return "Maaf, sistem AI sedang mengalami gangguan. Sila hubungi talian kecemasan terus.";
    }
  }

  Future<String> generateVolunteerBriefing(String sosType, String location, int victimCount) async {
    final prompt = '''
Anda sedang memberikan taklimat (briefing) ringkas kepada sukarelawan (Volunteer) yang akan ke lokasi kecemasan.
Jenis Kecemasan: $sosType
Lokasi: $location
Bilangan Mangsa Terlibat: $victimCount

Berikan taklimat ringkas (maksimum 3 perenggan) meliputi:
1. Ringkasan insiden.
2. Persediaan atau sumber yang perlu dibawa.
3. Nasihat keselamatan.
''';
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Taklimat tidak dapat dijana.";
    } catch (e) {
      return "Ralat menjana taklimat misi.";
    }
  }

  Future<String> getVolunteerBriefing() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('sos_reports').where('status', isEqualTo: 'Aktif').limit(3).get();
      if (snapshot.docs.isEmpty) {
        return "Tiada insiden kecemasan aktif pada masa ini. Sila bersedia di pangkalan.";
      }
      
      final reports = snapshot.docs.map((d) {
        final data = d.data();
        return "${data['type']} di ${data['address']}";
      }).join("; ");
      
      final prompt = '''
Anda sedang memberikan taklimat ringkas kepada sukarelawan sebelum mereka dihantar ke misi.
Insiden aktif terkini: $reports

Berikan taklimat pra-misi dalam 2-3 perenggan yang merangkumi ringkasan situasi terkini, peringatan persediaan mental & fizikal, serta arahan untuk sentiasa mengutamakan keselamatan diri.
''';
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Taklimat tidak dapat dijana.";
    } catch (e) {
      return "Ralat mendapatkan maklumat kecemasan.";
    }
  }

  Future<String> queryOfficerAnalytics(String question, Map<String, dynamic> firestoreData) async {
    final prompt = '''
Anda adalah penganalisis data kecemasan.
Data terkini dalam sistem: $firestoreData

Pegawai kerajaan bertanya: "$question"

Jawab secara profesional berdasarkan data di atas. Jika tiada data, nyatakan tiada rekod.
''';
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Tidak dapat memproses analisa.";
    } catch (e) {
      return "Ralat memproses analisa data.";
    }
  }

  Future<String> generateIncidentSummary(Map<String, dynamic> zoneData) async {
    final prompt = '''
Sila jana ringkasan laporan rasmi untuk zon bencana yang telah ditutup.
Data zon: $zoneData

Berikan ringkasan yang sesuai untuk diserahkan kepada kementerian (NADMA/Bomba).
Masukkan: jumlah mangsa, jumlah SOS diselesaikan, sukarelawan ditugaskan, dana disalurkan.
''';
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Ringkasan tidak dapat dijana.";
    } catch (e) {
      return "Ralat menjana ringkasan.";
    }
  }
}
