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
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _code = TextEditingController();
  SignupKind? _kind;
  DateTime? _birth;
  String? _photo;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _pass, _pass2, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
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
    try {
      final p = await pickProfilePhoto(src);
      if (p != null && mounted) setState(() => _photo = p);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر معالجة الصورة', error: true);
    }
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 16, 1, 1),
      firstDate: DateTime(now.year - 40),
      lastDate: DateTime(now.year - 8, 12, 31),
      helpText: 'تاريخ الميلاد',
    );
    if (d != null) setState(() => _birth = d);
  }

  String _fmt(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final kind = _kind;
    if (kind == null) {
      showSnack(context, 'اختر نوع الحساب أولًا', error: true);
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (kind.isMember && _birth == null) {
      showSnack(context, 'أدخل تاريخ الميلاد', error: true);
      return;
    }
    if (kind.isMember && _photo == null) {
      showSnack(context, 'ارفع صورتك الشخصية', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.register(
        session: context.read<Session>(),
        kind: kind,
        name: _name.text.trim(),
        phoneE164: PhoneUtils.normalize(_phone.text)!,
        password: _pass.text,
        birthDate: _birth,
        photoDataUri: _photo,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = context.watch<UiGate>().generalUnlocked;
    final kinds = [
      SignupKind.boysMember,
      SignupKind.girlsMember,
      SignupKind.boysServant,
      SignupKind.girlsServant,
      if (unlocked) SignupKind.general,
    ];
    final kind = _kind;
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              BackButton(onPressed: () => Navigator.pop(context)),
              const Expanded(child: Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
              const SizedBox(width: 48),
            ]),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('أنا:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final k in kinds)
                        ChoiceChip(
                          label: Text(k.label),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                          selectedColor: AppColors.royal,
                          labelStyle: TextStyle(color: _kind == k ? Colors.white : null, fontWeight: FontWeight.w700),
                        ),
                    ]),
                    if (kind != null) ...[
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          onTap: _pickPhoto,
                          child: Stack(children: [
                            Avatar(photoUrl: _photo, name: _name.text, radius: 46),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: CircleAvatar(radius: 15, backgroundColor: AppColors.gold, child: const Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                            ),
                          ]),
                        ),
                      ),
                      Center(child: Text(kind.isMember ? 'الصورة الشخصية (مطلوبة)' : 'الصورة الشخصية (اختيارية)', style: const TextStyle(fontSize: 12))),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(hintText: 'الاسم بالكامل', prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          return t.length < 2 || t.length > 60 ? 'أدخل اسمًا صحيحًا' : null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(hintText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_android)),
                        validator: (v) => PhoneUtils.normalize(v ?? '') == null ? 'أدخل رقم هاتف صحيح' : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                        child: Text('الرقم يُستخدم لتسجيل الدخول فقط ولم يتم التحقق منه برسالة SMS.',
                            style: TextStyle(fontSize: 11.5, color: isDark(context) ? Colors.white60 : Colors.black54)),
                      ),
                      if (kind.isMember) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickBirth,
                          borderRadius: BorderRadius.circular(16),
                          child: InputDecorator(
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                            child: Text(_birth == null ? 'تاريخ الميلاد' : _fmt(_birth!),
                                style: TextStyle(color: _birth == null ? Colors.black45 : null)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور (8 أحرف على الأقل)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
                        ),
                        validator: (v) => (v ?? '').length < AppConfig.minPasswordLength ? 'كلمة المرور قصيرة' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass2,
                        obscureText: _hide,
                        decoration: const InputDecoration(hintText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_reset)),
                        validator: (v) => v != _pass.text ? 'كلمتا المرور غير متطابقتين' : null,
                      ),
                      if (kind.needsServantCode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _code,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'كود الخدام', prefixIcon: Icon(Icons.key)),
                          validator: (v) => (v ?? '').trim() != AppConfig.servantCode ? 'كود الخدام غير صحيح' : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppCard(
                        child: Row(children: [
                          const Icon(Icons.hourglass_top, color: AppColors.gold),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kind.isMember
                                  ? 'بعد التسجيل ينتظر حسابك موافقة الخدام.'
                                  : 'الكود لا يمنحك صلاحيات. حسابك سيبقى قيد المراجعة حتى تعتمده الإدارة.',
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(label: 'إرسال طلب التسجيل', loading: _busy, onPressed: _submit),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
