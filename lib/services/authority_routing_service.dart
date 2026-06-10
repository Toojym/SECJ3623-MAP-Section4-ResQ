import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents an emergency authority contact routed for an incident type.
class AuthorityContact {
  final String name;
  final String shortName;
  final String phone;
  final String description;
  final IconData icon;
  final Color color;

  const AuthorityContact({
    required this.name,
    required this.shortName,
    required this.phone,
    required this.description,
    required this.icon,
    required this.color,
  });
}

/// Service that routes SOS incident types to the appropriate Malaysian emergency authority.
class AuthorityRoutingService {
  AuthorityRoutingService._();
  static final AuthorityRoutingService instance = AuthorityRoutingService._();

  static const _bomba = AuthorityContact(
    name: 'Jabatan Bomba dan Penyelamat Malaysia',
    shortName: 'Bomba',
    phone: '994',
    description: 'Kebakaran, penyelamatan teknikal, dan kecemasan bangunan.',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFEF4444),
  );

  static const _ambulance = AuthorityContact(
    name: 'Perkhidmatan Ambulans (Hospital)',
    shortName: 'Ambulans',
    phone: '999',
    description: 'Kecemasan perubatan, kemalangan, dan kes kritikal.',
    icon: Icons.medical_services_rounded,
    color: Color(0xFF10B981),
  );

  static const _police = AuthorityContact(
    name: 'Polis Diraja Malaysia (PDRM)',
    shortName: 'Polis',
    phone: '999',
    description: 'Orang hilang, jenayah, keselamatan awam, dan gangguan.',
    icon: Icons.local_police_rounded,
    color: Color(0xFF3B82F6),
  );

  static const _nadma = AuthorityContact(
    name: 'Agensi Pengurusan Bencana Negara (NADMA)',
    shortName: 'NADMA',
    phone: '03-8064 2400',
    description: 'Bencana banjir, tanah runtuh, dan kecemasan alam sekitar.',
    icon: Icons.flood_rounded,
    color: Color(0xFF6366F1),
  );

  static const _general = AuthorityContact(
    name: 'Talian Kecemasan Malaysia',
    shortName: 'Kecemasan',
    phone: '999',
    description: 'Talian kecemasan am Malaysia.',
    icon: Icons.emergency_rounded,
    color: Color(0xFFF59E0B),
  );

  /// Returns the appropriate [AuthorityContact] based on SOS incident type.
  AuthorityContact getAuthority(String incidentType) {
    switch (incidentType.toLowerCase()) {
      case 'kebakaran':
        return _bomba;
      case 'perubatan':
      case 'kecemasan perubatan':
      case 'kemalangan':
        return _ambulance;
      case 'orang hilang':
      case 'kehilangan':
        return _police;
      case 'banjir':
      case 'tanah runtuh':
      case 'bencana alam':
        return _nadma;
      default:
        return _general;
    }
  }

  /// Returns a map representation suitable for writing to Firestore.
  Map<String, dynamic> getAuthorityData(String incidentType) {
    final authority = getAuthority(incidentType);
    return {
      'name': authority.name,
      'shortName': authority.shortName,
      'phone': authority.phone,
    };
  }

  /// Launches the device dialer with the authority's phone number.
  Future<void> callAuthority(AuthorityContact authority) async {
    final uri = Uri(scheme: 'tel', path: authority.phone.replaceAll('-', '').replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
