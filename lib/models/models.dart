import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String role; // member / servant / general
  final String section; // boys / girls / all
  final String status; // pending / active / rejected / suspended
  const AppUser({required this.uid, required this.role, required this.section, required this.status});

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppUser(
      uid: d.id,
      role: (m['role'] ?? 'member') as String,
      section: (m['section'] ?? 'boys') as String,
      status: (m['status'] ?? 'pending') as String,
    );
  }

  bool get isActive => status == 'active';
  bool get isGeneral => isActive && role == 'general';
  bool get isServant => isActive && role == 'servant';
  bool get canReview => isGeneral || isServant;
}

class Profile {
  final String displayName;
  final String? photoUrl;
  final String section;
  const Profile({required this.displayName, this.photoUrl, required this.section});

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        displayName: (m['displayName'] ?? '') as String,
        photoUrl: m['photoUrl'] as String?,
        section: (m['section'] ?? 'boys') as String,
      );
}

class RegistrationRequest {
  final String uid;
  final String displayName;
  final String requestedRole;
  final String requestedSection;
  final String status;
  final DateTime? createdAt;
  const RegistrationRequest({
    required this.uid,
    required this.displayName,
    required this.requestedRole,
    required this.requestedSection,
    required this.status,
    this.createdAt,
  });

  factory RegistrationRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return RegistrationRequest(
      uid: d.id,
      displayName: (m['displayName'] ?? '') as String,
      requestedRole: (m['requestedRole'] ?? 'member') as String,
      requestedSection: (m['requestedSection'] ?? 'boys') as String,
      status: (m['status'] ?? 'pending') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AppSettings {
  final bool boysEnabled, girlsEnabled, registrationEnabled, maintenanceMode;
  const AppSettings({this.boysEnabled = true, this.girlsEnabled = true, this.registrationEnabled = true, this.maintenanceMode = false});

  factory AppSettings.fromMap(Map<String, dynamic>? m) => m == null
      ? const AppSettings()
      : AppSettings(
          boysEnabled: m['boysEnabled'] != false,
          girlsEnabled: m['girlsEnabled'] != false,
          registrationEnabled: m['registrationEnabled'] != false,
          maintenanceMode: m['maintenanceMode'] == true,
        );
}
