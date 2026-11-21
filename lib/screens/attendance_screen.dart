import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/actions.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

/// اختيار نوع الفعالية والتاريخ (مشترك بين الماسح والحضور اليدوي).
class EventPicker extends StatelessWidget {
  final String type;
  final DateTime day;
  final ValueChanged<String> onType;
  final ValueChanged<DateTime> onDay;
  const EventPicker({super.key, required this.type, required this.day, required this.onType, required this.onDay});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: type,
            decoration: const InputDecoration(labelText: 'نوع الحضور'),
            items: [for (final e in attendanceTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => onType(v ?? type),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await pickDate(context, day);
            if (d != null) onDay(d);
          },
          icon: const Icon(Icons.event),
          label: Text(fmtDate(day)),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
        ),
      ]);
}

/// ماسح QR: يمسح بطاقة المخدوم ويسجل حضوره.
class ScanAttendanceScreen extends StatefulWidget {
  const ScanAttendanceScreen({super.key});
  @override
  State<ScanAttendanceScreen> createState() => _ScanAttendanceScreenState();
}

class _ScanAttendanceScreenState extends State<ScanAttendanceScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String _type = 'mass';
  DateTime _day = DateTime.now();
  bool _busy = false;
  String? _msg;
  bool _ok = false;
  Member? _last;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_busy) return;
    final raw = cap.barcodes.isEmpty ? null : cap.barcodes.first.rawValue;
    if (raw == null) return;
    _busy = true;
    final me = context.read<Session>().appUser!;
    String? err;
    Member? member;
    if (!raw.startsWith('SF1|')) {
      err = 'هذا ليس رمز بطاقة عضوية صالحًا';
    } else {
      final uid = raw.substring(4);
      try {
        final u = await db.doc('users/$uid').get();
        final p = await db.doc('profiles/$uid').get();
        if (!u.exists || !p.exists) {
          err = 'المخدوم غير موجود';
        } else if (u.data()!['role'] != 'member' || u.data()!['status'] != 'active') {
          err = 'الحساب غير مفعّل أو ليس مخدومًا';
        } else {
          member = Member(uid, p.data()!['displayName'] as String? ?? '', u.data()!['section'] as String, p.data()!['photoUrl'] as String?);
          err = await recordAttendance(me: me, member: member, type: _type, day: _day);
        }
      } catch (_) {
        err = 'غير مسموح بقراءة هذا المخدوم (ليس من قسمك)';
      }
    }
    if (!mounted) return;
    setState(() {
      _ok = err == null;
      _msg = err ?? 'تم تسجيل الحضور بنجاح';
      _last = member;
    });
    await Future.delayed(const Duration(milliseconds: 2200));
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradAppBar('تسجيل الحضور', actions: [
        IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _controller.toggleTorch()),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: EventPicker(type: _type, day: _day, onType: (v) => setState(() => _type = v), onDay: (d) => setState(() => _day = d))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(child: Container(width: 240, height: 240, decoration: BoxDecoration(border: Border.all(color: AppColors.gold, width: 3), borderRadius: BorderRadius.circular(20)))),
            ]),
          ),
        ),
        if (_msg != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _ok ? AppColors.success.withOpacity(0.12) : AppColors.danger.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              if (_last != null) Avatar(photoUrl: _last!.photo, name: _last!.name, radius: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_last != null) Text(_last!.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(_msg!, style: TextStyle(color: _ok ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700)),
              ])),
              Icon(_ok ? Icons.check_circle : Icons.error, color: _ok ? AppColors.success : AppColors.danger),
            ]),
          ),
      ]),
    );
  }
}

/// الحضور اليدوي: بحث واختيار المخدوم وتسجيل الحضور باسم الخادم.
class ManualAttendanceScreen extends StatefulWidget {
  const ManualAttendanceScreen({super.key});
  @override
  State<ManualAttendanceScreen> createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  String _type = 'mass';
  DateTime _day = DateTime.now();
  List<Member>? _members;
  String _q = '';
  final Set<String> _done = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final me = context.read<Session>().appUser!;
    loadMembers(me).then((m) {
      if (mounted) setState(() => _members = m);
    }).catchError((e) {
      if (mounted) setState(() => _error = 'تعذر تحميل المخدومين');
    });
  }

  Future<void> _mark(Member m) async {
    final me = context.read<Session>().appUser!;
    final err = await recordAttendance(me: me, member: m, type: _type, day: _day);
    if (!mounted) return;
    if (err == null) {
      setState(() => _done.add(m.uid));
      showSnack(context, 'تم تسجيل حضور ${m.name}');
    } else {
      showSnack(context, err, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _members?.where((m) => m.name.contains(_q.trim())).toList();
    return Scaffold(
      appBar: gradAppBar('الحضور اليدوي'),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), child: EventPicker(type: _type, day: _day, onType: (v) => setState(() { _type = v; _done.clear(); }), onDay: (d) => setState(() { _day = d; _done.clear(); }))),
        Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 6), child: TextField(decoration: const InputDecoration(hintText: 'ابحث عن مخدوم', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => _q = v))),
        Expanded(
          child: _error != null
              ? EmptyState(_error!)
              : list == null
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? const EmptyState('لا يوجد مخدومون مفعّلون')
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            final done = _done.contains(m.uid);
                            return ListTile(
                              leading: Avatar(photoUrl: m.photo, name: m.name, radius: 22),
                              title: Text(m.name),
                              subtitle: Text(secShort(m.section)),
                              trailing: done
                                  ? const Icon(Icons.check_circle, color: AppColors.success)
                                  : FilledButton(onPressed: () => _mark(m), child: const Text('حضر')),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
