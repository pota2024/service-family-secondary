/// ثوابت التطبيق.
///
/// تنبيه أمني: الكودان [servantCode] و[generalCode] يوجدان داخل التطبيق ويمكن
/// استخراجهما. وظيفتهما فقط إظهار واجهة معينة. الصلاحية الفعلية لا تُمنح إلا
/// باعتماد الإدارة، وتفرضها قواعد Firestore (firestore.rules).
class AppConfig {
  static const appName = 'خدمة أسرة ثانوي';
  static const churchName = 'كنيسة الشهيد العظيم مارجرجس أبو زعل البلد';
  static const servantCode = '2580';
  static const generalCode = '0001';
  static const maxPhotoBytes = 180 * 1024;
  static const minPasswordLength = 8;
}

/// خيارات التسجيل الخمسة.
enum SignupKind { boysMember, girlsMember, boysServant, girlsServant, general }

extension SignupKindX on SignupKind {
  String get label => switch (this) {
        SignupKind.boysMember => 'أسرة ثانوي بنين 💪🏻',
        SignupKind.girlsMember => 'أسرة ثانوي بنات 👑',
        SignupKind.boysServant => 'خدام بنين',
        SignupKind.girlsServant => 'خدام بنات',
        SignupKind.general => 'عام',
      };

  String get requestedRole => switch (this) {
        SignupKind.boysMember || SignupKind.girlsMember => 'member',
        SignupKind.boysServant || SignupKind.girlsServant => 'servant',
        SignupKind.general => 'general',
      };

  String get section => switch (this) {
        SignupKind.boysMember || SignupKind.boysServant => 'boys',
        SignupKind.girlsMember || SignupKind.girlsServant => 'girls',
        SignupKind.general => 'all',
      };

  bool get isMember => requestedRole == 'member';
  bool get needsServantCode => requestedRole == 'servant';
}

String sectionLabel(String section) => switch (section) {
      'boys' => 'قسم البنين',
      'girls' => 'قسم البنات',
      _ => 'جميع الأقسام',
    };

String roleLabel(String role, String section) => switch (role) {
      'general' => 'مسؤول عام',
      'servant' => section == 'girls' ? 'خادمة بنات' : 'خادم بنين',
      _ => section == 'girls' ? 'مخدومة – بنات' : 'مخدوم – بنين',
    };
