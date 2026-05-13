import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users collection ──────────────────────────────────────────────────────

  Future<void> createUserDocument(
    String uid,
    String email,
    String role,
    String displayName,
  ) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': role,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'profileComplete': false,
    });
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
}
