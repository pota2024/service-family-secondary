import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants.dart';
import '../core/phone_utils.dart';
import '../models/models.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

class _Report {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  _Report(this.title, this.headers, this.rows);
}

String _csv(_Report r) {
  String esc(String s) => '"${s.replaceAll('"', '""')}"';
  return '\uFEFF${[r.headers, ...r.rows].map((row) => row.map(esc).join(',')).join('\r\n')}';
}

/// التقارير: عرض + تصدير CSV (يُفتح في Excel). البيانات الخاصة (الهاتف) للعام فقط.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _types = {
    'memberAtt': 'حضور مخدوم',
    'sectionAtt': 'حضور قسم',
    'points': 'النقاط',
    'compPoints': 'نقاط المسابقات',
    'activities': 'الأنشطة',
    'users': 'المستخدمون',
    'servants': 'الخدام',
  };
  String _type = 'sectionAtt';
  String? _section;
  DateTime? _from, _to;
  Member? _member;
  List<Member>? _members;
  _Report? _report;
  bool _busy = false;

  bool _inRange(DateTime? d) {
    if (d == null) return true;
    if (_from != null && d.isBefore(_from!)) return false;
    if (_to != null && d.isAfter(_to!.add(const Duration(days: 1)))) return false;
    return true;
  }

  Future<void> _run() async {
    final me = context.read<Session>().appUser!;
    setState(() { _busy = true; _report = null; });
    try {
      final sec = me.isGeneral ? _section : me.section;
      final names = await loadProfiles(me);
      String nm(String uid) => names[uid]?.displayName ?? uid;
      Q scoped(String col) {
        Q q = db.collection(col);
        if (sec != null) q = q.where('section', isEqualTo: sec);
        return q;
      }
      _Report rep;
      switch (_type) {
        case 'memberAtt':
          if (_member == null) throw 'اختر المخدوم أولًا';
          final s = await db.collection('attendance').where('uid', isEqualTo: _member!.uid).where('section', isEqualTo: _member!.section).get();
          final rows = [for (final d in s.docs) if (_inRange(tsOf(d['date']))) [attendanceTypes[d['type']] ?? '${d['type']}', fmtDate(tsOf(d['date'])!), nm(d['createdBy'] as String)]];
          rows.sort((a, b) => b[1].compareTo(a[1]));
          rep = _Report('حضور ${_member!.name}', ['النوع', 'التاريخ', 'سجّله'], rows);
        case 'sectionAtt':
          final s = await scoped('attendance').get();
          final rows = [for (final d in s.docs) if (_inRange(tsOf(d['date']))) [nm(d['uid'] as String), secShort(d['section'] as String), attendanceTypes[d['type']] ?? '${d['type']}', fmtDate(tsOf(d['date'])!), nm(d['createdBy'] as String)]];
          rows.sort((a, b) => b[3].compareTo(a[3]));
          rep = _Report('حضور القسم', ['المخدوم', 'القسم', 'النوع', 'التاريخ', 'سجّله'], rows);
        case 'points':
          final s = await scoped('points').get();
          final totals = <String, int>{};
          final sections = <String, String>{};
          for (final d in s.docs) {
            if (!_inRange(tsOf(d['createdAt']))) continue;
            totals[d['uid'] as String] = (totals[d['uid'] as String] ?? 0) + (d['amount'] as num).toInt();
            sections[d['uid'] as String] = d['section'] as String;
          }
          final rows = [for (final e in totals.entries) [nm(e.key), secShort(sections[e.key]!), '${e.value}']]..sort((a, b) => int.parse(b[2]).compareTo(int.parse(a[2])));
          rep = _Report('تقرير النقاط', ['المخدوم', 'القسم', 'المجموع'], rows);
        case 'compPoints':
          final s = await scoped('points').where('category', isEqualTo: 'competition').get();
          final rows = [for (final d in s.docs) if (_inRange(tsOf(d['createdAt']))) [nm(d['uid'] as String), d['reason'] as String, '${d['amount']}', fmtDate(tsOf(d['createdAt'])!), nm(d['createdBy'] as String)]];
          rep = _Report('نقاط المسابقات', ['المخدوم', 'المسابقة', 'النقاط', 'التاريخ', 'اعتمدها'], rows);
        case 'activities':
          final qs = visibleByAudience('activities', me);
          final all = <QDoc>[];
          for (final q in qs) { all.addAll((await q.get()).docs); }
          final rows = [for (final d in all) if (_inRange(tsOf(d['date']))) [d['title'] as String, fmtDateTime(tsOf(d['date'])!), (d.data()['location'] as String?) ?? '', secShort(d['audience'] as String), d['status'] == 'active' ? 'مفعّل' : 'ملغي']];
          rows.sort((a, b) => b[1].compareTo(a[1]));
          rep = _Report('تقرير الأنشطة', ['العنوان', 'الموعد', 'المكان', 'القسم', 'الحالة'], rows);
        case 'users':
        case 'servants':
          Q q = db.collection('users').where('role', isEqualTo: _type == 'users' ? 'member' : 'servant');
          if (sec != null) q = q.where('section', isEqualTo: sec);
          final s = await q.get();
          final phones = <String, String>{};
          if (me.isGeneral) {
            final ps = await db.collection('privateUsers').get();
            for (final d in ps.docs) { phones[d.id] = PhoneUtils.display(d['phone'] as String); }
          }
          final rows = [for (final d in s.docs) [nm(d.id), secShort(d['section'] as String), d['status'] as String, if (me.isGeneral) phones[d.id] ?? '', if (tsOf(d['createdAt']) != null) fmtDate(tsOf(d['createdAt'])!) else '']];
          rows.sort((a, b) => a[0].compareTo(b[0]));
          rep = _Report(_type == 'users' ? 'تقرير المستخدمين' : 'تقرير الخدام', ['الاسم', 'القسم', 'الحالة', if (me.isGeneral) 'الهاتف', 'تاريخ التسجيل'], rows);
        default:
          throw 'نوع غير معروف';
      }
      if (mounted) setState(() => _report = rep);
    } catch (e) {
      if (mounted) showSnack(context, e is String ? e : 'تعذر إنشاء التقرير', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    final r = _report!;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/report_${DateTime.now().millisecondsSinceEpoch}.csv');
    await f.writeAsString(_csv(r));
    await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: r.title);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    final types = {..._types}..removeWhere((k, _) => k == 'servants' && !me.isGeneral);
    return Scaffold(
      appBar: gradAppBar('التقارير'),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        DropdownButtonFormField<String>(
          value: _type,
          decoration: const InputDecoration(labelText: 'نوع التقرير'),
          items: [for (final e in types.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() { _type = v ?? _type; _report = null; }),
        ),
        const SizedBox(height: 10),
        if (me.isGeneral && _type != 'memberAtt')
          DropdownButtonFormField<String?>(
            value: _section,
            decoration: const InputDecoration(labelText: 'القسم'),
            items: const [DropdownMenuItem(value: null, child: Text('الكل')), DropdownMenuItem(value: 'boys', child: Text('بنين')), DropdownMenuItem(value: 'girls', child: Text('بنات'))],
            onChanged: (v) => setState(() => _section = v),
          ),
        if (_type == 'memberAtt')
          InkWell(
            onTap: () async {
              _members ??= await loadMembers(me);
              if (!mounted) return;
              final m = await pickMember(context, _members!);
              if (m != null) setState(() => _member = m);
            },
            child: InputDecorator(decoration: const InputDecoration(prefixIcon: Icon(Icons.person_search)), child: Text(_member?.name ?? 'اختر المخدوم')),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await pickDate(context, _from ?? DateTime.now()); if (d != null) setState(() => _from = d); }, icon: const Icon(Icons.date_range), label: Text(_from == null ? 'من تاريخ' : fmtDate(_from!)))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () async { final d = await pickDate(context, _to ?? DateTime.now()); if (d != null) setState(() => _to = d); }, icon: const Icon(Icons.date_range), label: Text(_to == null ? 'إلى تاريخ' : fmtDate(_to!)))),
          if (_from != null || _to != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _from = null; _to = null; })),
        ]),
        const SizedBox(height: 12),
        GradientButton(label: 'عرض التقرير', icon: Icons.assessment, loading: _busy, onPressed: _run),
        if (_report != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('${_report!.title} (${_report!.rows.length} سجل)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            FilledButton.icon(onPressed: _report!.rows.isEmpty ? null : _export, icon: const Icon(Icons.ios_share), label: const Text('تصدير CSV')),
          ]),
          const SizedBox(height: 8),
          if (_report!.rows.isEmpty)
            const EmptyState('لا توجد بيانات')
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [for (final h in _report!.headers) DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w800)))],
                rows: [for (final r in _report!.rows.take(100)) DataRow(cells: [for (final c in r) DataCell(Text(c))])],
              ),
            ),
          if (_report!.rows.length > 100) const Padding(padding: EdgeInsets.all(8), child: Text('المعروض أول 100 سجل؛ التصدير يشمل الكل.', style: TextStyle(fontSize: 12))),
        ],
      ]),
    );
  }
}
