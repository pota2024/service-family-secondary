import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

/// إحصائيات لحظية: العام يرى الكل مع فلتر قسم/نوع، والخادم يرى قسمه.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _section; // null = الكل (للعام)
  String? _type;
  Future<Map<String, num>>? _future;

  Future<Map<String, num>> _load(AppUser me) async {
    final sec = me.isGeneral ? _section : me.section;
    Q users(String role) {
      Q q = db.collection('users').where('role', isEqualTo: role).where('status', isEqualTo: 'active');
      if (sec != null) q = q.where('section', isEqualTo: sec);
      return q;
    }
    Q att = db.collection('attendance');
    Q pts = db.collection('points');
    if (sec != null) {
      att = att.where('section', isEqualTo: sec);
      pts = pts.where('section', isEqualTo: sec);
    }
    if (_type != null) att = att.where('type', isEqualTo: _type);
    Q pending = db.collection('registrationRequests').where('status', isEqualTo: 'pending');
    if (!me.isGeneral) pending = pending.where('requestedSection', isEqualTo: me.section);
    final r = await Future.wait<num>([
      countQ(users('member')),
      countQ(users('servant')),
      countQ(pending),
      countQ(att),
      sumQ(pts, 'amount'),
      me.isGeneral ? countQ(db.collection('competitions')) : countQ(db.collection('competitions').where('audience', isEqualTo: me.section)),
      me.isGeneral
          ? countQ(db.collection('activities').where('date', isGreaterThanOrEqualTo: DateTime.now()))
          : countQ(db.collection('activities').where('audience', isEqualTo: me.section)),
    ]);
    return {'members': r[0], 'servants': r[1], 'pending': r[2], 'att': r[3], 'pts': r[4], 'comp': r[5], 'acts': r[6]};
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    _future ??= _load(me);
    return Scaffold(
      appBar: gradAppBar('الإحصائيات', actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => _future = _load(me)))]),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          if (me.isGeneral)
            Expanded(
              child: DropdownButtonFormField<String?>(
                value: _section,
                decoration: const InputDecoration(labelText: 'القسم'),
                items: const [DropdownMenuItem(value: null, child: Text('الكل')), DropdownMenuItem(value: 'boys', child: Text('بنين')), DropdownMenuItem(value: 'girls', child: Text('بنات'))],
                onChanged: (v) => setState(() { _section = v; _future = null; }),
              ),
            ),
          if (me.isGeneral) const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _type,
              decoration: const InputDecoration(labelText: 'نوع الحضور'),
              items: [const DropdownMenuItem(value: null, child: Text('الكل')), for (final e in attendanceTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() { _type = v; _future = null; }),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        FutureBuilder<Map<String, num>>(
          future: _future,
          builder: (c, s) {
            if (s.hasError) return const EmptyState('تعذر تحميل الإحصائيات');
            if (!s.hasData) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            final d = s.data!;
            Widget card(String t, num v, IconData i, Color col) => AppCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(i, color: col, size: 28),
                  const SizedBox(height: 6),
                  Text('${v.toInt()}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                ]));
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                card('المخدومون', d['members']!, Icons.groups, AppColors.royal),
                card('الخدام', d['servants']!, Icons.volunteer_activism, AppColors.sky),
                card('طلبات التسجيل', d['pending']!, Icons.how_to_reg, AppColors.goldDark),
                card('إجمالي الحضور', d['att']!, Icons.event_available, AppColors.success),
                card('إجمالي النقاط', d['pts']!, Icons.stars, AppColors.gold),
                card('المسابقات', d['comp']!, Icons.emoji_events, AppColors.goldDark),
                card(me.isGeneral ? 'الأنشطة القادمة' : 'أنشطة القسم', d['acts']!, Icons.event, AppColors.royal),
              ],
            );
          },
        ),
      ]),
    );
  }
}
