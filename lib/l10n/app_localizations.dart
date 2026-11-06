import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'SUDOGRAM'**
  String get appTitle;

  /// No description provided for @chats.
  ///
  /// In ar, this message translates to:
  /// **'الشاتات'**
  String get chats;

  /// No description provided for @search.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الشاتات'**
  String get searchHint;

  /// No description provided for @ghostMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع الشبح'**
  String get ghostMode;

  /// No description provided for @demoMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع تجريبي'**
  String get demoMode;

  /// No description provided for @folderAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get folderAll;

  /// No description provided for @folderPersonal.
  ///
  /// In ar, this message translates to:
  /// **'شخصي'**
  String get folderPersonal;

  /// No description provided for @folderWork.
  ///
  /// In ar, this message translates to:
  /// **'شغل'**
  String get folderWork;

  /// No description provided for @folderGroups.
  ///
  /// In ar, this message translates to:
  /// **'جروبات'**
  String get folderGroups;

  /// No description provided for @tabChats.
  ///
  /// In ar, this message translates to:
  /// **'الشاتات'**
  String get tabChats;

  /// No description provided for @tabVault.
  ///
  /// In ar, this message translates to:
  /// **'الخزنة'**
  String get tabVault;

  /// No description provided for @tabTimeMachine.
  ///
  /// In ar, this message translates to:
  /// **'الآلة الزمنية'**
  String get tabTimeMachine;

  /// No description provided for @tabMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get tabMore;

  /// No description provided for @typeMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة…'**
  String get typeMessage;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @attach.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق'**
  String get attach;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// No description provided for @silentRead.
  ///
  /// In ar, this message translates to:
  /// **'قراءة صامتة مفعّلة'**
  String get silentRead;

  /// No description provided for @ghostOnForChat.
  ///
  /// In ar, this message translates to:
  /// **'شبح لهذا الشات'**
  String get ghostOnForChat;

  /// No description provided for @ghostOffForChat.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف الشبح لهذا الشات'**
  String get ghostOffForChat;

  /// No description provided for @hideChat.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء الشات'**
  String get hideChat;

  /// No description provided for @unhideChat.
  ///
  /// In ar, this message translates to:
  /// **'إظهار الشات'**
  String get unhideChat;

  /// No description provided for @vaultUnlocked.
  ///
  /// In ar, this message translates to:
  /// **'الخزنة مفتوحة'**
  String get vaultUnlocked;

  /// No description provided for @vaultLocked.
  ///
  /// In ar, this message translates to:
  /// **'الخزنة مقفولة'**
  String get vaultLocked;

  /// No description provided for @vaultAuthReason.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من هويتك لفتح الشاتات المخفية'**
  String get vaultAuthReason;

  /// No description provided for @vaultUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'البصمة أو قفل الشاشة غير متاحين على الجهاز'**
  String get vaultUnavailable;

  /// No description provided for @noChats.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد شاتات'**
  String get noChats;

  /// No description provided for @noMessages.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد'**
  String get noMessages;

  /// No description provided for @connecting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الاتصال…'**
  String get connecting;

  /// No description provided for @errorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، حاول مرة أخرى'**
  String get errorGeneric;

  /// No description provided for @loginPhoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get loginPhoneTitle;

  /// No description provided for @loginPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف مع كود الدولة'**
  String get loginPhoneHint;

  /// No description provided for @loginCodeTitle.
  ///
  /// In ar, this message translates to:
  /// **'كود التحقق'**
  String get loginCodeTitle;

  /// No description provided for @loginCodeHint.
  ///
  /// In ar, this message translates to:
  /// **'الكود اللي وصلك على تليجرام'**
  String get loginCodeHint;

  /// No description provided for @loginPasswordTitle.
  ///
  /// In ar, this message translates to:
  /// **'كلمة سر التحقق بخطوتين'**
  String get loginPasswordTitle;

  /// No description provided for @loginPasswordHint.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر'**
  String get loginPasswordHint;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @kindPhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get kindPhoto;

  /// No description provided for @kindVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get kindVideo;

  /// No description provided for @kindVoice.
  ///
  /// In ar, this message translates to:
  /// **'رسالة صوتية'**
  String get kindVoice;

  /// No description provided for @kindDocument.
  ///
  /// In ar, this message translates to:
  /// **'ملف'**
  String get kindDocument;

  /// No description provided for @kindSticker.
  ///
  /// In ar, this message translates to:
  /// **'ملصق'**
  String get kindSticker;

  /// No description provided for @kindOther.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get kindOther;

  /// No description provided for @splitPreview.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{رسالة واحدة} =2{رسالتين} few{{count} رسائل} other{{count} رسالة}}'**
  String splitPreview(int count);

  /// No description provided for @splitNotice.
  ///
  /// In ar, this message translates to:
  /// **'الرسالة طويلة وهتتقسم إلى {count}'**
  String splitNotice(String count);

  /// No description provided for @performanceMode.
  ///
  /// In ar, this message translates to:
  /// **'وضع الأداء'**
  String get performanceMode;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @deletedByPeer.
  ///
  /// In ar, this message translates to:
  /// **'اتمسحت من المُرسل'**
  String get deletedByPeer;

  /// No description provided for @edited.
  ///
  /// In ar, this message translates to:
  /// **'معدّلة'**
  String get edited;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @appLock.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق'**
  String get appLock;

  /// No description provided for @appLockHint.
  ///
  /// In ar, this message translates to:
  /// **'اطلب البصمة عند الرجوع للتطبيق'**
  String get appLockHint;

  /// No description provided for @appLockReason.
  ///
  /// In ar, this message translates to:
  /// **'أكّد هويتك لفتح SUDOGRAM'**
  String get appLockReason;

  /// No description provided for @unlock.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get unlock;

  /// No description provided for @editHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل التعديلات'**
  String get editHistory;

  /// No description provided for @noEdits.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نسخ أقدم'**
  String get noEdits;

  /// No description provided for @archiveResults.
  ///
  /// In ar, this message translates to:
  /// **'من الأرشيف المحلي'**
  String get archiveResults;

  /// No description provided for @currentVersion.
  ///
  /// In ar, this message translates to:
  /// **'الحالية'**
  String get currentVersion;

  /// No description provided for @deletedBadge.
  ///
  /// In ar, this message translates to:
  /// **'محذوفة'**
  String get deletedBadge;

  /// No description provided for @ghostHint.
  ///
  /// In ar, this message translates to:
  /// **'من غير إيصال قراءة أو كتابة أو ظهور أونلاين'**
  String get ghostHint;

  /// No description provided for @vault.
  ///
  /// In ar, this message translates to:
  /// **'الخزنة'**
  String get vault;

  /// No description provided for @vaultSetupTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعداد الخزنة'**
  String get vaultSetupTitle;

  /// No description provided for @vaultRealPass.
  ///
  /// In ar, this message translates to:
  /// **'الباسكود بتاعك'**
  String get vaultRealPass;

  /// No description provided for @vaultDecoyPass.
  ///
  /// In ar, this message translates to:
  /// **'باسكود وهمي (بيفتح خزنة عادية)'**
  String get vaultDecoyPass;

  /// No description provided for @vaultEnter.
  ///
  /// In ar, this message translates to:
  /// **'الباسكود'**
  String get vaultEnter;

  /// No description provided for @vaultWrong.
  ///
  /// In ar, this message translates to:
  /// **'باسكود غلط'**
  String get vaultWrong;

  /// No description provided for @vaultSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get vaultSave;

  /// No description provided for @vaultAddTitle.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get vaultAddTitle;

  /// No description provided for @vaultAddBody.
  ///
  /// In ar, this message translates to:
  /// **'المحتوى'**
  String get vaultAddBody;

  /// No description provided for @vaultAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get vaultAdd;

  /// No description provided for @vaultEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش حاجة هنا لسه'**
  String get vaultEmpty;

  /// No description provided for @vaultSamePass.
  ///
  /// In ar, this message translates to:
  /// **'لازم الباسكودين يكونوا مختلفين'**
  String get vaultSamePass;

  /// No description provided for @intruderLog.
  ///
  /// In ar, this message translates to:
  /// **'محاولات فاشلة'**
  String get intruderLog;

  /// No description provided for @timeMachine.
  ///
  /// In ar, this message translates to:
  /// **'آلة الزمن'**
  String get timeMachine;

  /// No description provided for @pickChat.
  ///
  /// In ar, this message translates to:
  /// **'الشات'**
  String get pickChat;

  /// No description provided for @pickDate.
  ///
  /// In ar, this message translates to:
  /// **'اختار تاريخ'**
  String get pickDate;

  /// No description provided for @contactLog.
  ///
  /// In ar, this message translates to:
  /// **'تغييرات جهات الاتصال'**
  String get contactLog;

  /// No description provided for @contactLogEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لسه ماشوفتش تغييرات'**
  String get contactLogEmpty;

  /// No description provided for @fieldName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get fieldName;

  /// No description provided for @fieldUsername.
  ///
  /// In ar, this message translates to:
  /// **'اليوزر'**
  String get fieldUsername;

  /// No description provided for @fieldPhone.
  ///
  /// In ar, this message translates to:
  /// **'الرقم'**
  String get fieldPhone;

  /// No description provided for @tools.
  ///
  /// In ar, this message translates to:
  /// **'أدوات'**
  String get tools;

  /// No description provided for @attachFile.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق ملف'**
  String get attachFile;

  /// No description provided for @download.
  ///
  /// In ar, this message translates to:
  /// **'تحميل'**
  String get download;

  /// No description provided for @openFile.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get openFile;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @fileSplitNotice.
  ///
  /// In ar, this message translates to:
  /// **'الملف أكبر من حد تليجرام وهيتبعت على {count} أجزاء'**
  String fileSplitNotice(String count);

  /// No description provided for @sendingParts.
  ///
  /// In ar, this message translates to:
  /// **'بيتم إرسال الأجزاء…'**
  String get sendingParts;

  /// No description provided for @joinParts.
  ///
  /// In ar, this message translates to:
  /// **'تجميع أجزاء ملف'**
  String get joinParts;

  /// No description provided for @joinPick.
  ///
  /// In ar, this message translates to:
  /// **'اختار كل الأجزاء وملف .manifest.json'**
  String get joinPick;

  /// No description provided for @joinDone.
  ///
  /// In ar, this message translates to:
  /// **'اتجمّع بنجاح'**
  String get joinDone;

  /// No description provided for @joinFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التجميع: {reason}'**
  String joinFailed(String reason);

  /// No description provided for @networkInspector.
  ///
  /// In ar, this message translates to:
  /// **'مراقب الشبكة'**
  String get networkInspector;

  /// No description provided for @connState.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال'**
  String get connState;

  /// No description provided for @netEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش طلبات لسه'**
  String get netEmpty;

  /// No description provided for @pin.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت الرسالة'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت'**
  String get unpin;

  /// No description provided for @addToFolder.
  ///
  /// In ar, this message translates to:
  /// **'المجلدات'**
  String get addToFolder;

  /// No description provided for @newFolder.
  ///
  /// In ar, this message translates to:
  /// **'مجلد جديد'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المجلد'**
  String get folderName;

  /// No description provided for @rename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية (على الجهاز ده بس)'**
  String get rename;

  /// No description provided for @aliasHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم المحلي'**
  String get aliasHint;

  /// No description provided for @clear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clear;

  /// No description provided for @profiles.
  ///
  /// In ar, this message translates to:
  /// **'البروفايلات'**
  String get profiles;

  /// No description provided for @saveProfile.
  ///
  /// In ar, this message translates to:
  /// **'احفظ الإعدادات الحالية كبروفايل'**
  String get saveProfile;

  /// No description provided for @profileName.
  ///
  /// In ar, this message translates to:
  /// **'اسم البروفايل'**
  String get profileName;

  /// No description provided for @forwardedFrom.
  ///
  /// In ar, this message translates to:
  /// **'محوّلة من {name}'**
  String forwardedFrom(String name);

  /// No description provided for @hiddenForward.
  ///
  /// In ar, this message translates to:
  /// **'حساب مخفي'**
  String get hiddenForward;

  /// No description provided for @rules.
  ///
  /// In ar, this message translates to:
  /// **'القواعد'**
  String get rules;

  /// No description provided for @rulesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'مفيش قواعد لسه'**
  String get rulesEmpty;

  /// No description provided for @ruleAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة قاعدة'**
  String get ruleAdd;

  /// No description provided for @ruleName.
  ///
  /// In ar, this message translates to:
  /// **'اسم القاعدة'**
  String get ruleName;

  /// No description provided for @ruleChat.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشات فيه'**
  String get ruleChat;

  /// No description provided for @ruleText.
  ///
  /// In ar, this message translates to:
  /// **'الرسالة فيها'**
  String get ruleText;

  /// No description provided for @ruleKind.
  ///
  /// In ar, this message translates to:
  /// **'نوع الرسالة'**
  String get ruleKind;

  /// No description provided for @anyKind.
  ///
  /// In ar, this message translates to:
  /// **'أي نوع'**
  String get anyKind;

  /// No description provided for @ruleDo.
  ///
  /// In ar, this message translates to:
  /// **'اعمل'**
  String get ruleDo;

  /// No description provided for @actPin.
  ///
  /// In ar, this message translates to:
  /// **'ثبّت الشات'**
  String get actPin;

  /// No description provided for @actHide.
  ///
  /// In ar, this message translates to:
  /// **'اخفي الشات'**
  String get actHide;

  /// No description provided for @actGhostOn.
  ///
  /// In ar, this message translates to:
  /// **'شغّل Ghost للشات'**
  String get actGhostOn;

  /// No description provided for @actGhostOff.
  ///
  /// In ar, this message translates to:
  /// **'اقفل Ghost للشات'**
  String get actGhostOff;

  /// No description provided for @actFolder.
  ///
  /// In ar, this message translates to:
  /// **'ضيفه لمجلد'**
  String get actFolder;

  /// No description provided for @ruleExport.
  ///
  /// In ar, this message translates to:
  /// **'انسخ حزمة القواعد'**
  String get ruleExport;

  /// No description provided for @ruleImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد حزمة قواعد'**
  String get ruleImport;

  /// No description provided for @ruleImportHint.
  ///
  /// In ar, this message translates to:
  /// **'الصق حزمة القواعد هنا'**
  String get ruleImportHint;

  /// No description provided for @ruleCopied.
  ///
  /// In ar, this message translates to:
  /// **'اتنسخ'**
  String get ruleCopied;

  /// No description provided for @ruleBad.
  ///
  /// In ar, this message translates to:
  /// **'حزمة قواعد مش صالحة'**
  String get ruleBad;

  /// No description provided for @ruleImported.
  ///
  /// In ar, this message translates to:
  /// **'اتستورد {count} قواعد'**
  String ruleImported(int count);

  /// No description provided for @attachMedia.
  ///
  /// In ar, this message translates to:
  /// **'صور وفيديوهات'**
  String get attachMedia;

  /// No description provided for @you.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get you;

  /// No description provided for @typing.
  ///
  /// In ar, this message translates to:
  /// **'بيكتب…'**
  String get typing;

  /// No description provided for @online.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get online;

  /// No description provided for @seenRecently.
  ///
  /// In ar, this message translates to:
  /// **'شوهد مؤخرًا'**
  String get seenRecently;

  /// No description provided for @seenWeek.
  ///
  /// In ar, this message translates to:
  /// **'شوهد خلال الأسبوع'**
  String get seenWeek;

  /// No description provided for @seenMonth.
  ///
  /// In ar, this message translates to:
  /// **'شوهد خلال الشهر'**
  String get seenMonth;

  /// No description provided for @seenAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر ظهور {time}'**
  String seenAt(String time);

  /// No description provided for @groupLabel.
  ///
  /// In ar, this message translates to:
  /// **'مجموعة'**
  String get groupLabel;

  /// No description provided for @channelLabel.
  ///
  /// In ar, this message translates to:
  /// **'قناة'**
  String get channelLabel;

  /// No description provided for @reply.
  ///
  /// In ar, this message translates to:
  /// **'رد'**
  String get reply;

  /// No description provided for @copy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @forward.
  ///
  /// In ar, this message translates to:
  /// **'تحويل'**
  String get forward;

  /// No description provided for @deleteForMe.
  ///
  /// In ar, this message translates to:
  /// **'حذف عندي'**
  String get deleteForMe;

  /// No description provided for @deleteForAll.
  ///
  /// In ar, this message translates to:
  /// **'حذف للجميع'**
  String get deleteForAll;

  /// No description provided for @deleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الرسالة؟'**
  String get deleteTitle;

  /// No description provided for @cantPost.
  ///
  /// In ar, this message translates to:
  /// **'مينفعش تكتب هنا'**
  String get cantPost;

  /// No description provided for @forwardTo.
  ///
  /// In ar, this message translates to:
  /// **'حوّل إلى'**
  String get forwardTo;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'النهاردة'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'إمبارح'**
  String get yesterday;

  /// No description provided for @editingMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرسالة'**
  String get editingMessage;

  /// No description provided for @replyingTo.
  ///
  /// In ar, this message translates to:
  /// **'رد على'**
  String get replyingTo;

  /// No description provided for @copied.
  ///
  /// In ar, this message translates to:
  /// **'اتنسخ'**
  String get copied;

  /// No description provided for @muted.
  ///
  /// In ar, this message translates to:
  /// **'مكتوم'**
  String get muted;

  /// No description provided for @photoLoading.
  ///
  /// In ar, this message translates to:
  /// **'بيتحمّل…'**
  String get photoLoading;

  /// No description provided for @mediaMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة'**
  String get mediaMessage;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @contacts.
  ///
  /// In ar, this message translates to:
  /// **'جهات الاتصال'**
  String get contacts;

  /// No description provided for @savedMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل المحفوظة'**
  String get savedMessages;

  /// No description provided for @searchInChat.
  ///
  /// In ar, this message translates to:
  /// **'بحث في الشات'**
  String get searchInChat;

  /// No description provided for @pinnedMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة مثبتة'**
  String get pinnedMessage;

  /// No description provided for @noResults.
  ///
  /// In ar, this message translates to:
  /// **'مفيش نتايج'**
  String get noResults;

  /// No description provided for @newChat.
  ///
  /// In ar, this message translates to:
  /// **'شات جديد'**
  String get newChat;

  /// No description provided for @notificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notificationsTitle;

  /// No description provided for @notificationsHint.
  ///
  /// In ar, this message translates to:
  /// **'يفضل متصل في الخلفية ويعرض الرسايل الجديدة'**
  String get notificationsHint;

  /// No description provided for @keepConnectedText.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get keepConnectedText;

  /// No description provided for @newMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة'**
  String get newMessage;

  /// No description provided for @info.
  ///
  /// In ar, this message translates to:
  /// **'معلومات'**
  String get info;

  /// No description provided for @username.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم'**
  String get username;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل'**
  String get phone;

  /// No description provided for @about.
  ///
  /// In ar, this message translates to:
  /// **'نبذة'**
  String get about;

  /// No description provided for @membersCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} عضو'**
  String membersCount(String n);

  /// No description provided for @react.
  ///
  /// In ar, this message translates to:
  /// **'تفاعل'**
  String get react;

  /// No description provided for @archive.
  ///
  /// In ar, this message translates to:
  /// **'الأرشيف'**
  String get archive;

  /// No description provided for @archiveChat.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get archiveChat;

  /// No description provided for @unarchiveChat.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الأرشفة'**
  String get unarchiveChat;

  /// No description provided for @draft.
  ///
  /// In ar, this message translates to:
  /// **'مسودة'**
  String get draft;

  /// No description provided for @devices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة'**
  String get devices;

  /// No description provided for @thisDevice.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز ده'**
  String get thisDevice;

  /// No description provided for @terminate.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل خروج'**
  String get terminate;

  /// No description provided for @newGroup.
  ///
  /// In ar, this message translates to:
  /// **'مجموعة جديدة'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المجموعة'**
  String get groupName;

  /// No description provided for @create.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء'**
  String get create;

  /// No description provided for @pollClosed.
  ///
  /// In ar, this message translates to:
  /// **'النتائج النهائية'**
  String get pollClosed;

  /// No description provided for @votesCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} صوت'**
  String votesCount(String n);

  /// No description provided for @privacy.
  ///
  /// In ar, this message translates to:
  /// **'الخصوصية'**
  String get privacy;

  /// No description provided for @privPhone.
  ///
  /// In ar, this message translates to:
  /// **'مين يشوف رقمي'**
  String get privPhone;

  /// No description provided for @privSeen.
  ///
  /// In ar, this message translates to:
  /// **'مين يشوف آخر ظهور'**
  String get privSeen;

  /// No description provided for @privPhoto.
  ///
  /// In ar, this message translates to:
  /// **'مين يشوف صورتي'**
  String get privPhoto;

  /// No description provided for @privCalls.
  ///
  /// In ar, this message translates to:
  /// **'مين يقدر يكلمني'**
  String get privCalls;

  /// No description provided for @privInvites.
  ///
  /// In ar, this message translates to:
  /// **'مين يضيفني في مجموعات'**
  String get privInvites;

  /// No description provided for @privForwards.
  ///
  /// In ar, this message translates to:
  /// **'رابط حسابي في الرسايل المحولة'**
  String get privForwards;

  /// No description provided for @everybody.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get everybody;

  /// No description provided for @myContacts.
  ///
  /// In ar, this message translates to:
  /// **'جهات اتصالي'**
  String get myContacts;

  /// No description provided for @nobody.
  ///
  /// In ar, this message translates to:
  /// **'محدش'**
  String get nobody;

  /// No description provided for @secretChat.
  ///
  /// In ar, this message translates to:
  /// **'بدء شات سري'**
  String get secretChat;

  /// No description provided for @secretNote.
  ///
  /// In ar, this message translates to:
  /// **'مشفر من طرف لطرف. على الجهاز ده بس.'**
  String get secretNote;

  /// No description provided for @selfDestruct.
  ///
  /// In ar, this message translates to:
  /// **'مؤقت الحذف التلقائي'**
  String get selfDestruct;

  /// No description provided for @timerOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get timerOff;

  /// No description provided for @timer1m.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get timer1m;

  /// No description provided for @timer1h.
  ///
  /// In ar, this message translates to:
  /// **'ساعة'**
  String get timer1h;

  /// No description provided for @timer1d.
  ///
  /// In ar, this message translates to:
  /// **'يوم'**
  String get timer1d;

  /// No description provided for @backgroundTitle.
  ///
  /// In ar, this message translates to:
  /// **'السماح بالعمل في الخلفية'**
  String get backgroundTitle;

  /// No description provided for @backgroundBody.
  ///
  /// In ar, this message translates to:
  /// **'عشان تظهرلك الرسايل الجديدة والتطبيق مقفول، لازم SUDOGRAM يفضل شغال في الخلفية. وافق في الشاشة الجاية.'**
  String get backgroundBody;

  /// No description provided for @later.
  ///
  /// In ar, this message translates to:
  /// **'بعدين'**
  String get later;

  /// No description provided for @allow.
  ///
  /// In ar, this message translates to:
  /// **'سماح'**
  String get allow;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'البروفايل'**
  String get profile;

  /// No description provided for @firstName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الأول'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In ar, this message translates to:
  /// **'اسم العيلة'**
  String get lastName;

  /// No description provided for @bioLabel.
  ///
  /// In ar, this message translates to:
  /// **'النبذة'**
  String get bioLabel;

  /// No description provided for @changePhoto.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الصورة'**
  String get changePhoto;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل خروج'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تسجّل خروج من الحساب ده؟ الأرشيف المحلي هيفضل على الجهاز.'**
  String get logoutConfirm;

  /// No description provided for @saved.
  ///
  /// In ar, this message translates to:
  /// **'اتحفظ'**
  String get saved;

  /// No description provided for @usernameTaken.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستخدم مأخوذ أو غير صالح'**
  String get usernameTaken;

  /// No description provided for @mute.
  ///
  /// In ar, this message translates to:
  /// **'كتم'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الكتم'**
  String get unmute;

  /// No description provided for @clearHistory.
  ///
  /// In ar, this message translates to:
  /// **'مسح المحادثة'**
  String get clearHistory;

  /// No description provided for @deleteChat.
  ///
  /// In ar, this message translates to:
  /// **'حذف الشات'**
  String get deleteChat;

  /// No description provided for @leaveChat.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة وحذف'**
  String get leaveChat;

  /// No description provided for @blockUser.
  ///
  /// In ar, this message translates to:
  /// **'حظر'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الحظر'**
  String get unblockUser;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get gallery;

  /// No description provided for @cameraPhoto.
  ///
  /// In ar, this message translates to:
  /// **'تصوير صورة'**
  String get cameraPhoto;

  /// No description provided for @cameraVideo.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل فيديو'**
  String get cameraVideo;

  /// No description provided for @fileLabel.
  ///
  /// In ar, this message translates to:
  /// **'ملف'**
  String get fileLabel;

  /// No description provided for @sendFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الإرسال: {e}'**
  String sendFailed(String e);

  /// No description provided for @recording.
  ///
  /// In ar, this message translates to:
  /// **'بيسجّل…'**
  String get recording;

  /// No description provided for @micDenied.
  ///
  /// In ar, this message translates to:
  /// **'إذن المايك مرفوض'**
  String get micDenied;

  /// No description provided for @micUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'الموبايل ده مش بيسجل صوت بصيغة Opus'**
  String get micUnsupported;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'متأكد؟'**
  String get confirm;

  /// No description provided for @cancelAction.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancelAction;

  /// No description provided for @hiddenChatsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشاتات المخفية'**
  String get hiddenChatsTitle;

  /// No description provided for @noHiddenChats.
  ///
  /// In ar, this message translates to:
  /// **'مفيش شاتات مخفية لسه. اضغط مطول على أي شات واختار إخفاء.'**
  String get noHiddenChats;

  /// No description provided for @joinByLink.
  ///
  /// In ar, this message translates to:
  /// **'انضمام برابط دعوة'**
  String get joinByLink;

  /// No description provided for @pasteLink.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط الدعوة'**
  String get pasteLink;

  /// No description provided for @join.
  ///
  /// In ar, this message translates to:
  /// **'انضمام'**
  String get join;

  /// No description provided for @blocked.
  ///
  /// In ar, this message translates to:
  /// **'المحظورين'**
  String get blocked;

  /// No description provided for @noBlocked.
  ///
  /// In ar, this message translates to:
  /// **'مفيش محظورين'**
  String get noBlocked;

  /// No description provided for @twoStep.
  ///
  /// In ar, this message translates to:
  /// **'التحقق بخطوتين'**
  String get twoStep;

  /// No description provided for @twoStepOn.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get twoStepOn;

  /// No description provided for @twoStepOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get twoStepOff;

  /// No description provided for @oldPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر الحالية'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر الجديدة (فاضي = إيقاف)'**
  String get newPassword;

  /// No description provided for @passwordHint.
  ///
  /// In ar, this message translates to:
  /// **'تلميح'**
  String get passwordHint;

  /// No description provided for @passwordChanged.
  ///
  /// In ar, this message translates to:
  /// **'اتحدثت كلمة السر'**
  String get passwordChanged;

  /// No description provided for @passwordFailed.
  ///
  /// In ar, this message translates to:
  /// **'كلمة السر غلط أو اترفضت'**
  String get passwordFailed;

  /// No description provided for @stickers.
  ///
  /// In ar, this message translates to:
  /// **'ستيكرز'**
  String get stickers;

  /// No description provided for @members.
  ///
  /// In ar, this message translates to:
  /// **'الأعضاء'**
  String get members;

  /// No description provided for @addMember.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عضو'**
  String get addMember;

  /// No description provided for @removeMember.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get removeMember;

  /// No description provided for @wallpaper.
  ///
  /// In ar, this message translates to:
  /// **'خلفية الشات'**
  String get wallpaper;

  /// No description provided for @telegramResults.
  ///
  /// In ar, this message translates to:
  /// **'نتائج تليجرام'**
  String get telegramResults;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @createPoll.
  ///
  /// In ar, this message translates to:
  /// **'استطلاع'**
  String get createPoll;

  /// No description provided for @pollQuestion.
  ///
  /// In ar, this message translates to:
  /// **'السؤال'**
  String get pollQuestion;

  /// No description provided for @pollOption.
  ///
  /// In ar, this message translates to:
  /// **'الخيار {n}'**
  String pollOption(String n);

  /// No description provided for @pollMultiple.
  ///
  /// In ar, this message translates to:
  /// **'السماح بأكتر من إجابة'**
  String get pollMultiple;

  /// No description provided for @location.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get location;

  /// No description provided for @contactLabel.
  ///
  /// In ar, this message translates to:
  /// **'جهة اتصال'**
  String get contactLabel;

  /// No description provided for @gif.
  ///
  /// In ar, this message translates to:
  /// **'GIF'**
  String get gif;

  /// No description provided for @locationDenied.
  ///
  /// In ar, this message translates to:
  /// **'إذن الموقع مرفوض'**
  String get locationDenied;

  /// No description provided for @send2.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send2;

  /// No description provided for @select.
  ///
  /// In ar, this message translates to:
  /// **'تحديد'**
  String get select;

  /// No description provided for @selectedCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} محدد'**
  String selectedCount(String n);

  /// No description provided for @share.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get share;

  /// No description provided for @resend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get resend;

  /// No description provided for @sendingFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الإرسال'**
  String get sendingFailed;

  /// No description provided for @jumpToLatest.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث'**
  String get jumpToLatest;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
