// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'SUDOGRAM';

  @override
  String get chats => 'الشاتات';

  @override
  String get search => 'بحث';

  @override
  String get searchHint => 'ابحث في الشاتات';

  @override
  String get ghostMode => 'وضع الشبح';

  @override
  String get demoMode => 'وضع تجريبي';

  @override
  String get folderAll => 'الكل';

  @override
  String get folderPersonal => 'شخصي';

  @override
  String get folderWork => 'شغل';

  @override
  String get folderGroups => 'جروبات';

  @override
  String get tabChats => 'الشاتات';

  @override
  String get tabVault => 'الخزنة';

  @override
  String get tabTimeMachine => 'الآلة الزمنية';

  @override
  String get tabMore => 'المزيد';

  @override
  String get typeMessage => 'اكتب رسالة…';

  @override
  String get send => 'إرسال';

  @override
  String get attach => 'إرفاق';

  @override
  String get back => 'رجوع';

  @override
  String get silentRead => 'قراءة صامتة مفعّلة';

  @override
  String get ghostOnForChat => 'شبح لهذا الشات';

  @override
  String get ghostOffForChat => 'إيقاف الشبح لهذا الشات';

  @override
  String get hideChat => 'إخفاء الشات';

  @override
  String get unhideChat => 'إظهار الشات';

  @override
  String get vaultUnlocked => 'الخزنة مفتوحة';

  @override
  String get vaultLocked => 'الخزنة مقفولة';

  @override
  String get vaultAuthReason => 'تحقق من هويتك لفتح الشاتات المخفية';

  @override
  String get vaultUnavailable => 'البصمة أو قفل الشاشة غير متاحين على الجهاز';

  @override
  String get noChats => 'لا توجد شاتات';

  @override
  String get noMessages => 'لا توجد رسائل بعد';

  @override
  String get connecting => 'جاري الاتصال…';

  @override
  String get errorGeneric => 'حدث خطأ، حاول مرة أخرى';

  @override
  String get loginPhoneTitle => 'تسجيل الدخول';

  @override
  String get loginPhoneHint => 'رقم الهاتف مع كود الدولة';

  @override
  String get loginCodeTitle => 'كود التحقق';

  @override
  String get loginCodeHint => 'الكود اللي وصلك على تليجرام';

  @override
  String get loginPasswordTitle => 'كلمة سر التحقق بخطوتين';

  @override
  String get loginPasswordHint => 'كلمة السر';

  @override
  String get next => 'التالي';

  @override
  String get kindPhoto => 'صورة';

  @override
  String get kindVideo => 'فيديو';

  @override
  String get kindVoice => 'رسالة صوتية';

  @override
  String get kindDocument => 'ملف';

  @override
  String get kindSticker => 'ملصق';

  @override
  String get kindOther => 'رسالة';

  @override
  String splitPreview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتين',
      one: 'رسالة واحدة',
    );
    return '$_temp0';
  }

  @override
  String splitNotice(String count) {
    return 'الرسالة طويلة وهتتقسم إلى $count';
  }

  @override
  String get performanceMode => 'وضع الأداء';

  @override
  String get language => 'اللغة';

  @override
  String get deletedByPeer => 'اتمسحت من المُرسل';

  @override
  String get edited => 'معدّلة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appLock => 'قفل التطبيق';

  @override
  String get appLockHint => 'اطلب البصمة عند الرجوع للتطبيق';

  @override
  String get appLockReason => 'أكّد هويتك لفتح SUDOGRAM';

  @override
  String get unlock => 'فتح';

  @override
  String get editHistory => 'سجل التعديلات';

  @override
  String get noEdits => 'مفيش نسخ أقدم';

  @override
  String get archiveResults => 'من الأرشيف المحلي';

  @override
  String get currentVersion => 'الحالية';

  @override
  String get deletedBadge => 'محذوفة';

  @override
  String get ghostHint => 'من غير إيصال قراءة أو كتابة أو ظهور أونلاين';

  @override
  String get vault => 'الخزنة';

  @override
  String get vaultSetupTitle => 'إعداد الخزنة';

  @override
  String get vaultRealPass => 'الباسكود بتاعك';

  @override
  String get vaultDecoyPass => 'باسكود وهمي (بيفتح خزنة عادية)';

  @override
  String get vaultEnter => 'الباسكود';

  @override
  String get vaultWrong => 'باسكود غلط';

  @override
  String get vaultSave => 'حفظ';

  @override
  String get vaultAddTitle => 'العنوان';

  @override
  String get vaultAddBody => 'المحتوى';

  @override
  String get vaultAdd => 'إضافة';

  @override
  String get vaultEmpty => 'مفيش حاجة هنا لسه';

  @override
  String get vaultSamePass => 'لازم الباسكودين يكونوا مختلفين';

  @override
  String get intruderLog => 'محاولات فاشلة';

  @override
  String get timeMachine => 'آلة الزمن';

  @override
  String get pickChat => 'الشات';

  @override
  String get pickDate => 'اختار تاريخ';

  @override
  String get contactLog => 'تغييرات جهات الاتصال';

  @override
  String get contactLogEmpty => 'لسه ماشوفتش تغييرات';

  @override
  String get fieldName => 'الاسم';

  @override
  String get fieldUsername => 'اليوزر';

  @override
  String get fieldPhone => 'الرقم';

  @override
  String get tools => 'أدوات';

  @override
  String get attachFile => 'إرفاق ملف';

  @override
  String get download => 'تحميل';

  @override
  String get openFile => 'فتح';

  @override
  String get cancel => 'إلغاء';

  @override
  String fileSplitNotice(String count) {
    return 'الملف أكبر من حد تليجرام وهيتبعت على $count أجزاء';
  }

  @override
  String get sendingParts => 'بيتم إرسال الأجزاء…';

  @override
  String get joinParts => 'تجميع أجزاء ملف';

  @override
  String get joinPick => 'اختار كل الأجزاء وملف .manifest.json';

  @override
  String get joinDone => 'اتجمّع بنجاح';

  @override
  String joinFailed(String reason) {
    return 'فشل التجميع: $reason';
  }

  @override
  String get networkInspector => 'مراقب الشبكة';

  @override
  String get connState => 'الاتصال';

  @override
  String get netEmpty => 'مفيش طلبات لسه';

  @override
  String get pin => 'تثبيت';

  @override
  String get unpin => 'إلغاء التثبيت';

  @override
  String get addToFolder => 'المجلدات';

  @override
  String get newFolder => 'مجلد جديد';

  @override
  String get folderName => 'اسم المجلد';

  @override
  String get rename => 'إعادة تسمية (على الجهاز ده بس)';

  @override
  String get aliasHint => 'الاسم المحلي';

  @override
  String get clear => 'مسح';

  @override
  String get profiles => 'البروفايلات';

  @override
  String get saveProfile => 'احفظ الإعدادات الحالية كبروفايل';

  @override
  String get profileName => 'اسم البروفايل';

  @override
  String forwardedFrom(String name) {
    return 'محوّلة من $name';
  }

  @override
  String get hiddenForward => 'حساب مخفي';
}
