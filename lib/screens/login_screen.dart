import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/phone_utils.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// فتح خيار "عام" في واجهة التسجيل (في الذاكرة فقط، لا يمنح أي صلاحية).
class UiGate extends ChangeNotifier {
  bool generalUnlocked = false;
  void unlockGeneral() {
    generalUnlocked = true;
    notifyListeners();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.signIn(PhoneUtils.normalize(_phone.text)!, _pass.text);
    } catch (e) {
      if (mounted) showSnack(context, AuthService.arabicError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accessCode() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('رمز الوصول'),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'أدخل الرمز'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim() == AppConfig.generalCode), child: const Text('تأكيد')),
        ],
      ),
    );
    if (!mounted || ok == null) return;
    if (ok) {
      context.read<UiGate>().unlockGeneral();
      showSnack(context, 'تم إظهار خيار "عام" في شاشة إنشاء الحساب. الحساب يحتاج اعتماد الإدارة.');
    } else {
      showSnack(context, 'الرمز غير صحيح', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Scaffold(
      body: SkyBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(children: [
                    const CrossLogo(size: 96),
                    const SizedBox(height: 14),
                    Text('أسرة ثانوي\nبنين وبنات',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, height: 1.25, fontWeight: FontWeight.w900, color: dark ? Colors.white : AppColors.navy)),
                    const SizedBox(height: 6),
                    Text(AppConfig.churchName,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dark ? Colors.white70 : AppColors.ink)),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(hintText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_android)),
                      validator: (v) => PhoneUtils.normalize(v ?? '') == null ? 'أدخل رقم هاتف صحيح' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: _hide,
                      decoration: InputDecoration(
                        hintText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'أدخل كلمة المرور' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(width: double.infinity, child: GradientButton(label: 'تسجيل الدخول', loading: _busy, onPressed: _login)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('نسيت كلمة المرور؟'),
                    ),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو')),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SoftOutlineButton(
                        label: 'إنشاء حساب جديد',
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _accessCode,
                      child: Text('لدي رمز وصول', style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.black45)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
