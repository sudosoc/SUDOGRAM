import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../domain/models.dart';

/// Full-screen, zoomable profile photo. Shows the thumbnail instantly and
/// swaps in the full-size picture once it has downloaded.
class ProfilePhotoScreen extends ConsumerStatefulWidget {
  const ProfilePhotoScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.thumb,
  });
  final int chatId;
  final String title;
  final Attachment? thumb;

  @override
  ConsumerState<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends ConsumerState<ProfilePhotoScreen> {
  String? _big;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(gatewayProvider).bigProfilePhoto(widget.chatId).then((p) {
      if (!mounted) return;
      setState(() {
        _big = p;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.thumb?.localPath;
    final path = _big ?? thumb;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        title: Text(widget.title),
      ),
      body: Center(
        child: path != null && File(path).existsSync()
            ? Stack(alignment: Alignment.center, children: [
                InteractiveViewer(
                  maxScale: 6,
                  child: Image.file(File(path), fit: BoxFit.contain),
                ),
                if (_loading)
                  const Positioned(
                      bottom: 40, child: CircularProgressIndicator()),
              ])
            : _loading
                ? const CircularProgressIndicator()
                : Text(context.t('No profile photo', 'مفيش صورة بروفايل'),
                    style: const TextStyle(color: Colors.white70)),
      ),
    );
  }
}

void openProfilePhoto(BuildContext context, int chatId, String title,
        Attachment? thumb) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          ProfilePhotoScreen(chatId: chatId, title: title, thumb: thumb),
    ));
