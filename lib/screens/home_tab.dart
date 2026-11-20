import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/session.dart';
import '../widgets/common.dart';

/// الصفحة الرئيسية (المرحلة 1): بطاقة المستخدم ومجموع النقاط من سجل العمليات.
/// المجموع يُحسب من مجموعة points ولا يُخزن كرقم منفصل.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final me = s.appUser!;
    final name = s.profile?.displayName ?? '';
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 26),
        child: Column(children: [
          Row(children: [
            Avatar(photoUrl: s.profile?.photoUrl, name: name, radius: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مرحبًا', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                Text(roleLabel(me.role, me.section), style: const TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          if (me.role == 'member') _PointsCard(uid: me.uid) else _StaffCard(role: me.role, section: me.section),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(18),
        child: AppCard(
          child: Row(children: [
            const Icon(Icons.verified_user, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text('حسابك مفعّل – ${sectionLabel(me.section)}. بقية الأقسام (الحضور، المسابقات، الأنشطة، الشات) تُضاف في المراحل التالية.',
                  style: const TextStyle(height: 1.6, fontSize: 13)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _PointsCard extends StatelessWidget {
  final String uid;
  const _PointsCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('points').where('uid', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        var total = 0;
        final docs = snap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        for (final d in docs) {
          total += (d.data()['amount'] as num? ?? 0).toInt();
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(colors: [AppColors.royalDark, AppColors.royal], begin: Alignment.centerRight, end: Alignment.centerLeft),
            border: Border.all(color: AppColors.gold.withOpacity(0.7), width: 1.4),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium, size: 56, color: AppColors.gold),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مجموع نقاطك', style: TextStyle(color: Colors.white70)),
                snap.connectionState == ConnectionState.waiting
                    ? const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                    : Text('$total نقطة', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _StaffCard extends StatelessWidget {
  final String role, section;
  const _StaffCard({required this.role, required this.section});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Icon(role == 'general' ? Icons.workspace_premium : Icons.groups, size: 44, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              role == 'general' ? 'لوحة الإدارة العامة: راجع طلبات التسجيل من تبويب «الطلبات».' : 'راجع طلبات تسجيل مخدومي ${sectionLabel(section)} من تبويب «الطلبات».',
              style: const TextStyle(color: Colors.white, height: 1.6),
            ),
          ),
        ]),
      );
}
