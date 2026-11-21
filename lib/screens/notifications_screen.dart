import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

IconData _icon(String? t) => switch (t) {
      'points' => Icons.stars,
      'competition' => Icons.emoji_events,
      'activity' => Icons.event,
      'account' => Icons.verified_user,
      'announcement' => Icons.campaign,
      _ => Icons.notifications,
    };

List<Q> notificationQueries(String uid, String section, bool general) => [
      db.collection('notifications').where('uid', isEqualTo: uid),
      db.collection('notifications').where('uid', isEqualTo: 'all'),
      if (!general) db.collection('notifications').where('uid', isEqualTo: section),
    ];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar('الإشعارات'),
      body: StreamBuilder<List<QDoc>>(
        stream: mergedStream(notificationQueries(me.uid, me.section, me.isGeneral)),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.toList()..sort((a, b) => (tsOf(b['createdAt']) ?? DateTime.now()).compareTo(tsOf(a['createdAt']) ?? DateTime.now()));
          if (docs.isEmpty) return const EmptyState('لا توجد إشعارات', icon: Icons.notifications_none);
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = docs[i];
              final own = d['uid'] == me.uid;
              final unread = own && d['read'] == false;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: unread ? () => d.reference.update({'read': true}) : null,
                child: AppCard(
                  child: Row(children: [
                    CircleAvatar(backgroundColor: unread ? AppColors.gold.withOpacity(0.2) : AppColors.paleSky, child: Icon(_icon(d['type'] as String?), color: unread ? AppColors.goldDark : AppColors.royal)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['title'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                      if ((d['body'] as String).isNotEmpty) Text(d['body'] as String, style: const TextStyle(fontSize: 13, height: 1.5)),
                      if (tsOf(d['createdAt']) != null) Text(fmtDateTime(tsOf(d['createdAt'])!), style: const TextStyle(fontSize: 11, color: Colors.black45)),
                    ])),
                    if (unread) const CircleAvatar(radius: 5, backgroundColor: AppColors.danger),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// عدد الإشعارات الشخصية غير المقروءة (للجرس).
Stream<int> unreadCount(String uid) =>
    db.collection('notifications').where('uid', isEqualTo: uid).where('read', isEqualTo: false).snapshots().map((s) => s.size);
