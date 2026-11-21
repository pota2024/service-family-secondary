import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/actions.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

/// إضافة نقاط (للخدام والعام): الخادم يحدد المقدار والسبب، ويُسجل اسمه ووقت العملية.
class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});
  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  List<Member>? _members;
  Member? _member;
  String _cat = 'mass';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    loadMembers(context.read<Session>().appUser!).then((m) {
      if (mounted) setState(() => _members = m);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_member == null) {
      showSnack(context, 'اختر المخدوم', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await addPoints(
        me: context.read<Session>().appUser!,
        member: _member!,
        amount: int.parse(_amount.text.trim()),
        reason: _reason.text.trim(),
        category: _cat,
      );
      if (mounted) {
        showSnack(context, 'تمت إضافة ${_amount.text.trim()} نقطة إلى ${_member!.name}');
        _amount.clear();
        _reason.clear();
      }
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = pointCategoriesFor(_member?.section ?? 'boys');
    if (!cats.contains(_cat)) _cat = 'manual';
    return Scaffold(
      appBar: gradAppBar('إضافة نقاط'),
      body: _members == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final m = await pickMember(context, _members!);
                      if (m != null) setState(() => _member = m);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.person_search)),
                      child: Text(_member?.name ?? 'اختر المخدوم'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _cat,
                    decoration: const InputDecoration(labelText: 'نوع النقاط'),
                    items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(pointCategories[c]!))],
                    onChanged: (v) => setState(() => _cat = v ?? _cat),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد النقاط', prefixIcon: Icon(Icons.stars)),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 1 || n > 1000 ? 'أدخل رقمًا من 1 إلى 1000' : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'سبب الإضافة', prefixIcon: Icon(Icons.edit_note)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب السبب' : null,
                  ),
                  const SizedBox(height: 8),
                  GradientButton(label: 'إضافة النقاط', icon: Icons.add_circle_outline, loading: _busy, onPressed: _save),
                ]),
              ),
            ]),
    );
  }
}

/// سجل النقاط والحضور للمخدوم نفسه فقط.
class MyHistoryScreen extends StatelessWidget {
  const MyHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = context.read<Session>().appUser!.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: gradAppBar('سجلي', bottom: const TabBar(tabs: [Tab(text: 'النقاط'), Tab(text: 'الحضور')], labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.white)),
        body: TabBarView(children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('points').where('uid', isEqualTo: uid).snapshots(),
            builder: (c, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs.toList()..sort((a, b) => (tsOf(b['createdAt']) ?? DateTime.now()).compareTo(tsOf(a['createdAt']) ?? DateTime.now()));
              if (docs.isEmpty) return const EmptyState('لا توجد عمليات نقاط بعد', icon: Icons.stars_outlined);
              final total = docs.fold<int>(0, (a, d) => a + ((d['amount'] as num?) ?? 0).toInt());
              return ListView(padding: const EdgeInsets.all(12), children: [
                AppCard(child: Center(child: Text('المجموع: $total نقطة', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 8),
                for (final d in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Row(children: [
                        const Icon(Icons.stars, color: Color(0xFFF5B82E)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${pointCategories[d['category']] ?? ''} – ${d['reason']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(tsOf(d['createdAt']) == null ? '' : fmtDateTime(tsOf(d['createdAt'])!), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ])),
                        Text('+${d['amount']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('attendance').where('uid', isEqualTo: uid).snapshots(),
            builder: (c, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs.toList()..sort((a, b) => (tsOf(b['date']) ?? DateTime.now()).compareTo(tsOf(a['date']) ?? DateTime.now()));
              if (docs.isEmpty) return const EmptyState('لا يوجد حضور مسجل بعد', icon: Icons.event_available);
              return ListView(padding: const EdgeInsets.all(12), children: [
                AppCard(child: Center(child: Text('عدد مرات الحضور: ${docs.length}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 8),
                for (final d in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(child: Row(children: [
                      const Icon(Icons.check_circle, color: Color(0xFF22A06B)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(attendanceTypes[d['type']] ?? '${d['type']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text(tsOf(d['date']) == null ? '' : fmtDate(tsOf(d['date'])!)),
                    ])),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
