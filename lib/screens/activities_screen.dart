import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});
  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  bool _upcoming = true;
  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar('الأنشطة والرحلات'),
      floatingActionButton: me.canReview
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('نشاط جديد'))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('القادمة')), ButtonSegment(value: false, label: Text('السابقة'))],
            selected: {_upcoming},
            onSelectionChanged: (s) => setState(() => _upcoming = s.first),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<QDoc>>(
            stream: mergedStream(visibleByAudience('activities', me)),
            builder: (c, snap) {
              if (snap.hasError) return EmptyState(AuthService.arabicError(snap.error!));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final now = DateTime.now().subtract(const Duration(hours: 6));
              final docs = snap.data!.where((d) {
                final dt = tsOf(d['date']);
                if (dt == null) return false;
                return _upcoming ? !dt.isBefore(now) : dt.isBefore(now);
              }).toList()
                ..sort((a, b) => _upcoming ? tsOf(a['date'])!.compareTo(tsOf(b['date'])!) : tsOf(b['date'])!.compareTo(tsOf(a['date'])!));
              if (docs.isEmpty) return EmptyState(_upcoming ? 'لا توجد أنشطة قادمة' : 'لا توجد أنشطة سابقة', icon: Icons.event_busy);
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 90),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => ActivityTile(doc: docs[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class ActivityTile extends StatelessWidget {
  final QDoc doc;
  const ActivityTile({super.key, required this.doc});
  @override
  Widget build(BuildContext context) {
    final d = tsOf(doc['date'])!;
    final cancelled = doc['status'] == 'cancelled';
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(id: doc.id))),
      child: AppCard(
        child: Row(children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text('${d.day}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy)),
              Text(monthsAr[d.month - 1], style: const TextStyle(fontSize: 12, color: AppColors.goldDark, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc['title'] as String, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, decoration: cancelled ? TextDecoration.lineThrough : null)),
            Text('${fmtTime(d)}${(doc.data()['location'] as String?)?.isNotEmpty == true ? ' • ${doc['location']}' : ''}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
          ])),
          if (cancelled) const Pill('ملغي', AppColors.danger) else Pill(secShort(doc['audience'] as String), AppColors.royal),
        ]),
      ),
    );
  }
}

class ActivityDetailScreen extends StatefulWidget {
  final String id;
  const ActivityDetailScreen({super.key, required this.id});
  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _busy = false;

  Future<void> _toggle(AppUser me, bool joined) async {
    setState(() => _busy = true);
    try {
      final ref = db.doc('activities/${widget.id}/registrations/${me.uid}');
      if (joined) {
        await ref.delete();
      } else {
        await ref.set({'uid': me.uid, 'section': me.section, 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: db.doc('activities/${widget.id}').snapshots(),
      builder: (c, snap) {
        final d = snap.data?.data();
        if (d == null) return Scaffold(appBar: gradAppBar('النشاط'), body: snap.hasData ? const EmptyState('النشاط غير موجود') : const Center(child: CircularProgressIndicator()));
        final date = tsOf(d['date']);
        final deadline = tsOf(d['registrationDeadline']);
        final img = d['imageUrl'] as String?;
        final cancelled = d['status'] == 'cancelled';
        final canJoin = me.role == 'member' && !cancelled && (deadline == null || DateTime.now().isBefore(deadline));
        final manage = me.canReview && (me.isGeneral || d['audience'] == me.section);
        return Scaffold(
          appBar: gradAppBar('النشاط', actions: [
            if (manage) IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityFormScreen(id: widget.id, data: d)))),
          ]),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            if (img != null && img.startsWith('http'))
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(img, height: 190, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
            const SizedBox(height: 12),
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(d['title'] as String, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))), if (cancelled) const Pill('ملغي', AppColors.danger)]),
              const SizedBox(height: 10),
              if (date != null) _line(Icons.event, fmtDateTime(date)),
              if ((d['location'] as String?)?.isNotEmpty == true) _line(Icons.place, d['location'] as String),
              _line(Icons.groups, 'القسم: ${secShort(d['audience'] as String)}'),
              if (deadline != null) _line(Icons.timer, 'آخر موعد للتسجيل: ${fmtDateTime(deadline)}'),
              if ((d['description'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 10), child: Text(d['description'] as String, style: const TextStyle(height: 1.7))),
            ])),
            const SizedBox(height: 12),
            if (me.role == 'member')
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: db.doc('activities/${widget.id}/registrations/${me.uid}').snapshots(),
                builder: (c, s) {
                  final joined = s.data?.exists == true;
                  if (!canJoin && !joined) return const SizedBox.shrink();
                  return joined
                      ? SoftOutlineButton(label: 'تم تأكيد اشتراكك – إلغاء الاشتراك', icon: Icons.check_circle, onPressed: _busy ? null : () => _toggle(me, true))
                      : GradientButton(label: 'تأكيد الاشتراك', icon: Icons.how_to_reg, loading: _busy, onPressed: () => _toggle(me, false));
                },
              )
            else if (manage)
              _Registrants(id: widget.id, me: me),
          ]),
        );
      },
    );
  }

  Widget _line(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Icon(i, size: 18, color: AppColors.royal), const SizedBox(width: 8), Expanded(child: Text(t))]));
}

class _Registrants extends StatelessWidget {
  final String id;
  final AppUser me;
  const _Registrants({required this.id, required this.me});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('activities/$id/registrations').snapshots(),
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final docs = s.data!.docs;
        return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المشتركون (${docs.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          for (final r in docs)
            FutureBuilder<Profile?>(
              future: cachedProfile(r.id),
              builder: (c, p) => ListTile(dense: true, leading: Avatar(photoUrl: p.data?.photoUrl, name: p.data?.displayName ?? '', radius: 16), title: Text(p.data?.displayName ?? '...')),
            ),
        ]));
      },
    );
  }
}

class ActivityFormScreen extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;
  const ActivityFormScreen({super.key, this.id, this.data});
  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.data?['title'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.data?['description'] as String? ?? '');
  late final _img = TextEditingController(text: widget.data?['imageUrl'] as String? ?? '');
  late final _loc = TextEditingController(text: widget.data?['location'] as String? ?? '');
  late String _audience = widget.data?['audience'] as String? ?? '';
  late DateTime _date = tsOf(widget.data?['date']) ?? DateTime.now().add(const Duration(days: 3));
  late DateTime? _deadline = tsOf(widget.data?['registrationDeadline']);
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
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'imageUrl': _img.text.trim(),
        'location': _loc.text.trim(),
        'date': Timestamp.fromDate(_date),
        'audience': _audience,
        'status': _active ? 'active' : 'cancelled',
        'registrationDeadline': _deadline == null ? FieldValue.delete() : Timestamp.fromDate(_deadline!),
      };
      if (widget.id == null) {
        body.remove('registrationDeadline');
        if (_deadline != null) body['registrationDeadline'] = Timestamp.fromDate(_deadline!);
        final ref = db.collection('activities').doc();
        final b = db.batch();
        b.set(ref, {...body, 'createdBy': me.uid, 'createdAt': FieldValue.serverTimestamp()});
        b.set(db.collection('notifications').doc(), notifDoc(_audience, 'نشاط جديد', _title.text.trim(), 'activity', ref.id));
        await b.commit();
      } else {
        final b = db.batch();
        b.update(db.doc('activities/${widget.id}'), body);
        b.set(db.collection('notifications').doc(), notifDoc(_audience, 'تم تعديل نشاط', _title.text.trim(), 'activity', widget.id!));
        await b.commit();
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
      appBar: gradAppBar(widget.id == null ? 'نشاط جديد' : 'تعديل النشاط'),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'العنوان'), validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
          const SizedBox(height: 12),
          TextFormField(controller: _loc, decoration: const InputDecoration(labelText: 'المكان')),
          const SizedBox(height: 12),
          TextFormField(
            controller: _img,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رابط الصورة (اختياري – رابط خارجي https)'),
            validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^https://.+').hasMatch(v!.trim()) ? null : 'يجب أن يبدأ بـ https://',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _audience,
            decoration: const InputDecoration(labelText: 'القسم'),
            items: [
              if (me.isGeneral || me.section == 'boys') const DropdownMenuItem(value: 'boys', child: Text('بنين')),
              if (me.isGeneral || me.section == 'girls') const DropdownMenuItem(value: 'girls', child: Text('بنات')),
              if (me.isGeneral) const DropdownMenuItem(value: 'all', child: Text('عام (الكل)')),
            ],
            onChanged: (v) => setState(() => _audience = v ?? _audience),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFD8E3FA))),
            leading: const Icon(Icons.event), title: const Text('التاريخ والوقت'), subtitle: Text(fmtDateTime(_date)),
            onTap: () async { final d = await pickDateTime(context, _date); if (d != null) setState(() => _date = d); },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFFD8E3FA))),
            leading: const Icon(Icons.timer), title: const Text('آخر موعد للتسجيل'),
            subtitle: Text(_deadline == null ? 'غير محدد' : fmtDateTime(_deadline!)),
            trailing: _deadline == null ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _deadline = null)),
            onTap: () async { final d = await pickDateTime(context, _deadline ?? _date); if (d != null) setState(() => _deadline = d); },
          ),
          SwitchListTile(title: const Text('النشاط مفعّل (إيقافه = إلغاء)'), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 8),
          GradientButton(label: 'حفظ', loading: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}
