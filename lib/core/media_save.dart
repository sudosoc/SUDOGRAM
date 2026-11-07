import 'dart:io';

import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../domain/models.dart';
import 'settings/app_settings.dart';

final Set<int> _autoSaved = {};

const _ch = MethodChannel('sudogram/window');

String _folderFor(ChatMessage m, String name) {
  switch (m.kind) {
    case MessageKind.photo:
      return 'Images';
    case MessageKind.video:
      return 'Videos';
    case MessageKind.voice:
      return 'Voice';
    default:
      final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (const {'mp3', 'm4a', 'ogg', 'opus', 'wav', 'flac', 'aac'}.contains(e)) return 'Audio';
      const docs = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv', 'rtf', 'odt'};
      return docs.contains(e) ? 'Documents' : 'Files';
  }
}

String _mimeFor(String name) {
  final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (e) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'ogg' || 'oga' || 'opus' => 'audio/ogg',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}

/// Saves a downloaded attachment silently into
/// Downloads/SUDOGRAM/(Images, Videos, Voice, Audio, Documents, Files).
/// Returns false when nothing was saved.
Future<bool> saveToDevice(ChatMessage m, {bool gallery = false}) async {
  final f = m.file ?? m.thumb;
  final path = f?.localPath;
  if (f == null || path == null || !File(path).existsSync()) return false;
  if (gallery) {
    if (m.kind == MessageKind.photo) {
      await Gal.putImage(path, album: 'SUDOGRAM');
      return true;
    }
    if (m.kind == MessageKind.video) {
      await Gal.putVideo(path, album: 'SUDOGRAM');
      return true;
    }
  }
  var name = f.name.isEmpty ? path.split('/').last : f.name;
  if (!name.contains('.') && path.contains('.')) name = '$name.${path.split('.').last}';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final dot = name.lastIndexOf('.');
  final unique = dot > 0
      ? '${name.substring(0, dot)}_$stamp${name.substring(dot)}'
      : '${name}_$stamp';
  await _ch.invokeMethod('saveFile', {
    'src': path,
    'dir': _folderFor(m, name),
    'name': unique,
    'mime': _mimeFor(name),
  });
  return true;
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
    await saveToDevice(m, gallery: true);
  } catch (_) {
    _autoSaved.remove(id);
  }
}
