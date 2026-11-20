# خدمة أسرة ثانوي – تطبيق Android (Flutter + Firebase)

كنيسة الشهيد العظيم مارجرجس أبو زعل البلد.

**الحالة: المرحلة 1 من 4** (الأساس: الهوية، الدخول والتسجيل، الأدوار، الموافقة الإدارية، قواعد Firestore كاملة، بناء APK).

- طريقة الإعداد خطوة بخطوة بدون Terminal: [`docs/SETUP_AR.md`](docs/SETUP_AR.md)
- ما تم وما لم يتم والقرارات الأمنية: [`docs/PHASE1_STATUS_AR.md`](docs/PHASE1_STATUS_AR.md)

## هيكل المشروع
| المسار | المحتوى |
|---|---|
| `lib/` | كود Flutter (core, models, services, screens, widgets) |
| `android/` | إعدادات Android + `app/google-services.json` |
| `firestore.rules` | قواعد الأمان لكل المجموعات |
| `tests/rules/` | اختبارات القواعد على محاكي Firestore |
| `.github/workflows/` | بناء APK + اختبار القواعد |
| `assets/images/` | ضع صورة المقدمة `intro_george.png` هنا |
