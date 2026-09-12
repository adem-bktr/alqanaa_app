# خطة تجهيز نسخة iOS والبناء السحابي عبر GitHub Actions

تهدف هذه الخطة إلى إعداد ملفات مشروع iOS لاستقبال الأذونات اللازمة وتوفير آلية لبناء التطبيق تلقائياً دون الحاجة لجهاز Mac، مع الحفاظ على اسم الحزمة الحالي لضمان التوافق مع Firebase و Google Play.

## تنبيهات للمراجعة
> [!IMPORTANT]
> **ملف Firebase:** يجب عليك إضافة تطبيق iOS في منصة Firebase Console، ثم تحميل ملف `GoogleService-Info.plist` ووضعه في مجلد `ios/Runner/`. بدون هذا الملف، سيفشل البناء أو سيتوقف التطبيق عند التشغيل.

> [!NOTE]
> **التثبيت على الهاتف:** بعد انتهاء البناء في GitHub، ستحصل على ملف بصيغة `.ipa`. ستحتاج لاستخدام برنامج مثل **Sideloadly** على ويندوز لتثبيته على آيفونك.

## التغييرات المقترحة

### إعدادات نظام iOS (Permissions & Bundle ID)

#### [MODIFY] [Info.plist](file:///C:/Users/Asus/AndroidStudioProjects/alqanaa_app/ios/Runner/Info.plist)
إضافة مفاتيح الأذونات (Privacy Keys) لتمكين الوصول إلى:
- الموقع (Location)
- البلوتوث (Bluetooth)
- الكاميرا والصور (Camera & Photos)

#### [MODIFY] [project.pbxproj](file:///C:/Users/Asus/AndroidStudioProjects/alqanaa_app/ios/Runner.xcodeproj/project.pbxproj)
التأكد من توحيد `PRODUCT_BUNDLE_IDENTIFIER` ليكون `com.alqanaaapp.grossiste`.

---

### البناء السحابي (CI/CD)

#### [NEW] [ios_build.yml](file:///C:/Users/Asus/AndroidStudioProjects/alqanaa_app/.github/workflows/ios_build.yml)
إنشاء ملف تعليمات لـ GitHub Actions يقوم بالآتي:
1. تشغيل بيئة macOS سحابية.
2. تثبيت Flutter وتهيئة المشروع.
3. بناء نسخة iOS (بدون توقيع رقمي - No Codesign) لتناسب التثبيت اليدوي (Sideloading).
4. رفع الملف الناتج (`.ipa`) كـ Artifact يمكنك تحميله.

## خطة التحقق

### التحقق الآلي
- تشغيل GitHub Action والتأكد من نجاح عملية البناء (Build Success).

### التحقق اليدوي
- تحميل ملف الـ `ipa` الناتج وتجربة تثبيته عبر Sideloadly على هاتف آيفون.
- التأكد من ظهور طلبات الأذونات (الموقع، البلوتوث) عند فتح التطبيق.
