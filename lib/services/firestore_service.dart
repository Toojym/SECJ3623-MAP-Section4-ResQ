import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users collection ──────────────────────────────────────────────────────

  Future<void> createUserDocument(
    String uid,
    String email,
    String password,
    String role,
    String displayName,
  ) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'password': password,
      'role': role,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'profileComplete': false,
    });
    
    // Also initialize the citizen profile with the password so it can be fetched immediately
    if (role == 'citizen') {
      await _db.collection('citizen_profiles').doc(uid).set({
        'uid': uid,
        'email': email,
        'password': password,
        'fullName': displayName,
      }, SetOptions(merge: true));
    }
  }

  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<bool> checkEmailExists(String email) async {
    final query = await _db.collection('users').where('email', isEqualTo: email.trim()).limit(1).get();
    return query.docs.isNotEmpty;
  }

  Future<String?> getUserRole(String uid) async {
    final data = await getUserDocument(uid);
    return data?['role'] as String?;
  }

  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ── Role profiles ──────────────────────────────────────────────────────────

  Future<void> createCitizenProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('citizen_profiles').doc(uid).set({
      ...data,
      'uid': uid,
    }, SetOptions(merge: true));
    // Mark profile as complete in the users doc
    await updateUserDocument(uid, {'profileComplete': true});
  }

  Future<void> createVolunteerProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('volunteer_profiles').doc(uid).set({
      ...data,
      'uid': uid,
      'sigapMataPoints': 0,
      'isActive': false,
    }, SetOptions(merge: true));
    await updateUserDocument(uid, {'profileComplete': true});
  }

  Future<void> createOfficerProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('officer_profiles').doc(uid).set({
      ...data,
      'uid': uid,
    }, SetOptions(merge: true));
    await updateUserDocument(uid, {'profileComplete': true});
  }

  Future<Map<String, dynamic>?> getCitizenProfile(String uid) async {
    final doc = await _db.collection('citizen_profiles').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> getVolunteerProfile(String uid) async {
    final doc = await _db.collection('volunteer_profiles').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> getOfficerProfile(String uid) async {
    final doc = await _db.collection('officer_profiles').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> updateVolunteerActiveStatus(String uid, bool isActive) async {
    await _db.collection('volunteer_profiles').doc(uid).update({'isActive': isActive});
  }

  // ── Incidents (SOS) ──────────────────────────────────────────────────────

  Stream<QuerySnapshot> getActiveIncidentsStream() {
    return _db
        .collection('incidents')
        .where('status', isEqualTo: 'active')
        // Removed orderBy to prevent composite index requirement. We will sort locally.
        .snapshots();
  }

  Future<void> resolveIncident(String incidentId) async {
    await _db.collection('incidents').doc(incidentId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Temporary method to seed dummy data if collection is empty
  Future<void> seedDummyIncidentsIfEmpty() async {
    final snapshot = await _db.collection('incidents').limit(1).get();
    if (snapshot.docs.isEmpty) {
      final now = DateTime.now();
      await _db.collection('incidents').add({
        'title': 'Banjir Kilat — Ampang',
        'description': 'Air naik mendadak di kawasan perumahan utama.',
        'severity': 'Kritikal',
        'type': 'Banjir',
        'status': 'active',
        'reportedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
        'latitude': 3.14925,
        'longitude': 101.7610,
      });
      await _db.collection('incidents').add({
        'title': 'Tanah Runtuh — Gombak',
        'description': 'Pokok tumbang dan tanah runtuh di jalan utama.',
        'severity': 'Sederhana',
        'type': 'Tanah Runtuh',
        'status': 'active',
        'reportedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 40))), // < 3 hari
        'latitude': 3.2217,
        'longitude': 101.7262,
      });
      await _db.collection('incidents').add({
        'title': 'Kecemasan Perubatan — Cheras',
        'description': 'Pesakit perlukan bantuan oksigen di pusat pemindahan.',
        'severity': 'Rendah',
        'type': 'Kecemasan Perubatan',
        'status': 'active',
        'reportedAt': Timestamp.fromDate(now.subtract(const Duration(days: 4))), // > 3 Hari
        'latitude': 3.1065,
        'longitude': 101.7259,
      });
    }
  }
}
