import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// طلبات التسجيل المعلقة التي يحق لهذا المستخدم مراجعتها.
/// العام: كل الطلبات. الخادم: طلبات المخدومين في قسمه فقط.
Query<Map<String, dynamic>> pendingRequestsQuery(AppUser me) {
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('registrationRequests')
      .where('status', isEqualTo: 'pending');
  if (!me.isGeneral) {
    q = q
        .where('requestedRole', isEqualTo: 'member')
        .where('requestedSection', isEqualTo: me.section);
  }
  return q;
}
