import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/phone_utils.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/queries.dart';
import '../services/session.dart';
import '../widgets/common.dart';

/// مراجعة طلبات التسجيل.
/// العام: كل الطلبات (مخدومين، خدام، عام). الخادم: مخدومو قسمه فقط.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات التسجيل'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.headerGradient)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pendingRequestsQuery(me).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(AuthService.arabicError(snap.error!)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!.docs.map(RegistrationRequest.fromDoc).toList()
            ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد طلبات معلقة', style: TextStyle(fontSize: 16)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _RequestTile(req: items[i], me: me),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final RegistrationRequest req;
  final AppUser me;
  const _RequestTile({required this.req, required this.me});
  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _busy = false;

  String get _typeLabel => switch (widget.req.requestedRole) {
        'servant' => 'طلب خادم/خادمة – ${sectionLabel(widget.req.requestedSection)}',
        'general' => 'طلب حساب عام',
        _ => 'مخدوم – ${sectionLabel(widget.req.requestedSection)}',
      };

  Future<void> _review(bool approve) async {
    if (!approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('رفض الطلب؟'),
          content: Text('سيتم رفض طلب ${widget.req.displayName}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('رفض')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final r = widget.req;
      final db = FirebaseFirestore.instance;
      final now = FieldValue.serverTimestamp();
      final batch = db.batch();
      final userUpdate = <String, dynamic>{'status': approve ? 'active' : 'rejected', 'updatedAt': now};
      // رفع الدور (خادم/عام) مسموح للعام فقط؛ القواعد ترفض أي محاولة غير ذلك.
      if (approve && r.requestedRole != 'member') userUpdate['role'] = r.requestedRole;
      if (approve && r.requestedRole == 'general' && !widget.me.isGeneral) throw 'اعتماد حساب عام من صلاحية الإدارة العامة فقط';
      batch.update(db.doc('users/${r.uid}'), userUpdate);
      batch.update(db.doc('registrationRequests/${r.uid}'), {
        'status': approve ? 'approved' : 'rejected',
        'reviewedBy': widget.me.uid,
        'reviewedAt': now,
      });
      batch.set(db.collection('notifications').doc(), {
        'uid': r.uid,
        'title': approve ? 'تم قبول حسابك' : 'تم رفض طلب التسجيل',
        'body': approve ? 'يمكنك الآن استخدام التطبيق.' : 'تواصل مع الخدام لمعرفة السبب.',
        'type': 'account',
        'relatedId': '',
        'read': false,
        'createdAt': now,
      });
      await batch.commit();
      if (mounted) showSnack(context, approve ? 'تم قبول الطلب' : 'تم رفض الطلب');
    } catch (e) {
      if (mounted) showSnack(context, e is String ? e : AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.req;
    final db = FirebaseFirestore.instance;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.doc('profiles/${r.uid}').snapshots(),
            builder: (_, s) => Avatar(photoUrl: s.data?.data()?['photoUrl'] as String?, name: r.displayName, radius: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(_typeLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.royal, fontWeight: FontWeight.w700)),
              if (widget.me.isGeneral)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: db.doc('privateUsers/${r.uid}').get(),
                  builder: (_, s) {
                    final p = s.data?.data()?['phone'] as String?;
                    return p == null
                        ? const SizedBox.shrink()
                        : Directionality(textDirection: TextDirection.ltr, child: Text(PhoneUtils.display(p), style: const TextStyle(fontSize: 12.5)));
                  },
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GradientButton(label: 'قبول', icon: Icons.check, loading: _busy, onPressed: () => _review(true))),
          const SizedBox(width: 10),
          Expanded(child: SoftOutlineButton(label: 'رفض', icon: Icons.close, onPressed: _busy ? null : () => _review(false))),
        ]),
      ]),
    );
  }
}
