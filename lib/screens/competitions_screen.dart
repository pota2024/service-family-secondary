import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

String _subLabel(String? s) => switch (s) { 'pending' => 'قيد المراجعة', 'approved' => 'تم الاعتماد', 'rejected' => 'مرفوضة', _ => 'متاحة' };
Color _subColor(String? s) => switch (s) { 'pending' => AppColors.goldDark, 'approved' => AppColors.success, 'rejected' => AppColors.danger, _ => AppColors.royal };

class CompetitionsScreen extends StatelessWidget {
  const CompetitionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar('مسابقات'),
      floatingActionButton: me.canReview
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompetitionFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('مسابقة جديدة'))
          : null,
      body: StreamBuilder<List<QDoc>>(
        stream: mergedStream(visibleByAudience('competitions', me)),
        builder: (c, snap) {
          if (snap.hasError) return EmptyState(AuthService.arabicError(snap.error!));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.where((d) => me.canReview || d['status'] == 'active').toList()
            ..sort((a, b) => (tsOf(b['createdAt']) ?? DateTime.now()).compareTo(tsOf(a['createdAt']) ?? DateTime.now()));
          if (docs.isEmpty) return const EmptyState('لا توجد مسابقات حاليًا', icon: Icons.emoji_events_outlined);
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: me.role == 'member' ? db.collection('competitionSubmissions').where('uid', isEqualTo: me.uid).snapshots() : const Stream.empty(),
            builder: (c, subSnap) {
              final subs = {for (final d in subSnap.data?.docs ?? <QDoc>[]) d['competitionId'] as String: d['status'] as String};
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final st = subs[d.id];
                  final active = d['status'] == 'active';
                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompetitionDetailScreen(id: d.id))),
                    child: AppCard(
                      child: Row(children: [
                        const CircleAvatar(radius: 26, backgroundColor: AppColors.paleSky, child: Icon(Icons.emoji_events, color: AppColors.gold, size: 30)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${d['points']} نقطة • ${secShort(d['audience'] as String)}', style: const TextStyle(fontSize: 12.5)),
                          if (tsOf(d['endAt']) != null) Text('ينتهي ${fmtDate(tsOf(d['endAt'])!)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ])),
                        if (me.role == 'member') Pill(_subLabel(st), _subColor(st)) else Pill(active ? 'مفعّلة' : 'موقوفة', active ? AppColors.success : AppColors.danger),
                      ]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class CompetitionDetailScreen extends StatefulWidget {
  final String id;
  const CompetitionDetailScreen({super.key, required this.id});
  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  final _evidence = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _open(String link) async {
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showSnack(context, 'تعذر فتح الرابط', error: true);
  }

  Future<void> _submit(AppUser me) async {
    if (_evidence.text.trim().isEmpty) {
      showSnack(context, 'اكتب إثبات الحل أو تفاصيل مشاركتك', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await db.doc('competitionSubmissions/${widget.id}_${me.uid}').set({
        'competitionId': widget.id,
        'uid': me.uid,
        'section': me.section,
        'answerEvidence': _evidence.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showSnack(context, 'تم إرسال مشاركتك للمراجعة');
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(AppUser me, QDoc sub, Map<String, dynamic> comp, bool approve) async {
    int pts = (comp['points'] as num).toInt();
    if (approve) {
      final ctl = TextEditingController(text: '$pts');
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('اعتماد الحل'),
          content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد النقاط الممنوحة')),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('اعتماد'))],
        ),
      );
      if (ok != true) return;
      pts = int.tryParse(ctl.text.trim()) ?? -1;
      if (pts < 0 || pts > 1000) {
        if (mounted) showSnack(context, 'عدد نقاط غير صالح', error: true);
        return;
      }
    }
    try {
      final uid = sub['uid'] as String;
      final b = db.batch();
      b.update(sub.reference, {'status': approve ? 'approved' : 'rejected', 'reviewedBy': me.uid, 'reviewedAt': FieldValue.serverTimestamp()});
      if (approve && pts > 0) {
        b.set(db.doc('points/comp_${widget.id}_$uid'), {
          'uid': uid,
          'section': sub['section'],
          'amount': pts,
          'reason': 'مسابقة: ${comp['title']}',
          'category': 'competition',
          'competitionId': widget.id,
          'createdBy': me.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      b.set(db.collection('notifications').doc(), notifDoc(uid, approve ? 'تم اعتماد حل المسابقة' : 'تم رفض حل المسابقة', approve ? 'حصلت على $pts نقطة في "${comp['title']}"' : 'راجع الخادم لمعرفة السبب', 'competition', widget.id));
      await b.commit();
      if (mounted) showSnack(context, approve ? 'تم الاعتماد وإضافة النقاط' : 'تم الرفض');
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.doc('competitions/${widget.id}').snapshots(),
      builder: (c, snap) {
        if (!snap.hasData) return Scaffold(appBar: gradAppBar('المسابقة'), body: const Center(child: CircularProgressIndicator()));
        final d = snap.data!.data();
        if (d == null) return Scaffold(appBar: gradAppBar('المسابقة'), body: const EmptyState('المسابقة غير موجودة'));
        final end = tsOf(d['endAt']);
        final start = tsOf(d['startAt']);
        final now = DateTime.now();
        final open = d['status'] == 'active' && (start == null || !now.isBefore(start)) && (end == null || !now.isAfter(end));
        return Scaffold(
          appBar: gradAppBar('المسابقة', actions: [
            if (me.canReview && (me.isGeneral || d['audience'] == me.section))
              IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CompetitionFormScreen(id: widget.id, data: d)))),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['title'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [Pill('${d['points']} نقطة', AppColors.goldDark), Pill(secShort(d['audience'] as String), AppColors.royal), Pill(open ? 'مفتوحة' : 'مغلقة', open ? AppColors.success : AppColors.danger)]),
              if ((d['description'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 12), child: Text(d['description'] as String, style: const TextStyle(height: 1.7))),
              const SizedBox(height: 10),
              if (start != null) Text('البداية: ${fmtDateTime(start)}'),
              if (end != null) Text('النهاية: ${fmtDateTime(end)}'),
            ])),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => _open(d['link'] as String), icon: const Icon(Icons.open_in_new), label: const Text('فتح رابط المسابقة'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50))),
            const Padding(padding: EdgeInsets.all(8), child: Text('فتح الرابط لا يمنح نقاطًا. بعد حل المسابقة أرسل إثبات الحل هنا ليراجعه الخادم.', style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.6))),
            if (me.role == 'member') _memberPart(me, open) else _staffPart(me, d),
          ]),
        );
      },
    );
  }

  Widget _memberPart(AppUser me, bool open) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.doc('competitionSubmissions/${widget.id}_${me.uid}').snapshots(),
      builder: (c, s) {
        final sub = s.data?.data();
        if (sub != null) {
          return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Text('حالة مشاركتك: ', style: TextStyle(fontWeight: FontWeight.w700)), Pill(_subLabel(sub['status'] as String?), _subColor(sub['status'] as String?))]),
            const SizedBox(height: 8),
            Text(sub['answerEvidence'] as String, style: const TextStyle(height: 1.6)),
          ]));
        }
        if (!open) return const SizedBox.shrink();
        return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إرسال الحل', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(controller: _evidence, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'اكتب إجاباتك أو درجتك أو رابط إثبات الحل')),
          GradientButton(label: 'إرسال للمراجعة', loading: _busy, onPressed: () => _submit(me)),
        ]));
      },
    );
  }

  Widget _staffPart(AppUser me, Map<String, dynamic> comp) {
    Q q = db.collection('competitionSubmissions').where('competitionId', isEqualTo: widget.id);
    if (!me.isGeneral) q = q.where('section', isEqualTo: me.section);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final docs = s.data!.docs.toList()..sort((a, b) => (tsOf(a['createdAt']) ?? DateTime.now()).compareTo(tsOf(b['createdAt']) ?? DateTime.now()));
        if (docs.isEmpty) return const EmptyState('لا توجد مشاركات بعد');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('المشاركات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          for (final sub in docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FutureBuilder<Profile?>(
                  future: cachedProfile(sub['uid'] as String),
                  builder: (c, p) => Row(children: [
                    Avatar(photoUrl: p.data?.photoUrl, name: p.data?.displayName ?? '', radius: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.data?.displayName ?? '...', style: const TextStyle(fontWeight: FontWeight.w800))),
                    Pill(_subLabel(sub['status'] as String), _subColor(sub['status'] as String)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text(sub['answerEvidence'] as String, style: const TextStyle(height: 1.6)),
                if (sub['status'] == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: () => _review(me, sub, comp, true), icon: const Icon(Icons.check), label: const Text('اعتماد'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _review(me, sub, comp, false), icon: const Icon(Icons.close), label: const Text('رفض'))),
                  ]),
                ],
              ])),
            ),
        ]);
      },
    );
  }
}

class CompetitionFormScreen extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;
  const CompetitionFormScreen({super.key, this.id, this.data});
  @override
  State<CompetitionFormScreen> createState() => _CompetitionFormScreenState();
}

class _CompetitionFormScreenState extends State<CompetitionFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.data?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.data?['description'] as String? ?? '');
  late final _link = TextEditingController(text: widget.data?['link'] as String? ?? '');
  late final _points = TextEditingController(text: '${widget.data?['points'] ?? 10}');
  late String _audience = widget.data?['audience'] as String? ?? '';
  late DateTime _start = tsOf(widget.data?['startAt']) ?? DateTime.now();
  late DateTime _end = tsOf(widget.data?['endAt']) ?? DateTime.now().add(const Duration(days: 7));
  late bool _active = (widget.data?['status'] ?? 'active') == 'active';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final me = context.read<Session>().appUser!;
    if (_audience.isEmpty) _audience = me.isGeneral ? 'all' : me.section;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final me = context.read<Session>().appUser!;
    setState(() => _busy = true);
    try {
      final body = {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'link': _link.text.trim(),
        'audience': _audience,
        'points': int.parse(_points.text.trim()),
        'startAt': Timestamp.fromDate(_start),
        'endAt': Timestamp.fromDate(_end),
        'status': _active ? 'active' : 'inactive',
      };
      if (widget.id == null) {
        final ref = db.collection('competitions').doc();
        final b = db.batch();
        b.set(ref, {...body, 'createdBy': me.uid, 'createdAt': FieldValue.serverTimestamp()});
        b.set(db.collection('notifications').doc(), notifDoc(_audience, 'مسابقة جديدة', _title.text.trim(), 'competition', ref.id));
        await b.commit();
      } else {
        await db.doc('competitions/${widget.id}').update(body);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar(widget.id == null ? 'مسابقة جديدة' : 'تعديل المسابقة'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان المسابقة'), validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _link,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رابط المسابقة (https://...)'),
            validator: (v) => RegExp(r'^https?://.+').hasMatch((v ?? '').trim()) ? null : 'أدخل رابطًا يبدأ بـ http أو https',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _audience,
            decoration: const InputDecoration(labelText: 'القسم المستهدف'),
            items: [
              if (me.isGeneral || me.section == 'boys') const DropdownMenuItem(value: 'boys', child: Text('بنين')),
              if (me.isGeneral || me.section == 'girls') const DropdownMenuItem(value: 'girls', child: Text('بنات')),
              if (me.isGeneral) const DropdownMenuItem(value: 'all', child: Text('عام (الكل)')),
            ],
            onChanged: (v) => setState(() => _audience = v ?? _audience),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _points,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              return n == null || n < 0 || n > 1000 ? '0 إلى 1000' : null;
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFD8E3FA))),
            leading: const Icon(Icons.play_arrow), title: const Text('البداية'), subtitle: Text(fmtDateTime(_start)),
            onTap: () async { final d = await pickDateTime(context, _start); if (d != null) setState(() => _start = d); },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFD8E3FA))),
            leading: const Icon(Icons.stop), title: const Text('النهاية'), subtitle: Text(fmtDateTime(_end)),
            onTap: () async { final d = await pickDateTime(context, _end); if (d != null) setState(() => _end = d); },
          ),
          SwitchListTile(title: const Text('المسابقة مفعّلة'), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 8),
          GradientButton(label: 'حفظ', loading: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}
