import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';
import 'activities_screen.dart';
import 'attendance_screen.dart';
import 'card_screen.dart';
import 'competitions_screen.dart';
import 'notifications_screen.dart';
import 'points_screen.dart';
import 'profile_screen.dart';
import 'verses_screen.dart';

/// الصفحة الرئيسية: كل البيانات ديناميكية من Firestore.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final me = s.appUser!;
    final name = s.profile?.displayName ?? '';
    final isMember = me.role == 'member';
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 22),
        child: Column(children: [
          Row(children: [
            GestureDetector(onTap: isMember ? null : () => go(const ProfileScreen()), child: Avatar(photoUrl: s.profile?.photoUrl, name: name, radius: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('مرحبًا', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                Text(roleLabel(me.role, me.section), style: const TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ),
            StreamBuilder<int>(
              stream: unreadCount(me.uid),
              builder: (c, n) => Badge(
                isLabelVisible: (n.data ?? 0) > 0,
                label: Text('${n.data ?? 0}'),
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                  onPressed: () => go(const NotificationsScreen()),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          if (isMember) _PointsCard(uid: me.uid) else _StaffBanner(me: me),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (isMember) ...[
            _MemberStats(uid: me.uid),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Quick(Icons.qr_code_2, 'بطاقتي', () => go(const MemberCardScreen()))),
              const SizedBox(width: 10),
              Expanded(child: _Quick(Icons.history, 'سجلي', () => go(const MyHistoryScreen()))),
              const SizedBox(width: 10),
              Expanded(child: _Quick(Icons.menu_book, 'الآيات', () => go(const VersesScreen()))),
            ]),
          ] else
            Row(children: [
              Expanded(child: _Quick(Icons.qr_code_scanner, 'مسح QR', () => go(const ScanAttendanceScreen()))),
              const SizedBox(width: 10),
              Expanded(child: _Quick(Icons.fact_check, 'حضور يدوي', () => go(const ManualAttendanceScreen()))),
              const SizedBox(width: 10),
              Expanded(child: _Quick(Icons.stars, 'نقاط', () => go(const AddPointsScreen()))),
            ]),
          const SizedBox(height: 14),
          const VerseCard(),
          const SizedBox(height: 14),
          _NextActivity(me: me),
          const SizedBox(height: 14),
          _OpenCompetitions(me: me),
          const SizedBox(height: 14),
          _LatestNotifications(me: me),
        ]),
      ),
    ]);
  }
}

class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Quick(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AppCard(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(children: [Icon(icon, color: AppColors.royal, size: 28), const SizedBox(height: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))])),
      );
}

class _PointsCard extends StatelessWidget {
  final String uid;
  const _PointsCard({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('points').where('uid', isEqualTo: uid).snapshots(),
      builder: (context, snap) {
        // المجموع يُحسب من سجل العمليات دائمًا
        final docs = snap.data?.docs ?? <QDoc>[];
        final total = docs.fold<int>(0, (a, d) => a + ((d['amount'] as num?) ?? 0).toInt());
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

class _StaffBanner extends StatelessWidget {
  final AppUser me;
  const _StaffBanner({required this.me});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Icon(me.isGeneral ? Icons.workspace_premium : Icons.groups, size: 44, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(child: Text(me.isGeneral ? 'لوحة الإدارة العامة: كل الأقسام' : 'أنت تخدم ${sectionLabel(me.section)}. أدوات الإدارة في تبويب «الإدارة».', style: const TextStyle(color: Colors.white, height: 1.6))),
        ]),
      );
}

class _MemberStats extends StatelessWidget {
  final String uid;
  const _MemberStats({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('attendance').where('uid', isEqualTo: uid).snapshots(),
      builder: (c, s) {
        final docs = (s.data?.docs ?? <QDoc>[]).toList()..sort((a, b) => (tsOf(b['date']) ?? DateTime(2000)).compareTo(tsOf(a['date']) ?? DateTime(2000)));
        final last = docs.isEmpty ? null : docs.first;
        return Row(children: [
          Expanded(child: AppCard(child: Column(children: [const Icon(Icons.event_available, color: AppColors.success), Text('${docs.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const Text('مرات الحضور', style: TextStyle(fontSize: 12))]))),
          const SizedBox(width: 10),
          Expanded(child: AppCard(child: Column(children: [const Icon(Icons.access_time, color: AppColors.royal), Text(last == null ? '—' : fmtDate(tsOf(last['date'])!), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const Text('آخر حضور', style: TextStyle(fontSize: 12))]))),
        ]);
      },
    );
  }
}

class _NextActivity extends StatelessWidget {
  final AppUser me;
  const _NextActivity({required this.me});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QDoc>>(
      stream: mergedStream(visibleByAudience('activities', me)),
      builder: (c, s) {
        final now = DateTime.now();
        final up = (s.data ?? <QDoc>[]).where((d) => d['status'] == 'active' && tsOf(d['date']) != null && tsOf(d['date'])!.isAfter(now)).toList()
          ..sort((a, b) => tsOf(a['date'])!.compareTo(tsOf(b['date'])!));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(context, 'الرحلة / النشاط القادم', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivitiesScreen()))),
          if (up.isEmpty) const AppCard(child: Text('لا توجد أنشطة قادمة')) else ActivityTile(doc: up.first),
        ]);
      },
    );
  }
}

class _OpenCompetitions extends StatelessWidget {
  final AppUser me;
  const _OpenCompetitions({required this.me});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QDoc>>(
      stream: mergedStream(visibleByAudience('competitions', me)),
      builder: (c, s) {
        final now = DateTime.now();
        final open = (s.data ?? <QDoc>[]).where((d) => d['status'] == 'active' && (tsOf(d['endAt']) == null || tsOf(d['endAt'])!.isAfter(now))).length;
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompetitionsScreen())),
          child: AppCard(child: Row(children: [
            const Icon(Icons.emoji_events, color: AppColors.gold, size: 34),
            const SizedBox(width: 12),
            Expanded(child: Text(open == 0 ? 'لا توجد مسابقات متاحة الآن' : 'مسابقات متاحة الآن: $open', style: const TextStyle(fontWeight: FontWeight.w800))),
            const Icon(Icons.chevron_left),
          ])),
        );
      },
    );
  }
}

class _LatestNotifications extends StatelessWidget {
  final AppUser me;
  const _LatestNotifications({required this.me});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QDoc>>(
      stream: mergedStream(notificationQueries(me.uid, me.section, me.isGeneral)),
      builder: (c, s) {
        final list = (s.data ?? <QDoc>[]).toList()..sort((a, b) => (tsOf(b['createdAt']) ?? DateTime(2000)).compareTo(tsOf(a['createdAt']) ?? DateTime(2000)));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title(context, 'أحدث الإشعارات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
          if (list.isEmpty) const AppCard(child: Text('لا توجد إشعارات')),
          for (final d in list.take(3))
            Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(child: Row(children: [const Icon(Icons.notifications_active, color: AppColors.royal), const SizedBox(width: 10), Expanded(child: Text(d['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)))]))),
        ]);
      },
    );
  }
}

Widget _title(BuildContext context, String t, VoidCallback more) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const Spacer(), TextButton(onPressed: more, child: const Text('عرض الكل'))]),
    );
