import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/data.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../widgets/parts.dart';

const verseCategories = ['تشجيع', 'إيمان', 'محبة', 'رجاء', 'صلاة', 'خدمة'];

void shareVerse(String text, String ref) => Share.share('$text\n— $ref\n(ترجمة فاندايك)');

/// بطاقة "آية اليوم": تتغير يوميًا من الآيات المفعّلة التي يضيفها العام.
class VerseCard extends StatelessWidget {
  const VerseCard({super.key});
  @override
  Widget build(BuildContext context) {
    final me = context.read<Session>().appUser!;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('verses').where('active', isEqualTo: true).snapshots(),
      builder: (c, s) {
        final docs = s.data?.docs.toList() ?? [];
        docs.sort((a, b) => a.id.compareTo(b.id));
        if (docs.isEmpty) {
          return AppCard(child: Row(children: [
            const Icon(Icons.menu_book, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(me.isGeneral ? 'لا توجد آيات بعد. أضفها من «الإدارة ← الآيات».' : 'ستظهر هنا آية مشجعة يضيفها المسؤول.', style: const TextStyle(height: 1.6))),
          ]));
        }
        final now = DateTime.now();
        final dayIndex = now.difference(DateTime(now.year)).inDays;
        final v = docs[dayIndex % docs.length];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF8E5), Colors.white]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.menu_book, color: AppColors.goldDark),
              const SizedBox(width: 8),
              const Text('آية اليوم', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.share, size: 20, color: AppColors.royal), onPressed: () => shareVerse(v['text'] as String, v['reference'] as String)),
            ]),
            Text('﴿${v['text']}﴾', style: const TextStyle(fontSize: 17, height: 1.8, color: AppColors.navy, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(v['reference'] as String, style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800)),
          ]),
        );
      },
    );
  }
}

class VersesScreen extends StatefulWidget {
  const VersesScreen({super.key});
  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen> {
  String? _cat;

  Future<void> _edit({QDoc? doc}) async {
    final text = TextEditingController(text: doc?['text'] as String? ?? '');
    final ref = TextEditingController(text: doc?['reference'] as String? ?? '');
    var cat = doc?['category'] as String? ?? verseCategories.first;
    var active = doc?['active'] as bool? ?? true;
    final me = context.read<Session>().appUser!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) => AlertDialog(
        title: Text(doc == null ? 'إضافة آية' : 'تعديل آية'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: text, maxLines: 4, decoration: const InputDecoration(labelText: 'نص الآية (فاندايك – انسخه من مصدر موثوق)')),
          const SizedBox(height: 8),
          TextField(controller: ref, decoration: const InputDecoration(labelText: 'المرجع (مثال: سفر – إصحاح: آية)')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: cat, items: [for (final k in verseCategories) DropdownMenuItem(value: k, child: Text(k))], onChanged: (v) => setS(() => cat = v ?? cat), decoration: const InputDecoration(labelText: 'التصنيف')),
          SwitchListTile(title: const Text('مفعّلة'), value: active, onChanged: (v) => setS(() => active = v)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('حفظ'))],
      )),
    );
    if (ok != true) return;
    if (text.text.trim().isEmpty || ref.text.trim().isEmpty) {
      if (mounted) showSnack(context, 'النص والمرجع مطلوبان', error: true);
      return;
    }
    try {
      final body = {'text': text.text.trim(), 'reference': ref.text.trim(), 'category': cat, 'active': active};
      if (doc == null) {
        await db.collection('verses').add({...body, 'createdBy': me.uid, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await doc.reference.update(body);
      }
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<Session>().appUser!;
    return Scaffold(
      appBar: gradAppBar('الآيات'),
      floatingActionButton: me.isGeneral ? FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('آية')) : null,
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null))),
            for (final k in verseCategories) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(k), selected: _cat == k, onSelected: (_) => setState(() => _cat = k))),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('verses').snapshots(),
            builder: (c, s) {
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final docs = s.data!.docs.where((d) => (me.isGeneral || d['active'] == true) && (_cat == null || d['category'] == _cat)).toList();
              if (docs.isEmpty) return const EmptyState('لا توجد آيات', icon: Icons.menu_book);
              return ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('﴿${d['text']}﴾', style: const TextStyle(fontSize: 16, height: 1.8)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(d['reference'] as String, style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Pill(d['category'] as String, AppColors.royal),
                      if (me.isGeneral && d['active'] != true) const Padding(padding: EdgeInsets.only(right: 6), child: Pill('موقوفة', AppColors.danger)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.share, size: 20), onPressed: () => shareVerse(d['text'] as String, d['reference'] as String)),
                      if (me.isGeneral) IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _edit(doc: d)),
                      if (me.isGeneral) IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger), onPressed: () => d.reference.delete()),
                    ]),
                  ]));
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
