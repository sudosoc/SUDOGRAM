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
  String get pin => 'Pin message';

  @override
  String get unpin => 'Unpin message';

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

  @override
  String get you => 'You';

  @override
  String get typing => 'typing…';

  @override
  String get online => 'online';

  @override
  String get seenRecently => 'last seen recently';

  @override
  String get seenWeek => 'last seen within a week';

  @override
  String get seenMonth => 'last seen within a month';

  @override
  String seenAt(String time) {
    return 'last seen $time';
  }

  @override
  String get groupLabel => 'group';

  @override
  String get channelLabel => 'channel';

  @override
  String get reply => 'Reply';

  @override
  String get copy => 'Copy';

  @override
  String get edit => 'Edit';

  @override
  String get forward => 'Forward';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get deleteForAll => 'Delete for everyone';

  @override
  String get deleteTitle => 'Delete message?';

  @override
  String get cantPost => 'You can\'t post here';

  @override
  String get forwardTo => 'Forward to';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get editingMessage => 'Editing message';

  @override
  String get replyingTo => 'Replying to';

  @override
  String get copied => 'Copied';

  @override
  String get muted => 'Muted';

  @override
  String get photoLoading => 'Loading…';

  @override
  String get mediaMessage => 'Message';

  @override
  String get delete => 'Delete';

  @override
  String get contacts => 'Contacts';

  @override
  String get savedMessages => 'Saved Messages';

  @override
  String get searchInChat => 'Search in chat';

  @override
  String get pinnedMessage => 'Pinned message';

  @override
  String get noResults => 'No results';

  @override
  String get newChat => 'New chat';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsHint =>
      'Stay connected in the background and show new messages';

  @override
  String get keepConnectedText => 'Connected';

  @override
  String get newMessage => 'New message';

  @override
  String get info => 'Info';

  @override
  String get username => 'Username';

  @override
  String get phone => 'Phone';

  @override
  String get about => 'About';

  @override
  String membersCount(String n) {
    return '$n members';
  }

  @override
  String get react => 'React';

  @override
  String get archive => 'Archive';

  @override
  String get archiveChat => 'Archive';

  @override
  String get unarchiveChat => 'Unarchive';

  @override
  String get draft => 'Draft';

  @override
  String get devices => 'Devices';

  @override
  String get thisDevice => 'This device';

  @override
  String get terminate => 'Log out';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get create => 'Create';

  @override
  String get pollClosed => 'Final results';

  @override
  String votesCount(String n) {
    return '$n votes';
  }

  @override
  String get privacy => 'Privacy';

  @override
  String get privPhone => 'Who can see my phone number';

  @override
  String get privSeen => 'Who can see my last seen';

  @override
  String get privPhoto => 'Who can see my profile photo';

  @override
  String get privCalls => 'Who can call me';

  @override
  String get privInvites => 'Who can add me to groups';

  @override
  String get privForwards => 'Link to my account on forwarded messages';

  @override
  String get everybody => 'Everybody';

  @override
  String get myContacts => 'My contacts';

  @override
  String get nobody => 'Nobody';

  @override
  String get secretChat => 'Start secret chat';

  @override
  String get secretNote => 'End-to-end encrypted. Only on this device.';

  @override
  String get selfDestruct => 'Self-destruct timer';

  @override
  String get timerOff => 'Off';

  @override
  String get timer1m => '1 minute';

  @override
  String get timer1h => '1 hour';

  @override
  String get timer1d => '1 day';

  @override
  String get backgroundTitle => 'Allow background activity';

  @override
  String get backgroundBody =>
      'To show new messages when the app is closed, SUDOGRAM must keep running in the background. Please allow it on the next screen.';

  @override
  String get later => 'Later';

  @override
  String get allow => 'Allow';

  @override
  String get profile => 'Profile';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get bioLabel => 'Bio';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm =>
      'Log out of this account? Your local archive stays on this device.';

  @override
  String get saved => 'Saved';

  @override
  String get usernameTaken => 'Username is taken or invalid';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get leaveChat => 'Leave and delete';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String get gallery => 'Gallery';

  @override
  String get cameraPhoto => 'Take photo';

  @override
  String get cameraVideo => 'Record video';

  @override
  String get fileLabel => 'File';

  @override
  String sendFailed(String e) {
    return 'Couldn\'t send: $e';
  }

  @override
  String get recording => 'Recording…';

  @override
  String get micDenied => 'Microphone permission denied';

  @override
  String get micUnsupported => 'This phone can\'t record voice notes in Opus';

  @override
  String get confirm => 'Are you sure?';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get hiddenChatsTitle => 'Hidden chats';

  @override
  String get noHiddenChats =>
      'No hidden chats yet. Long-press any chat and choose Hide.';

  @override
  String get joinByLink => 'Join by invite link';

  @override
  String get pasteLink => 'Paste invite link';

  @override
  String get join => 'Join';

  @override
  String get blocked => 'Blocked users';

  @override
  String get noBlocked => 'No blocked users';

  @override
  String get twoStep => 'Two-step verification';

  @override
  String get twoStepOn => 'On';

  @override
  String get twoStepOff => 'Off';

  @override
  String get oldPassword => 'Current password';

  @override
  String get newPassword => 'New password (empty = turn off)';

  @override
  String get passwordHint => 'Hint';

  @override
  String get passwordChanged => 'Password updated';

  @override
  String get passwordFailed => 'Wrong password or rejected';

  @override
  String get stickers => 'Stickers';

  @override
  String get members => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get removeMember => 'Remove';

  @override
  String get wallpaper => 'Chat background';

  @override
  String get telegramResults => 'Telegram results';

  @override
  String get done => 'Done';

  @override
  String get createPoll => 'Poll';

  @override
  String get pollQuestion => 'Question';

  @override
  String pollOption(String n) {
    return 'Option $n';
  }

  @override
  String get pollMultiple => 'Allow multiple answers';

  @override
  String get location => 'Location';

  @override
  String get contactLabel => 'Contact';

  @override
  String get gif => 'GIF';

  @override
  String get locationDenied => 'Location permission denied';

  @override
  String get send2 => 'Send';
}
