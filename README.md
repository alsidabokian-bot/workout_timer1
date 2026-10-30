# عداد التمرين

عداد تنازلي للتمارين (تمرين / راحة / جولات) بتنبيهات صوتية واهتزاز، مبني بـ Flutter.

## البناء
- من GitHub: Actions ← **Build Flutter APK** ← Run workflow، ثم نزّل `app-release` من Artifacts.
- محليًا: `flutter pub get` ثم `flutter build apk --release`.

## قبل النشر في المتجر
- غيّر معرّف الحزمة `com.tamreen.counter` إن أردت معرّفًا خاصًا بك (في `android/app/build.gradle` و`MainActivity.kt` ومجلد `kotlin`).
- الإصدار الحالي موقّع بمفتاح debug؛ أنشئ مفتاح توقيع خاصًا للنشر.

## الملفات
| الملف | الوظيفة |
|---|---|
| `lib/main.dart` | نقطة البدء والثيم |
| `lib/store.dart` | الإعدادات المحفوظة |
| `lib/timer_engine.dart` | منطق التمرين والراحة والجولات |
| `lib/sound_service.dart` | الصفير والنغمات والاهتزاز |
| `lib/setup_screen.dart` | ضبط الأوقات |
| `lib/workout_screen.dart` | شاشة العدّ |
| `lib/settings_screen.dart` | الصوت والاهتزاز والمظهر |
| `lib/app_background.dart` | خلفية الصورة وطبقة التعتيم |
| `assets/sounds/` | نغمات التنبيه (WAV) |
| `assets/images/bg.jpg` | صورة واجهة التطبيق (استبدلها بصورة أخرى بنفس الاسم) |

## ملاحظة
المؤقت دقيق حتى لو انتقل التطبيق للخلفية، لكن الصفير أثناء إطفاء الشاشة غير مضمون لأن التطبيق لا يستخدم خدمة خلفية. الشاشة تبقى مضاءة أثناء التمرين.
