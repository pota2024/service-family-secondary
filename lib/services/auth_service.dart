import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/constants.dart';
import '../core/phone_utils.dart';
import 'session.dart';

/// دخول برقم الهاتف + كلمة مرور بدون SMS: يُشتق بريد داخلي ثابت من الرقم
/// ويُستخدم مع Firebase Email/Password. الرقم لم يتم إثبات ملكيته.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> signIn(String phoneE164, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: PhoneUtils.internalEmail(phoneE164),
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  /// تسجيل جديد: ينشئ حساب Auth ثم يكتب المستندات الأربعة في دفعة واحدة.
  /// أي فشل في الكتابة يحذف حساب Auth الذي أُنشئ للتو حتى لا يبقى حساب ناقص.
  static Future<void> register({
    required Session session,
    required SignupKind kind,
    required String name,
    required String phoneE164,
    required String password,
    DateTime? birthDate,
    String? photoDataUri,
  }) async {
    session.registering = true;
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: PhoneUtils.internalEmail(phoneE164),
        password: password,
      );
    } catch (_) {
      session.registering = false;
      rethrow;
    }
    final uid = cred.user!.uid;
    try {
      final now = FieldValue.serverTimestamp();
      final batch = _db.batch();
      // أول حساب عام فقط: إذا لم تُنشأ الإعدادات بعد (settings/app) يصبح هذا الحساب هو العام الأول
      // وتُنشأ الإعدادات في نفس الدفعة فيُغلق الباب. بعد ذلك تُعتمد كل الحسابات من داخل التطبيق.
      var bootstrap = false;
      if (kind == SignupKind.general) {
        final st = await _db.doc('settings/app').get();
        bootstrap = !st.exists;
      }
      // غير ذلك: الدور دائمًا member والحالة pending؛ الدور المطلوب يُسجل في الطلب فقط.
      batch.set(_db.doc('users/$uid'), {
        'role': bootstrap ? 'general' : 'member',
        'section': kind.section,
        'status': bootstrap ? 'active' : 'pending',
        'createdAt': now,
        'updatedAt': now,
      });
      if (bootstrap) {
        batch.set(_db.doc('settings/app'), {
          'appName': AppConfig.appName,
          'boysEnabled': true,
          'girlsEnabled': true,
          'registrationEnabled': true,
          'maintenanceMode': false,
        });
      }
      batch.set(_db.doc('profiles/$uid'), {
        'displayName': name,
        if (photoDataUri != null) 'photoUrl': photoDataUri,
        'section': kind.section,
        'createdAt': now,
      });
      batch.set(_db.doc('privateUsers/$uid'), {
        'phone': phoneE164,
        if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate),
      });
      batch.set(_db.doc('registrationRequests/$uid'), {
        'uid': uid,
        'displayName': name,
        'requestedRole': kind.requestedRole,
        'requestedSection': kind.section,
        'status': bootstrap ? 'approved' : 'pending',
        'createdAt': now,
      });
      await batch.commit().timeout(const Duration(seconds: 30));
    } catch (_) {
      try {
        await cred.user!.delete();
      } catch (_) {}
      session.registering = false;
      rethrow;
    }
    session.registering = false;
  }

  static Future<void> changePassword(String oldPassword, String newPassword) async {
    final u = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: u.email!, password: oldPassword);
    await u.reauthenticateWithCredential(cred);
    await u.updatePassword(newPassword);
  }

  /// يترجم أخطاء Firebase إلى رسائل عربية واضحة.
  static String arabicError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'رقم الهاتف أو كلمة المرور غير صحيحة';
        case 'email-already-in-use':
          return 'هذا الرقم مسجل بالفعل. جرّب تسجيل الدخول';
        case 'weak-password':
          return 'كلمة المرور ضعيفة';
        case 'too-many-requests':
          return 'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة';
        case 'network-request-failed':
          return 'لا يوجد اتصال بالإنترنت';
        case 'user-disabled':
          return 'تم تعطيل هذا الحساب';
        case 'operation-not-allowed':
          return 'تسجيل الدخول بكلمة المرور غير مفعّل في Firebase (راجع ملف الإعداد)';
        case 'requires-recent-login':
          return 'سجّل الدخول من جديد ثم أعد المحاولة';
      }
      return 'خطأ في المصادقة (${e.code})';
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') return 'غير مسموح بتنفيذ هذه العملية (قواعد الأمان)';
      if (e.code == 'unavailable') return 'الخدمة غير متاحة، تحقق من الاتصال';
      return 'خطأ في قاعدة البيانات (${e.code})';
    }
    return 'حدث خطأ غير متوقع';
  }
}
