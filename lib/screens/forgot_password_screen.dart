import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// استرجاع كلمة المرور.
/// لا يوجد بريد حقيقي ولا SMS، ولا يمكن إعادة تعيين كلمة مرور مستخدم آخر بدون خادم
/// (Cloud Functions تتطلب Blaze). لذلك نوضح الحل المتاح مجانًا بصراحة.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const SizedBox(height: 30),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Row(children: [
                  Icon(Icons.info_outline, color: AppColors.royal),
                  SizedBox(width: 8),
                  Text('كيف أسترجع حسابي؟', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ]),
                SizedBox(height: 12),
                Text('تسجيل الدخول يتم برقم الهاتف وكلمة المرور دون رسائل SMS، لذلك لا يوجد بريد لإرسال رابط الاسترجاع.', style: TextStyle(height: 1.7)),
                SizedBox(height: 10),
                Text('• إذا كنت تتذكر كلمتك الحالية: ادخل ثم من «الملف الشخصي» اختر «تغيير كلمة المرور».', style: TextStyle(height: 1.7)),
                Text('• إذا نسيتها: تواصل مع أحد الخدام أو مسؤول الخدمة ليتم إنشاء حساب جديد لك بنفس الرقم بعد حذف الحساب القديم من لوحة Firebase.', style: TextStyle(height: 1.7)),
                SizedBox(height: 10),
                Text('ملاحظة للإدارة: الإعادة الآلية تتطلب خادمًا (Cloud Functions/Blaze). التفاصيل في docs/SETUP_AR.md.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
