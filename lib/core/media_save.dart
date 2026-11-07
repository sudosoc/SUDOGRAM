import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:gal/gal.dart';

import '../domain/models.dart';
import 'settings/app_settings.dart';

final Set<int> _autoSaved = {};

/// Saves a downloaded attachment: photos / videos go to the gallery, other
/// files through the system "save as" picker. Returns false when nothing
/// was saved.
Future<bool> saveToDevice(ChatMessage m) async {
  final f = m.file ?? m.thumb;
  final path = f?.localPath;
  if (f == null || path == null || !File(path).existsSync()) return false;
  switch (m.kind) {
    case MessageKind.photo:
      await Gal.putImage(path, album: 'SUDOGRAM');
      return true;
    case MessageKind.video:
      await Gal.putVideo(path, album: 'SUDOGRAM');
      return true;
    default:
      final name = f.name.isEmpty ? path.split('/').last : f.name;
      final r = await FilePicker.saveFile(
        fileName: name,
        bytes: await File(path).readAsBytes(),
      );
      return r != null;
  }
}

/// The rule "does this chat's incoming media go to the gallery?".
bool shouldAutoSave(AppSettings s, ChatMessage m) {
  if (m.outgoing) return false;
  final mode = (s.x['saveChatModes'] as Map?)?['${m.chatId}'];
  if (mode == 'never') return false;
  if (mode == 'always') return m.kind == MessageKind.photo || m.kind == MessageKind.video;
  return switch (m.kind) {
    MessageKind.photo => s.x['saveGalleryPhotos'] == true,
    MessageKind.video => s.x['saveGalleryVideos'] == true,
    _ => false,
  };
}

/// Called for every finished download; saves quietly when the rule allows.
Future<void> autoSaveIfWanted(AppSettings s, ChatMessage m) async {
  final id = m.file?.fileId;
  if (id == null || _autoSaved.contains(id) || !shouldAutoSave(s, m)) return;
  _autoSaved.add(id);
  try {
    await saveToDevice(m);
  } catch (_) {
    _autoSaved.remove(id);
  }
}
