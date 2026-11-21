import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

enum SessionState { loading, signedOut, orphan, ready, error }

/// حالة الجلسة: المستخدم + مستند users + profile + طلب التسجيل + الإعدادات (كلها لحظية).
class Session extends ChangeNotifier {
  Session() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
  }

  final _db = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription> _subs = [];

  SessionState state = SessionState.loading;
  User? firebaseUser;
  AppUser? appUser;
  Profile? profile;
  RegistrationRequest? myRequest;
  AppSettings settings = const AppSettings();
  String? errorMessage;

  /// أثناء التسجيل ننتظر اكتمال كتابة المستندات قبل الحكم بأن الحساب ناقص.
  bool _registering = false;
  set registering(bool v) {
    _registering = v;
    if (!v && state == SessionState.loading && firebaseUser != null && appUser == null) {
      state = SessionState.orphan;
    }
    notifyListeners();
  }

  void _cancelDocs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _onAuth(User? u) {
    _cancelDocs();
    firebaseUser = u;
    appUser = null;
    profile = null;
    myRequest = null;
    errorMessage = null;
    if (u == null) {
      state = SessionState.signedOut;
      notifyListeners();
      return;
    }
    state = SessionState.loading;
    notifyListeners();
    final uid = u.uid;

    _subs.add(_db.doc('users/$uid').snapshots().listen((snap) {
      if (!snap.exists) {
        appUser = null;
        state = _registering ? SessionState.loading : SessionState.orphan;
      } else {
        appUser = AppUser.fromDoc(snap);
        state = SessionState.ready;
      }
      notifyListeners();
    }, onError: (e) {
      errorMessage = '$e';
      state = SessionState.error;
      notifyListeners();
    }));

    _subs.add(_db.doc('profiles/$uid').snapshots().listen((snap) {
      profile = snap.exists ? Profile.fromMap(snap.data()!) : null;
      notifyListeners();
    }, onError: (_) {}));

    _subs.add(_db.doc('registrationRequests/$uid').snapshots().listen((snap) {
      myRequest = snap.exists ? RegistrationRequest.fromDoc(snap) : null;
      notifyListeners();
    }, onError: (_) {}));

    _subs.add(_db.doc('settings/app').snapshots().listen((snap) {
      settings = AppSettings.fromMap(snap.data());
      // أول تشغيل: العام يُنشئ settings/app فيُغلق باب إنشاء "أول حساب عام" نهائيًا.
      if (!snap.exists && appUser?.isGeneral == true) {
        _db.doc('settings/app').set({
          'appName': 'خدمة أسرة ثانوي',
          'boysEnabled': true,
          'girlsEnabled': true,
          'registrationEnabled': true,
          'maintenanceMode': false,
        }).catchError((_) {});
      }
      notifyListeners();
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDocs();
    super.dispose();
  }
}
