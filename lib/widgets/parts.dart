import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/data.dart';
import 'common.dart';

PreferredSizeWidget gradAppBar(String title, {List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      title: Text(title),
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.headerGradient)),
    );

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.royal.withOpacity(0.4)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.6)),
          ]),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year}/${two(d.month)}/${two(d.day)}';
String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String fmtDateTime(DateTime d) => '${fmtDate(d)}  ${fmtTime(d)}';
const monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

Future<DateTime?> pickDate(BuildContext c, DateTime initial, {DateTime? first, DateTime? last}) => showDatePicker(
      context: c,
      initialDate: initial,
      firstDate: first ?? DateTime(2020),
      lastDate: last ?? DateTime(2100),
    );

Future<DateTime?> pickDateTime(BuildContext c, DateTime initial) async {
  final d = await pickDate(c, initial);
  if (d == null || !c.mounted) return null;
  final t = await showTimePicker(context: c, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// نافذة اختيار مخدوم مع بحث بالاسم.
Future<Member?> pickMember(BuildContext context, List<Member> members) {
  return showModalBottomSheet<Member>(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      var q = '';
      return StatefulBuilder(builder: (c, setS) {
        final list = members.where((m) => m.name.contains(q.trim())).toList();
        return SizedBox(
          height: MediaQuery.of(c).size.height * 0.8,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'ابحث بالاسم', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setS(() => q = v),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState('لا يوجد مخدومون مطابقون')
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: Avatar(photoUrl: list[i].photo, name: list[i].name, radius: 20),
                          title: Text(list[i].name),
                          subtitle: Text(secShort(list[i].section)),
                          onTap: () => Navigator.pop(c, list[i]),
                        ),
                      ),
              ),
            ]),
          ),
        );
      });
    },
  );
}

String secShort(String s) => switch (s) { 'boys' => 'بنين', 'girls' => 'بنات', _ => 'الكل' };
