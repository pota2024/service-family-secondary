import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'data.dart';

/// تسجيل حضور مخدوم. المعرّف eventId_uid يمنع التكرار. يرجع null عند النجاح أو رسالة الخطأ.
Future<String?> recordAttendance({
  required AppUser me,
  required Member member,
  required String type,
  required DateTime day,
}) async {
  final eventId = '$type-${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
  try {
    final dup = await db
        .collection('attendance')
        .where('uid', isEqualTo: member.uid)
        .where('eventId', isEqualTo: eventId)
        .where('section', isEqualTo: member.section)
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) return 'تم تسجيل حضور ${member.name} مسبقًا لهذه الفعالية';
    await db.doc('attendance/${eventId}_${member.uid}').set({
      'uid': member.uid,
      'section': member.section,
      'eventId': eventId,
      'type': type,
      'date': Timestamp.fromDate(DateTime(day.year, day.month, day.day)),
      'createdBy': me.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return null;
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') return 'غير مسموح: المخدوم ليس مفعّلًا أو ليس من قسمك';
    return 'تعذر التسجيل (${e.code})';
  }
}

/// إضافة نقاط مع سجل السبب والخادم، وإشعار للمخدوم.
Future<void> addPoints({
  required AppUser me,
  required Member member,
  required int amount,
  required String reason,
  required String category,
}) async {
  final batch = db.batch();
  batch.set(db.collection('points').doc(), {
    'uid': member.uid,
    'section': member.section,
    'amount': amount,
    'reason': reason,
    'category': category,
    'createdBy': me.uid,
    'createdAt': FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('notifications').doc(), notifDoc(member.uid, 'تمت إضافة نقاط', 'حصلت على $amount نقطة: $reason', 'points'));
  await batch.commit();
}
