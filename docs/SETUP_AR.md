# دليل الإعداد (بدون Terminal وبدون تثبيت Flutter)

## 1) رفع الملفات إلى GitHub
1. فك ضغط ملف ZIP على جهازك.
2. افتح المستودع على GitHub ثم **Add file ← Upload files**.
3. اسحب **محتويات** المجلد (وليس المجلد نفسه) إلى الصفحة. تأكد أن مجلد `.github` ظهر في القائمة (مجلدات النقطة قد تُخفى في بعض أجهزة ويندوز: فعّل «إظهار العناصر المخفية»).
4. اكتب رسالة مثل `Phase 1` واختر **Commit directly to the main branch** ثم **Commit changes**.
5. حد GitHub في الرفع من المتصفح 100 ملف في المرة. إذا ظهرت رسالة بذلك ارفع على دفعتين (مثلًا `android` و`lib` أولًا ثم الباقي).
6. **إن لم يظهر `.github/workflows`:** اضغط **Add file ← Create new file**، اكتب في خانة الاسم `.github/workflows/build-apk.yml` والصق محتوى الملف من ZIP، وكرر مع `rules-test.yml`.

> يفضل أن يكون المستودع **Private**. (انظر قسم google-services.json أدناه.)

## 2) إعداد Firebase (من المتصفح)
مشروعك: `khedmet-osret-thanawy`.

1. **Authentication ← Sign-in method ← Email/Password ← Enable** (فعّل الأول فقط، لا تفعّل Email link). *هذا ضروري؛ بدونه يظهر خطأ «غير مفعّل».*
2. **Firestore Database ← Create database** ← اختر **Production mode** وأقرب موقع. (الخطة المجانية Spark تكفي.)
3. **Firestore ← Rules**: امسح المحتوى والصق محتوى `firestore.rules` كاملًا ثم **Publish**.
4. لا تفعّل Storage ولا Functions ولا أي خدمة تطلب Blaze.

## 3) إنشاء أول حساب «عام» (إجباري ويدوي)
لا يوجد من يعتمد الحسابات قبل وجود حساب عام، ولذلك يُنشأ مرة واحدة من لوحة Firebase:

1. ثبّت التطبيق (الخطوة 4)، وفي شاشة الدخول اضغط **«لدي رمز وصول»** وأدخل `0001`، ثم **إنشاء حساب جديد ← عام** وسجّل بياناتك.
   (سيظهر لك أن الحساب قيد المراجعة؛ هذا طبيعي.)
2. في Firebase: **Firestore ← users** ← افتح المستند الذي معرفه UID حسابك (تجده في Authentication ← Users).
3. عدّل الحقول: `role` = `general` ، `status` = `active` ، `section` = `all` ثم Save.
4. أعد فتح التطبيق: ستدخل كمسؤول عام. بعدها تُعتمد باقي الحسابات من داخل التطبيق (تبويب «الطلبات»).

بعد ذلك لا تحتاج للوحة Firebase لاعتماد الناس. الرمز `0001` وحده لا يمنح صلاحية لأحد.

## 4) بناء APK وتنزيله
1. في GitHub افتح تبويب **Actions ← Build APK** (يبدأ تلقائيًا بعد الرفع، أو اضغط **Run workflow**).
2. انتظر علامة ✅ (10–15 دقيقة تقريبًا في أول مرة).
3. افتح التشغيل الناجح ← أسفل الصفحة **Artifacts ← khedmet-osra-apk** ← نزّل ZIP وفكه وثبّت `app-release.apk`.
4. إذا فشل (❌) انسخ آخر 40 سطرًا من الخطوة الحمراء وأرسلها لي.

### توقيع ثابت (اختياري، مهم قبل التوزيع الواسع)
بدون توقيع ثابت، كل بناء يُوقّع بمفتاح مؤقت مختلف، فلا يمكن تحديث التطبيق فوق نسخة سابقة (يلزم حذفها). لتثبيت التوقيع أضف في **Settings ← Secrets and variables ← Actions** الأسرار: `ANDROID_KEYSTORE_BASE64` و`ANDROID_KEYSTORE_PASSWORD` و`ANDROID_KEY_ALIAS` و`ANDROID_KEY_PASSWORD`. إنشاء ملف keystore يحتاج أداة keytool؛ أخبرني عند الحاجة وأجهّز لك خطوات بديلة.

## 5) اختبار قواعد الأمان
تبويب **Actions ← Firestore Rules Tests** يعمل تلقائيًا عند أي تعديل على `firestore.rules`، ويشغّل ~90 اختبارًا على محاكي محلي مجاني (لا يلمس بياناتك). يجب أن يكون ✅ قبل أي نشر للقواعد.

## 6) google-services.json والأمان
- الملف مستخدم كما هو في `android/app/google-services.json` ولا توجد إعدادات بديلة.
- مفتاح API في هذا الملف **ليس سرًا بالمعنى الكامل**؛ أي شخص يفك التطبيق يستخرجه. الحماية الحقيقية في:
  1. **قواعد Firestore** (هي الحاجز الفعلي أمام القراءة والكتابة).
  2. **تقييد المفتاح** في Google Cloud Console ← APIs & Services ← Credentials ← المفتاح: *Android apps*: أضف الحزمة `com.khedmetosretthanawy.app` و SHA-1 (بعد تثبيت توقيع ثابت)، و*API restrictions*: اقصره على Identity Toolkit API و Token Service API و Cloud Firestore API و Firebase Installations API.
  3. وضع حصص/تنبيهات للاستهلاك من Billing ← Budgets (حتى مع Spark).
- إبقاء المستودع Private أفضل لكنه ليس بديلًا عن النقاط أعلاه.

## 7) صورة المقدمة (مارجرجس)
ضع صورة أصلية أو مرخصة باسم `assets/images/intro_george.png` (يمكن رفعها من GitHub مباشرة). إن لم توجد يظهر مشهد بديل (صليب ذهبي). التخطي متاح بعد ثانيتين.

## 8) تنبيه على الخط
الخط Cairo يُحمّل أول مرة من الإنترنت ثم يُحفظ. لجعله مضمنًا بالكامل ضع ملفات TTF في `assets/fonts` وأخبرني لأعدل الإعداد.
