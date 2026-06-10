import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerTaskModel {
  final String id;
  final String squadName;
  final String squadId; // ADDED - which squad this task is for
  final String zone;
  final String priority;
  final String status;
  final double progress;
  final String taskDescription;
  final String assignedVolunteer;
  final String eta;
  final String lastKnownLocation;
  final double? currentLat;
  final double? currentLng;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final int requiredVolunteerCount;
  final List<String> acceptedVolunteerUIDs;
  final List<String> declinedVolunteerUIDs;
  final Timestamp? broadcastedAt;
  final String disasterZoneId;

  VolunteerTaskModel({
    required this.id,
    required this.squadName,
    required this.squadId, // ADDED
    required this.zone,
    this.priority = 'Sederhana',
    required this.status,
    required this.progress,
    required this.taskDescription,
    this.assignedVolunteer = '',
    this.eta = '-',
    this.lastKnownLocation = '',
    this.currentLat,
    this.currentLng,
    this.createdAt,
    this.updatedAt,
    this.requiredVolunteerCount = 4,
    this.acceptedVolunteerUIDs = const [],
    this.declinedVolunteerUIDs = const [],
    this.broadcastedAt,
    this.disasterZoneId = '',
  });

  factory VolunteerTaskModel.fromMap(String id, Map<String, dynamic> map) {
    return VolunteerTaskModel(
      id: id,
      squadName: map['squadName'] ?? '',
      squadId: map['squadId'] ?? '', // ADDED
      zone: map['zone'] ?? '',
      priority: map['priority'] ?? 'Sederhana',
      status: map['status'] ?? 'Menuju ke Lokasi',
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      taskDescription: map['taskDescription'] ?? '',
      assignedVolunteer: map['assignedVolunteer'] ?? '',
      eta: map['eta'] ?? '-',
      lastKnownLocation: map['lastKnownLocation'] ?? '',
      currentLat: (map['currentLat'] as num?)?.toDouble(),
      currentLng: (map['currentLng'] as num?)?.toDouble(),
      createdAt: map['createdAt'] as Timestamp?,
      updatedAt: map['updatedAt'] as Timestamp?,
      requiredVolunteerCount:
          (map['requiredVolunteerCount'] as num?)?.toInt() ?? 4,
      acceptedVolunteerUIDs:
          List<String>.from(map['acceptedVolunteerUIDs'] ?? []),
      declinedVolunteerUIDs:
          List<String>.from(map['declinedVolunteerUIDs'] ?? []),
      broadcastedAt: map['broadcastedAt'] as Timestamp?,
      disasterZoneId: map['disasterZoneId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'squadName': squadName,
      'squadId': squadId, // ADDED
      'zone': zone,
      'priority': priority,
      'status': status,
      'progress': progress,
      'taskDescription': taskDescription,
      'assignedVolunteer': assignedVolunteer,
      'eta': eta,
      'lastKnownLocation': lastKnownLocation,
      'currentLat': currentLat,
      'currentLng': currentLng,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': updatedAt,
      'requiredVolunteerCount': requiredVolunteerCount,
      'acceptedVolunteerUIDs': acceptedVolunteerUIDs,
      'declinedVolunteerUIDs': declinedVolunteerUIDs,
      'broadcastedAt': broadcastedAt,
      'disasterZoneId': disasterZoneId,
    };
  }
  
  bool hasAccepted(String uid) => acceptedVolunteerUIDs.contains(uid);
  bool hasDeclined(String uid) => declinedVolunteerUIDs.contains(uid);
  bool get isFull => acceptedVolunteerUIDs.length >= requiredVolunteerCount;
  bool canAccept(String uid) => 
      !hasAccepted(uid) && 
      !hasDeclined(uid) && 
      !isFull && 
      status != 'Selesai Tugas';
}