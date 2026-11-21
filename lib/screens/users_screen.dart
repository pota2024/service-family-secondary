import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/phone_utils.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

String statusLabel(String s) => switch (s) { 'active' => 'مفعّل', 'pending' => 'قيد المراجعة', 'rejected' => 'مرفوض', _ => 'موقوف' };
Color statusColor(String s) => switch (s) { 'active' => AppColors.success, 'pending' => AppColors.goldDark, _ => AppColors.danger };

/// إدارة المستخدمين والصلاحيات. العام: كل شيء. الخادم: تفعيل/إيقاف مخدومي قسمه فقط.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _q = '';
  String? _role, _section, _status;

  Future<void> _update(String uid, Map<String, dynamic> change, {String? notifyTitle}) async {
    try {
      final b = db.batch();
      b.update(db.doc('users/$uid'), {...change, 'updatedAt': FieldValue.serverTimestamp()});
      if (notifyTitle != null) b.set(db.collection('notifications').doc(), notifDoc(uid, notifyTitle, '', 'account'));
      await b.commit();
      if (mounted) showSnack(context, 'تم التحديث');
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    }
  }

  Future<void> _details(AppUser me, QDoc u, Profile? p) async {
    final uid = u.id;
    final role = u['role'] as String, section = u['section'] as String, status = u['status'] as String;
    final canEdit = uid != me.uid && (me.isGeneral || (role == 'member' && section == me.section));
    String? phone;
    if (me.isGeneral) {
      try {
        phone = (await db.doc('privateUsers/$uid').get()).data()?['phone'] as String?;
      } catch (_) {}
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(photoUrl: p?.photoUrl, name: p?.displayName ?? '', radius: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p?.displayName ?? '—', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('${roleLabel(role, section)} • ${statusLabel(status)}'),
                if (phone != null) Directionality(textDirection: TextDirection.ltr, child: Text(PhoneUtils.display(phone))),
              ])),
            ]),
            const Divider(height: 24),
            if (!canEdit) const Text('لا تملك صلاحية تعديل هذا الحساب'),
            if (canEdit) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (status != 'active') ActionChip(label: const Text('تفعيل'), onPressed: () { Navigator.pop(c); _update(uid, {'status': 'active'}, notifyTitle: 'تم تفعيل حسابك'); }),
                if (status == 'active') ActionChip(label: const Text('إيقاف'), onPressed: () { Navigator.pop(c); _update(uid, {'status': 'suspended'}, notifyTitle: 'تم إيقاف حسابك'); }),
                if (me.isGeneral && role != 'servant' && section != 'all') ActionChip(label: const Text('ترقية إلى خادم'), onPressed: () { Navigator.pop(c); _update(uid, {'role': 'servant'}); }),
                if (me.isGeneral && role == 'servant') ActionChip(label: const Text('تحويل إلى مخدوم'), onPressed: () { Navigator.pop(c); _update(uid, {'role': 'member'}); }),
                if (me.isGeneral && role != 'general') ActionChip(label: const Text('منح صلاحية عام'), onPressed: () async {
                  Navigator.pop(c);
                  final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('منح صلاحية عام؟'), content: const Text('سيملك هذا الحساب كل الصلاحيات الإدارية.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('منح'))]));
                  if (ok == true) _update(uid, {'role': 'general', 'section': 'all'});
                }),
                if (me.isGeneral && role != 'general' && section != 'boys') ActionChip(label: const Text('نقل لقسم البنين'), onPressed: () { Navigator.pop(c); _update(uid, {'section': 'boys'}); }),
                if (me.isGeneral && role != 'general' && section != 'girls') ActionChip(label: const Text('نقل لقسم البنات'), onPressed: () { Navigator.pop(c); _update(uid, {'section': 'girls'}); }),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    Q uq = db.collection('users');
    if (!me.isGeneral) uq = uq.where('section', isEqualTo: me.section);
    return Scaffold(
      appBar: gradAppBar('المستخدمون'),
      body: FutureBuilder<Map<String, Profile>>(
        future: loadProfiles(me),
        builder: (c, ps) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: uq.snapshots(),
          builder: (c, us) {
            if (us.hasError) return EmptyState(AuthService.arabicError(us.error!));
            if (!us.hasData || !ps.hasData) return const Center(child: CircularProgressIndicator());
            final profiles = ps.data!;
            final list = us.data!.docs.where((d) {
              final name = profiles[d.id]?.displayName ?? '';
              return name.contains(_q.trim()) && (_role == null || d['role'] == _role) && (_section == null || d['section'] == _section) && (_status == null || d['status'] == _status);
            }).toList()
              ..sort((a, b) => (profiles[a.id]?.displayName ?? '').compareTo(profiles[b.id]?.displayName ?? ''));
            return Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 4), child: TextField(decoration: const InputDecoration(hintText: 'بحث بالاسم', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v))),
              SizedBox(
                height: 46,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
                  _f('مخدوم', _role == 'member', () => setState(() => _role = _role == 'member' ? null : 'member')),
                  _f('خادم', _role == 'servant', () => setState(() => _role = _role == 'servant' ? null : 'servant')),
                  if (me.isGeneral) _f('عام', _role == 'general', () => setState(() => _role = _role == 'general' ? null : 'general')),
                  if (me.isGeneral) _f('بنين', _section == 'boys', () => setState(() => _section = _section == 'boys' ? null : 'boys')),
                  if (me.isGeneral) _f('بنات', _section == 'girls', () => setState(() => _section = _section == 'girls' ? null : 'girls')),
                  _f('مفعّل', _status == 'active', () => setState(() => _status = _status == 'active' ? null : 'active')),
                  _f('معلّق', _status == 'pending', () => setState(() => _status = _status == 'pending' ? null : 'pending')),
                  _f('موقوف', _status == 'suspended', () => setState(() => _status = _status == 'suspended' ? null : 'suspended')),
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState('لا توجد نتائج')
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final d = list[i];
                          final p = profiles[d.id];
                          return ListTile(
                            leading: Avatar(photoUrl: p?.photoUrl, name: p?.displayName ?? '', radius: 22),
                            title: Text(p?.displayName ?? '(بدون اسم)'),
                            subtitle: Text(roleLabel(d['role'] as String, d['section'] as String)),
                            trailing: Pill(statusLabel(d['status'] as String), statusColor(d['status'] as String)),
                            onTap: () => _details(me, d, p),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _f(String t, bool sel, VoidCallback f) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FilterChip(label: Text(t), selected: sel, onSelected: (_) => f()));
}
