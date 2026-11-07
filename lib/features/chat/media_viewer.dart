import 'dart:async';
import 'dart:io';
import '../../core/ui/icon_styles.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/media_save.dart';
import '../../core/ui/notice.dart';
import '../../domain/models.dart';
import 'info_screen.dart' show InfoJump;

/// Full-screen viewer for shared media with "Go to message" and "Pin".
/// Pops with an [InfoJump] when the user wants to jump to the message.
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.chatId, required this.message});
  final int chatId;
  final ChatMessage message;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerState();
}

class _MediaViewerState extends ConsumerState<MediaViewerScreen> {
  String? _path;
  bool _loading = true;
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final f = widget.message.file ?? widget.message.thumb;
    if (f == null) {
      setState(() => _loading = false);
      return;
    }
    final g = ref.read(gatewayProvider);
    String? path = f.downloaded ? f.localPath : null;
    if (path == null) {
      try {
        await g.downloadFile(f.fileId);
        for (var i = 0; i < 120 && path == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final r = await g.tdRaw({'@type': 'getFile', 'file_id': f.fileId});
          final l = r['local'] as Map?;
          if (l?['is_downloading_completed'] == true) {
            path = l!['path'] as String?;
          }
          if (!mounted) return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    if (path != null && widget.message.kind == MessageKind.video) {
      final c = VideoPlayerController.file(File(path));
      try {
        await c.initialize();
        await c.setLooping(true);
        await c.play();
        _video = c;
      } catch (_) {
        await c.dispose();
      }
    }
    if (!mounted) return;
    setState(() {
      _path = path;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _pin() async {
    try {
      await ref
          .read(gatewayProvider)
          .pinMessage(widget.chatId, widget.message.id, pin: true);
      if (mounted) {
        notice(context, context.t('Message pinned', 'تم تثبيت الرسالة'),
            kind: NoticeKind.success);
      }
    } catch (e) {
      if (mounted) {
        notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_video != null) {
      body = Center(
        child: GestureDetector(
          onTap: () => setState(() => _video!.value.isPlaying ? _video!.pause() : _video!.play()),
          child: AspectRatio(
            aspectRatio: _video!.value.aspectRatio,
            child: VideoPlayer(_video!),
          ),
        ),
      );
    } else if (_path != null && m.kind == MessageKind.photo) {
      body = InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.file(File(_path!))),
      );
    } else if (_path != null) {
      body = Center(
        child: FilledButton.icon(
          icon: const SIcon(Icons.open_in_new),
          label: Text(context.t('Open file', 'فتح الملف')),
          onPressed: () => OpenFilex.open(_path!),
        ),
      );
    } else {
      body = Center(child: Text(context.t('Could not load', 'تعذر التحميل')));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: Text('${m.time.day}/${m.time.month}/${m.time.year}'),
        actions: [
          if (_path != null)
            IconButton(
              tooltip: context.t('Save to device', 'حفظ على الجهاز'),
              icon: const SIcon(Icons.download),
              onPressed: () async {
                final f = m.file ?? m.thumb!;
                final copy = m.copyWith(
                  file: Attachment(
                    fileId: f.fileId,
                    name: f.name,
                    size: f.size,
                    localPath: _path,
                    downloaded: true,
                  ),
                );
                try {
                  final ok = await saveToDevice(copy);
                  if (context.mounted) {
                    notice(context, ok ? context.t('Saved', 'تم الحفظ') : context.t('Could not save', 'تعذر الحفظ'),
                        kind: ok ? NoticeKind.success : NoticeKind.error);
                  }
                } catch (e) {
                  if (context.mounted) {
                    notice(context, friendlyError(e, ar: context.isAr), kind: NoticeKind.error);
                  }
                }
              },
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const SIcon(Icons.chat_bubble_outline),
                label: Text(context.t('Go to message', 'الذهاب للرسالة')),
                onPressed: () => Navigator.of(context).pop(InfoJump(m.id)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const SIcon(Icons.push_pin_outlined),
                label: Text(context.t('Pin message', 'تثبيت الرسالة')),
                onPressed: _pin,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
