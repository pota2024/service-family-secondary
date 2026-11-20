import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/image_utils.dart';
import '../core/phone_utils.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import '../main.dart' show ThemeController;

/// الملف الشخصي: عرض بياناتي فقط. لا يمكن من هنا تعديل الدور أو القسم أو الحالة.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busyPhoto = false;

  Future<void> _changePhoto(String uid) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('من المعرض'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('الكاميرا'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ]),
      ),
    );
    if (src == null) return;
    setState(() => _busyPhoto = true);
    try {
      final p = await pickProfilePhoto(src);
      if (p != null) {
        await FirebaseFirestore.instance.doc('profiles/$uid').update({'photoUrl': p});
        if (mounted) showSnack(context, 'تم تحديث الصورة');
      }
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyPhoto = false);
    }
  }

  Future<void> _changePassword() async {
    final old = TextEditingController();
    final nw = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: old, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الحالية'), validator: (v) => (v ?? '').isEmpty ? 'مطلوبة' : null),
            const SizedBox(height: 10),
            TextFormField(controller: nw, obscureText: true, decoration: const InputDecoration(hintText: 'كلمة المرور الجديدة'), validator: (v) => (v ?? '').length < AppConfig.minPasswordLength ? '8 أحرف على الأقل' : null),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(c, true); }, child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthService.changePassword(old.text, nw.text);
      if (mounted) showSnack(context, 'تم تغيير كلمة المرور');
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final me = s.appUser!;
    final name = s.profile?.displayName ?? '';
    final theme = context.watch<ThemeController>();
    return ListView(padding: EdgeInsets.zero, children: [
      Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
        child: Column(children: [
          GestureDetector(
            onTap: _busyPhoto ? null : () => _changePhoto(me.uid),
            child: Stack(alignment: Alignment.center, children: [
              Avatar(photoUrl: s.profile?.photoUrl, name: name, radius: 48),
              if (_busyPhoto) const CircularProgressIndicator(color: Colors.white),
              Positioned(bottom: 0, left: 0, child: CircleAvatar(radius: 15, backgroundColor: AppColors.gold, child: const Icon(Icons.camera_alt, size: 16, color: Colors.white))),
            ]),
          ),
          const SizedBox(height: 10),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${roleLabel(me.role, me.section)} • ${sectionLabel(me.section)}', style: const TextStyle(color: Colors.white70)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          AppCard(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.doc('privateUsers/${me.uid}').snapshots(),
              builder: (_, snap) {
                final d = snap.data?.data();
                final phone = d?['phone'] as String?;
                final birth = (d?['birthDate'] as Timestamp?)?.toDate();
                return Column(children: [
                  _row(Icons.phone_android, 'رقم الهاتف', phone == null ? '—' : PhoneUtils.display(phone), ltr: true),
                  const Divider(height: 22),
                  _row(Icons.cake_outlined, 'تاريخ الميلاد', birth == null ? '—' : '${birth.year}/${birth.month.toString().padLeft(2, '0')}/${birth.day.toString().padLeft(2, '0')}'),
                  const Divider(height: 22),
                  _row(Icons.info_outline, 'ملاحظة', 'رقم الهاتف لم يتم التحقق منه برسالة SMS.'),
                ]);
              },
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(leading: const Icon(Icons.lock_outline), title: const Text('تغيير كلمة المرور'), trailing: const Icon(Icons.chevron_left), onTap: _changePassword),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('الوضع الداكن'),
                value: theme.mode == ThemeMode.dark,
                onChanged: (v) => theme.set(v ? ThemeMode.dark : ThemeMode.light),
              ),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.logout, color: AppColors.danger), title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)), onTap: AuthService.signOut),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _row(IconData icon, String label, String value, {bool ltr = false}) => Row(children: [
        Icon(icon, color: AppColors.royal),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        Flexible(child: Directionality(textDirection: ltr ? TextDirection.ltr : TextDirection.rtl, child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontSize: 13)))),
      ]);
}
