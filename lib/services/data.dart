import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

typedef QDoc = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef Q = Query<Map<String, dynamic>>;

FirebaseFirestore get db => FirebaseFirestore.instance;

DateTime? tsOf(dynamic v) => v is Timestamp ? v.toDate() : null;

/// يدمج نتائج عدة استعلامات (متنافية) في قائمة واحدة لحظية.
Stream<List<QDoc>> mergedStream(List<Q> queries) {
  late StreamController<List<QDoc>> c;
  final subs = <StreamSubscription>[];
  c = StreamController<List<QDoc>>(onListen: () {
    final latest = List<List<QDoc>?>.filled(queries.length, null);
    for (var i = 0; i < queries.length; i++) {
      subs.add(queries[i].snapshots().listen((s) {
        latest[i] = s.docs;
        if (latest.every((e) => e != null)) {
          c.add([for (final l in latest) ...l!]);
        }
      }, onError: (e) => c.addError(e)));
    }
  }, onCancel: () {
    for (final s in subs) {
      s.cancel();
    }
  });
  return c.stream;
}

/// استعلامات مجموعة لها حقل audience بحيث تُقبل من القواعد (قسمي + للجميع)، والعام يرى الكل.
List<Q> visibleByAudience(String col, AppUser me) {
  final c = db.collection(col);
  if (me.isGeneral) return [c];
  return [c.where('audience', isEqualTo: me.section), c.where('audience', isEqualTo: 'all')];
}

Map<String, dynamic> notifDoc(String uid, String title, String body, String type, [String related = '']) => {
      'uid': uid,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': related,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

/// إشعار داخل التطبيق (uid = مستخدم أو boys / girls / all للإعلان الجماعي).
Future<void> sendNotification(String uid, String title, String body, String type, [String related = '']) =>
    db.collection('notifications').add(notifDoc(uid, title, body, type, related));

class Member {
  final String uid, name, section;
  final String? photo;
  const Member(this.uid, this.name, this.section, this.photo);
}

/// المخدومون المفعّلون (الخادم: قسمه فقط، العام: الكل).
Future<List<Member>> loadMembers(AppUser me) async {
  Q uq = db.collection('users').where('role', isEqualTo: 'member').where('status', isEqualTo: 'active');
  Q pq = db.collection('profiles');
  if (!me.isGeneral) {
    uq = uq.where('section', isEqualTo: me.section);
    pq = pq.where('section', isEqualTo: me.section);
  }
  final res = await Future.wait([uq.get(), pq.get()]);
  final profiles = {for (final d in res[1].docs) d.id: Profile.fromMap(d.data() as Map<String, dynamic>)};
  final out = <Member>[];
  for (final d in res[0].docs) {
    final p = profiles[d.id];
    if (p == null) continue;
    out.add(Member(d.id, p.displayName, (d.data() as Map<String, dynamic>)['section'] as String? ?? p.section, p.photoUrl));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

/// أسماء كل من يحق لي رؤية ملفاتهم (للتقارير والقوائم).
Future<Map<String, Profile>> loadProfiles(AppUser me) async {
  Q pq = db.collection('profiles');
  if (!me.isGeneral) pq = pq.where('section', isEqualTo: me.section);
  final snap = await pq.get();
  return {for (final d in snap.docs) d.id: Profile.fromMap(d.data())};
}

final Map<String, Future<Profile?>> _profileCache = {};
Future<Profile?> cachedProfile(String uid) => _profileCache.putIfAbsent(uid, () async {
      try {
        final d = await db.doc('profiles/$uid').get();
        return d.exists ? Profile.fromMap(d.data()!) : null;
      } catch (_) {
        return null;
      }
    });

Future<int> countQ(Q q) async => (await q.count().get()).count ?? 0;
Future<num> sumQ(Q q, String field) async => (await q.aggregate(sum(field)).get()).getSum(field) ?? 0;

const pointCategories = {
  'mass': 'حضور القداس',
  'tonia': 'لبس التونية',
  'communion': 'التناول',
  'sunday_school': 'حضور مدارس الأحد',
  'manual': 'إضافة يدوية',
  'competition': 'مسابقة',
};

List<String> pointCategoriesFor(String section) => section == 'girls'
    ? ['mass', 'communion', 'sunday_school', 'manual']
    : ['mass', 'tonia', 'communion', 'sunday_school', 'manual'];

const attendanceTypes = {
  'mass': 'قداس',
  'sunday_school': 'مدارس أحد',
  'meeting': 'اجتماع',
  'trip': 'رحلة / نشاط',
  'other': 'أخرى',
};
