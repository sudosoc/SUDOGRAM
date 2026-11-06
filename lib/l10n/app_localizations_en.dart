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

  @override
  String get vault => 'Vault';

  @override
  String get vaultSetupTitle => 'Set up the vault';

  @override
  String get vaultRealPass => 'Your passcode';

  @override
  String get vaultDecoyPass => 'Decoy passcode (opens a harmless vault)';

  @override
  String get vaultEnter => 'Passcode';

  @override
  String get vaultWrong => 'Wrong passcode';

  @override
  String get vaultSave => 'Save';

  @override
  String get vaultAddTitle => 'Title';

  @override
  String get vaultAddBody => 'Content';

  @override
  String get vaultAdd => 'Add';

  @override
  String get vaultEmpty => 'Nothing here yet';

  @override
  String get vaultSamePass => 'The two passcodes must be different';

  @override
  String get intruderLog => 'Failed attempts';

  @override
  String get timeMachine => 'Time Machine';

  @override
  String get pickChat => 'Chat';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get contactLog => 'Contact changes';

  @override
  String get contactLogEmpty => 'No changes seen yet';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get tools => 'Tools';

  @override
  String get attachFile => 'Attach file';

  @override
  String get download => 'Download';

  @override
  String get openFile => 'Open';

  @override
  String get cancel => 'Cancel';

  @override
  String fileSplitNotice(String count) {
    return 'The file is over Telegram\'s limit and will be sent in $count parts';
  }

  @override
  String get sendingParts => 'Sending parts…';

  @override
  String get joinParts => 'Join file parts';

  @override
  String get joinPick => 'Pick all the parts and the .manifest.json file';

  @override
  String get joinDone => 'Joined successfully';

  @override
  String joinFailed(String reason) {
    return 'Could not join: $reason';
  }

  @override
  String get networkInspector => 'Network Inspector';

  @override
  String get connState => 'Connection';

  @override
  String get netEmpty => 'No requests yet';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get addToFolder => 'Folders';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get rename => 'Rename (only on this device)';

  @override
  String get aliasHint => 'Local name';

  @override
  String get clear => 'Clear';

  @override
  String get profiles => 'Profiles';

  @override
  String get saveProfile => 'Save current settings as a profile';

  @override
  String get profileName => 'Profile name';

  @override
  String forwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String get hiddenForward => 'a hidden account';

  @override
  String get rules => 'Rules';

  @override
  String get rulesEmpty => 'No rules yet';

  @override
  String get ruleAdd => 'Add rule';

  @override
  String get ruleName => 'Rule name';

  @override
  String get ruleChat => 'Chat name contains';

  @override
  String get ruleText => 'Message contains';

  @override
  String get ruleKind => 'Message type';

  @override
  String get anyKind => 'Any';

  @override
  String get ruleDo => 'Then';

  @override
  String get actPin => 'Pin chat';

  @override
  String get actHide => 'Hide chat';

  @override
  String get actGhostOn => 'Turn Ghost on for chat';

  @override
  String get actGhostOff => 'Turn Ghost off for chat';

  @override
  String get actFolder => 'Add to folder';

  @override
  String get ruleExport => 'Copy rule pack';

  @override
  String get ruleImport => 'Import rule pack';

  @override
  String get ruleImportHint => 'Paste a rule pack here';

  @override
  String get ruleCopied => 'Copied';

  @override
  String get ruleBad => 'Not a valid rule pack';

  @override
  String ruleImported(int count) {
    return 'Imported $count rules';
  }

  @override
  String get attachMedia => 'Photos and videos';
}
