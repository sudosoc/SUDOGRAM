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
