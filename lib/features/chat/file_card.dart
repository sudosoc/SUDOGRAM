import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = b / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v < 10 ? 1 : 0)} ${units[i]}';
}

class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.file,
    required this.onDownload,
    required this.onCancel,
  });

  final Attachment file;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final Widget action;
    if (file.downloaded && file.localPath != null) {
      action = TextButton(
        onPressed: () => OpenFilex.open(file.localPath!),
        child: Text(l.openFile),
      );
    } else if (file.downloading) {
      action = IconButton(
        tooltip: l.cancel,
        icon: const Icon(Icons.close),
        onPressed: onCancel,
      );
    } else {
      action = IconButton(
        tooltip: l.download,
        icon: const Icon(Icons.download_rounded),
        onPressed: onDownload,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.insert_drive_file_outlined, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr),
                  Text(formatBytes(file.size),
                      style: const TextStyle(
                          fontSize: 11, color: GlassTokens.textTertiary)),
                ],
              ),
            ),
            action,
          ]),
          if (file.downloading)
            LinearProgressIndicator(value: file.progress == 0 ? null : file.progress),
        ],
      ),
    );
  }
}
