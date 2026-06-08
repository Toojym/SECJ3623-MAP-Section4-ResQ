import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
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
    await _db
        .collection('volunteer_profiles')
        .doc(uid)
        .update({'isActive': isActive});
  }

  // ── SOS Reports ─────────────────────────────────────────────────────────────

  /// Create a new SOS report and return the document ID.
  Future<String> createSOSReport(Map<String, dynamic> data) async {
    final docRef = await _db.collection('sos_reports').add(data);
    
    final reporterId = data['reporterId'] as String?;
    if (reporterId != null) {
      await _db.collection('citizen_profiles').doc(reporterId).set({
        'safetyStatus': 'Perlu Bantuan',
      }, SetOptions(merge: true));
    }
    
    return docRef.id;
  }

  /// Stream active SOS reports (real-time) for the Volunteer Task Board.
  /// Only reports with status 'active' are returned, ordered newest-first.
  Stream<QuerySnapshot> streamActiveSOSReports() {
    return _db
        .collection('sos_reports')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream the current user's active SOS reports (for citizen cancellation UI).
  Stream<QuerySnapshot> streamMyActiveSOSReports(String uid) {
    return _db
        .collection('sos_reports')
        .where('reporterId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  /// Update any fields on an SOS report document.
  Future<void> updateSOSReport(String docId, Map<String, dynamic> data) async {
    await _db.collection('sos_reports').doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel an SOS report (citizen side — false alarm).
  Future<void> cancelSOSReport(String docId, String reason) async {
    final reportDoc = await _db.collection('sos_reports').doc(docId).get();
    final reporterId = reportDoc.data()?['reporterId'] as String?;

    await _db.collection('sos_reports').doc(docId).update({
      'status': 'cancelled',
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (reporterId != null) {
      await _db.collection('citizen_profiles').doc(reporterId).set({
        'safetyStatus': 'Selamat',
      }, SetOptions(merge: true));
    }
  }

  /// Volunteer accepts / responds to an SOS report.
  Future<void> respondToSOS(
    String docId,
    String volunteerId,
    String volunteerName,
  ) async {
    await _db.collection('sos_reports').doc(docId).update({
      'status': 'responded',
      'responderId': volunteerId,
      'responderName': volunteerName,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get a single SOS report by ID.
  Future<Map<String, dynamic>?> getSOSReport(String docId) async {
    final doc = await _db.collection('sos_reports').doc(docId).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  // ── Officer SOS Monitoring ────────────────────────────────────────────────

  /// Officer: stream ALL SOS reports that are active or responded (need monitoring).
  /// Ordered by creation time newest-first. Requires a Firestore composite index on
  /// (status, createdAt desc) — or fall back to client-side sorting without orderBy.
  Stream<QuerySnapshot> streamAllActiveSOSReportsForOfficer() {
    return _db
        .collection('sos_reports')
        .where('status', whereIn: ['active', 'responded'])
        .snapshots(); // Sorted client-side to avoid composite index requirement
  }

  /// Officer: stream SOS reports that have been resolved (for history view).
  Stream<QuerySnapshot> streamResolvedSOSReports() {
    return _db
        .collection('sos_reports')
        .where('status', isEqualTo: 'resolved')
        .snapshots(); // Sorted client-side
  }

  /// Officer resolves a citizen SOS report. This automatically removes it from
  /// the volunteer task board (which only streams 'active' status) and from the
  /// officer's active monitoring list.
  Future<void> resolveSOSReportByOfficer(String docId) async {
    final reportDoc = await _db.collection('sos_reports').doc(docId).get();
    final reporterId = reportDoc.data()?['reporterId'] as String?;

    await _db.collection('sos_reports').doc(docId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (reporterId != null) {
      await _db.collection('citizen_profiles').doc(reporterId).set({
        'safetyStatus': 'Berpindah',
      }, SetOptions(merge: true));
    }
  }

  // ── Disaster Zones ────────────────────────────────────────────────────────

  /// Create a new disaster zone in Firestore.
  Future<String> createDisasterZone(Map<String, dynamic> data) async {
    final docRef = await _db.collection('disaster_zones').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Stream all declared disaster zones in real time.
  Stream<QuerySnapshot> streamDisasterZones() {
    return _db.collection('disaster_zones').snapshots();
  }

  /// Stream active or responded SOS reports for a specific citizen.
  Stream<QuerySnapshot> streamMyActiveAndRespondedSOSReports(String uid) {
    return _db
        .collection('sos_reports')
        .where('reporterId', isEqualTo: uid)
        .where('status', whereIn: ['active', 'responded'])
        .snapshots();
  }

  /// Request backup/reinforcements for a specific SOS report.
  Future<void> updateSOSReportBackupRequest(String docId, bool needBackup) async {
    await _db.collection('sos_reports').doc(docId).update({
      'needBackup': needBackup,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Volunteer resolves a citizen SOS report.
  Future<void> resolveSOSReportByVolunteer(String docId) async {
    final reportDoc = await _db.collection('sos_reports').doc(docId).get();
    final reporterId = reportDoc.data()?['reporterId'] as String?;

    await _db.collection('sos_reports').doc(docId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (reporterId != null) {
      await _db.collection('citizen_profiles').doc(reporterId).set({
        'safetyStatus': 'Berpindah',
      }, SetOptions(merge: true));
    }
  }

  // ── Claims (Tuntutan) ──────────────────────────────────────────────────────

  Future<void> submitClaim(Map<String, dynamic> data) async {
    await _db.collection('claims').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamClaimsForCitizen(String citizenId) {
    return _db
        .collection('claims')
        .where('citizenId', isEqualTo: citizenId)
        .snapshots();
  }

  Stream<QuerySnapshot> streamPendingClaims() {
    return _db
        .collection('claims')
        .where('status', isEqualTo: 'submitted')
        .snapshots();
  }

  Future<void> updateClaimStatus(String claimId, String status, {String? reason}) async {
    await _db.collection('claims').doc(claimId).update({
      'status': status,
      if (reason != null) 'rejectReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> bulkApproveClaimsByZone(String location) async {
    final pendingClaims = await _db
        .collection('claims')
        .where('status', isEqualTo: 'submitted')
        .where('location', isEqualTo: location)
        .get();

    final batch = _db.batch();
    for (final doc in pendingClaims.docs) {
      batch.update(doc.reference, {
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteClaim(String claimId) async {
    await _db.collection('claims').doc(claimId).delete();
  }

  Future<String> uploadClaimEvidence(File imageFile, String citizenId) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$citizenId.jpg';
      final ref = _storage.ref().child('claims_evidence/$fileName');
      
      final bytes = await imageFile.readAsBytes();
      final uploadTask = ref.putData(
        bytes, 
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      if (snapshot.state == TaskState.success) {
        return await snapshot.ref.getDownloadURL();
      } else {
        throw Exception('Upload did not succeed. State: ${snapshot.state}');
      }
    } catch (e) {
      debugPrint('Firebase Storage upload failed: $e. Falling back to Base64.');
      final bytes = await imageFile.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }
  }

  // ── Donation Campaigns ─────────────────────────────────────────────────────

  Future<void> createCampaign(Map<String, dynamic> data) async {
    await _db.collection('campaigns').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamActiveCampaigns() {
    return _db.collection('campaigns').snapshots();
  }

  // ── Donations ──────────────────────────────────────────────────────────────
  
  Stream<QuerySnapshot> streamUserDonations(String citizenId) {
    return _db.collection('donations').where('citizenId', isEqualTo: citizenId).snapshots();
  }

  Future<void> submitDonation(String campaignId, Map<String, dynamic> donationData, double amount) async {
    final campaignRef = _db.collection('campaigns').doc(campaignId);
    final newDonationRef = _db.collection('donations').doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(campaignRef);
      if (!snapshot.exists) {
        throw Exception("Campaign does not exist!");
      }

      // Read current amount
      final currentAmount = (snapshot.data()!['currentAmount'] as num?)?.toDouble() ?? 0.0;
      
      // Update campaign
      transaction.update(campaignRef, {
        'currentAmount': currentAmount + amount,
      });

      // Insert donation record
      transaction.set(newDonationRef, donationData);
    });
  }

  // ── Volunteer Tasks ────────────────────────────────────────────────────────
  
  Future<void> createVolunteerTask(Map<String, dynamic> data) async {
    await _db.collection('volunteer_tasks').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> streamVolunteerTasks() {
    return _db.collection('volunteer_tasks').snapshots();
  }

  Future<void> updateVolunteerTask(String taskId, Map<String, dynamic> data) async {
    await _db.collection('volunteer_tasks').doc(taskId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
