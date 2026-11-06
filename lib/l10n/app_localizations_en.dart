// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SUDOGRAM';

  @override
  String get chats => 'Chats';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search chats';

  @override
  String get ghostMode => 'Ghost Mode';

  @override
  String get demoMode => 'Demo mode';

  @override
  String get folderAll => 'All';

  @override
  String get folderPersonal => 'Personal';

  @override
  String get folderWork => 'Work';

  @override
  String get folderGroups => 'Groups';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabVault => 'Vault';

  @override
  String get tabTimeMachine => 'Time Machine';

  @override
  String get tabMore => 'More';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get send => 'Send';

  @override
  String get attach => 'Attach';

  @override
  String get back => 'Back';

  @override
  String get silentRead => 'Silent read is on';

  @override
  String get ghostOnForChat => 'Ghost for this chat';

  @override
  String get ghostOffForChat => 'Turn off ghost for this chat';

  @override
  String get hideChat => 'Hide chat';

  @override
  String get unhideChat => 'Unhide chat';

  @override
  String get vaultUnlocked => 'Vault unlocked';

  @override
  String get vaultLocked => 'Vault locked';

  @override
  String get vaultAuthReason => 'Verify your identity to open hidden chats';

  @override
  String get vaultUnavailable =>
      'Biometrics or screen lock are not available on this device';

  @override
  String get noChats => 'No chats';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get connecting => 'Connecting…';

  @override
  String get errorGeneric => 'Something went wrong, try again';

  @override
  String get loginPhoneTitle => 'Sign in';

  @override
  String get loginPhoneHint => 'Phone number with country code';

  @override
  String get loginCodeTitle => 'Verification code';

  @override
  String get loginCodeHint => 'The code sent to your Telegram';

  @override
  String get loginPasswordTitle => 'Two-step verification password';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get next => 'Next';

  @override
  String get kindPhoto => 'Photo';

  @override
  String get kindVideo => 'Video';

  @override
  String get kindVoice => 'Voice message';

  @override
  String get kindDocument => 'File';

  @override
  String get kindSticker => 'Sticker';

  @override
  String get kindOther => 'Message';

  @override
  String splitPreview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String splitNotice(String count) {
    return 'Long message, will be split into $count';
  }

  @override
  String get performanceMode => 'Performance mode';

  @override
  String get language => 'Language';

  @override
  String get deletedByPeer => 'Deleted by sender';

  @override
  String get edited => 'edited';

  @override
  String get settings => 'Settings';

  @override
  String get appLock => 'App Lock';

  @override
  String get appLockHint => 'Ask for fingerprint when returning to the app';

  @override
  String get appLockReason => 'Verify your identity to open SUDOGRAM';

  @override
  String get unlock => 'Unlock';

  @override
  String get editHistory => 'Edit history';

  @override
  String get noEdits => 'No earlier versions';

  @override
  String get archiveResults => 'From the local archive';

  @override
  String get currentVersion => 'Current';

  @override
  String get deletedBadge => 'deleted';

  @override
  String get ghostHint => 'No read receipts, typing or online status';
}
