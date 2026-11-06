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
  String get pin => 'تثبيت الرسالة';

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

  @override
  String get rules => 'القواعد';

  @override
  String get rulesEmpty => 'مفيش قواعد لسه';

  @override
  String get ruleAdd => 'إضافة قاعدة';

  @override
  String get ruleName => 'اسم القاعدة';

  @override
  String get ruleChat => 'اسم الشات فيه';

  @override
  String get ruleText => 'الرسالة فيها';

  @override
  String get ruleKind => 'نوع الرسالة';

  @override
  String get anyKind => 'أي نوع';

  @override
  String get ruleDo => 'اعمل';

  @override
  String get actPin => 'ثبّت الشات';

  @override
  String get actHide => 'اخفي الشات';

  @override
  String get actGhostOn => 'شغّل Ghost للشات';

  @override
  String get actGhostOff => 'اقفل Ghost للشات';

  @override
  String get actFolder => 'ضيفه لمجلد';

  @override
  String get ruleExport => 'انسخ حزمة القواعد';

  @override
  String get ruleImport => 'استيراد حزمة قواعد';

  @override
  String get ruleImportHint => 'الصق حزمة القواعد هنا';

  @override
  String get ruleCopied => 'اتنسخ';

  @override
  String get ruleBad => 'حزمة قواعد مش صالحة';

  @override
  String ruleImported(int count) {
    return 'اتستورد $count قواعد';
  }

  @override
  String get attachMedia => 'صور وفيديوهات';

  @override
  String get you => 'أنت';

  @override
  String get typing => 'بيكتب…';

  @override
  String get online => 'متصل';

  @override
  String get seenRecently => 'شوهد مؤخرًا';

  @override
  String get seenWeek => 'شوهد خلال الأسبوع';

  @override
  String get seenMonth => 'شوهد خلال الشهر';

  @override
  String seenAt(String time) {
    return 'آخر ظهور $time';
  }

  @override
  String get groupLabel => 'مجموعة';

  @override
  String get channelLabel => 'قناة';

  @override
  String get reply => 'رد';

  @override
  String get copy => 'نسخ';

  @override
  String get edit => 'تعديل';

  @override
  String get forward => 'تحويل';

  @override
  String get deleteForMe => 'حذف عندي';

  @override
  String get deleteForAll => 'حذف للجميع';

  @override
  String get deleteTitle => 'حذف الرسالة؟';

  @override
  String get cantPost => 'مينفعش تكتب هنا';

  @override
  String get forwardTo => 'حوّل إلى';

  @override
  String get today => 'النهاردة';

  @override
  String get yesterday => 'إمبارح';

  @override
  String get editingMessage => 'تعديل الرسالة';

  @override
  String get replyingTo => 'رد على';

  @override
  String get copied => 'اتنسخ';

  @override
  String get muted => 'مكتوم';

  @override
  String get photoLoading => 'بيتحمّل…';

  @override
  String get mediaMessage => 'رسالة';

  @override
  String get delete => 'حذف';

  @override
  String get contacts => 'جهات الاتصال';

  @override
  String get savedMessages => 'الرسائل المحفوظة';

  @override
  String get searchInChat => 'بحث في الشات';

  @override
  String get pinnedMessage => 'رسالة مثبتة';

  @override
  String get noResults => 'مفيش نتايج';

  @override
  String get newChat => 'شات جديد';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsHint => 'يفضل متصل في الخلفية ويعرض الرسايل الجديدة';

  @override
  String get keepConnectedText => 'متصل';

  @override
  String get newMessage => 'رسالة جديدة';

  @override
  String get info => 'معلومات';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get phone => 'الموبايل';

  @override
  String get about => 'نبذة';

  @override
  String membersCount(String n) {
    return '$n عضو';
  }

  @override
  String get react => 'تفاعل';

  @override
  String get archive => 'الأرشيف';

  @override
  String get archiveChat => 'أرشفة';

  @override
  String get unarchiveChat => 'إلغاء الأرشفة';

  @override
  String get draft => 'مسودة';

  @override
  String get devices => 'الأجهزة';

  @override
  String get thisDevice => 'الجهاز ده';

  @override
  String get terminate => 'تسجيل خروج';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get create => 'إنشاء';

  @override
  String get pollClosed => 'النتائج النهائية';

  @override
  String votesCount(String n) {
    return '$n صوت';
  }

  @override
  String get privacy => 'الخصوصية';

  @override
  String get privPhone => 'مين يشوف رقمي';

  @override
  String get privSeen => 'مين يشوف آخر ظهور';

  @override
  String get privPhoto => 'مين يشوف صورتي';

  @override
  String get privCalls => 'مين يقدر يكلمني';

  @override
  String get privInvites => 'مين يضيفني في مجموعات';

  @override
  String get privForwards => 'رابط حسابي في الرسايل المحولة';

  @override
  String get everybody => 'الكل';

  @override
  String get myContacts => 'جهات اتصالي';

  @override
  String get nobody => 'محدش';

  @override
  String get secretChat => 'بدء شات سري';

  @override
  String get secretNote => 'مشفر من طرف لطرف. على الجهاز ده بس.';

  @override
  String get selfDestruct => 'مؤقت الحذف التلقائي';

  @override
  String get timerOff => 'متوقف';

  @override
  String get timer1m => 'دقيقة';

  @override
  String get timer1h => 'ساعة';

  @override
  String get timer1d => 'يوم';

  @override
  String get backgroundTitle => 'السماح بالعمل في الخلفية';

  @override
  String get backgroundBody =>
      'عشان تظهرلك الرسايل الجديدة والتطبيق مقفول، لازم SUDOGRAM يفضل شغال في الخلفية. وافق في الشاشة الجاية.';

  @override
  String get later => 'بعدين';

  @override
  String get allow => 'سماح';

  @override
  String get profile => 'البروفايل';

  @override
  String get firstName => 'الاسم الأول';

  @override
  String get lastName => 'اسم العيلة';

  @override
  String get bioLabel => 'النبذة';

  @override
  String get changePhoto => 'تغيير الصورة';

  @override
  String get logout => 'تسجيل خروج';

  @override
  String get logoutConfirm =>
      'تسجّل خروج من الحساب ده؟ الأرشيف المحلي هيفضل على الجهاز.';

  @override
  String get saved => 'اتحفظ';

  @override
  String get usernameTaken => 'اسم المستخدم مأخوذ أو غير صالح';

  @override
  String get mute => 'كتم';

  @override
  String get unmute => 'إلغاء الكتم';

  @override
  String get clearHistory => 'مسح المحادثة';

  @override
  String get deleteChat => 'حذف الشات';

  @override
  String get leaveChat => 'مغادرة وحذف';

  @override
  String get blockUser => 'حظر';

  @override
  String get unblockUser => 'إلغاء الحظر';

  @override
  String get gallery => 'المعرض';

  @override
  String get cameraPhoto => 'تصوير صورة';

  @override
  String get cameraVideo => 'تسجيل فيديو';

  @override
  String get fileLabel => 'ملف';

  @override
  String sendFailed(String e) {
    return 'فشل الإرسال: $e';
  }

  @override
  String get recording => 'بيسجّل…';

  @override
  String get micDenied => 'إذن المايك مرفوض';

  @override
  String get micUnsupported => 'الموبايل ده مش بيسجل صوت بصيغة Opus';

  @override
  String get confirm => 'متأكد؟';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get hiddenChatsTitle => 'الشاتات المخفية';

  @override
  String get noHiddenChats =>
      'مفيش شاتات مخفية لسه. اضغط مطول على أي شات واختار إخفاء.';

  @override
  String get joinByLink => 'انضمام برابط دعوة';

  @override
  String get pasteLink => 'الصق رابط الدعوة';

  @override
  String get join => 'انضمام';

  @override
  String get blocked => 'المحظورين';

  @override
  String get noBlocked => 'مفيش محظورين';

  @override
  String get twoStep => 'التحقق بخطوتين';

  @override
  String get twoStepOn => 'مفعّل';

  @override
  String get twoStepOff => 'متوقف';

  @override
  String get oldPassword => 'كلمة السر الحالية';

  @override
  String get newPassword => 'كلمة السر الجديدة (فاضي = إيقاف)';

  @override
  String get passwordHint => 'تلميح';

  @override
  String get passwordChanged => 'اتحدثت كلمة السر';

  @override
  String get passwordFailed => 'كلمة السر غلط أو اترفضت';

  @override
  String get stickers => 'ستيكرز';

  @override
  String get members => 'الأعضاء';

  @override
  String get addMember => 'إضافة عضو';

  @override
  String get removeMember => 'إزالة';

  @override
  String get wallpaper => 'خلفية الشات';

  @override
  String get telegramResults => 'نتائج تليجرام';

  @override
  String get done => 'تم';

  @override
  String get createPoll => 'استطلاع';

  @override
  String get pollQuestion => 'السؤال';

  @override
  String pollOption(String n) {
    return 'الخيار $n';
  }

  @override
  String get pollMultiple => 'السماح بأكتر من إجابة';

  @override
  String get location => 'الموقع';

  @override
  String get contactLabel => 'جهة اتصال';

  @override
  String get gif => 'GIF';

  @override
  String get locationDenied => 'إذن الموقع مرفوض';

  @override
  String get send2 => 'إرسال';
}
