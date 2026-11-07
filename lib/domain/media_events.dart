import 'models.dart';

/// Lets the app layer react when a received photo / video finished
/// downloading (used for "save to gallery automatically").
class MediaEvents {
  static void Function(ChatMessage m)? onDownloaded;
}
