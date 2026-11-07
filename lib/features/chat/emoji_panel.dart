import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../domain/telegram_gateway.dart';
import '../../l10n/app_localizations.dart';
import 'sticker_picker.dart';

/// Inline panel under the input: Emoji (default) | Stickers | GIF.
/// Long-press an emoji for skin tones.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.gw,
    required this.controller,
    required this.onPick,
    this.onChanged,
  });

  final TelegramGateway gw;
  final TextEditingController controller;
  final void Function(StickerItem) onPick;
  final VoidCallback? onChanged;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = GlassScope.of(context).accent;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(l.tabEmoji)),
            ButtonSegment(value: 1, label: Text(l.tabStickers)),
            ButtonSegment(value: 2, label: const Text('GIF')),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
      ),
      Expanded(
        child: switch (_tab) {
          0 => EmojiPicker(
              textEditingController: widget.controller,
              onEmojiSelected: (_, _) => widget.onChanged?.call(),
              onBackspacePressed: widget.onChanged,
              config: Config(
                height: 260,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  backgroundColor: Colors.transparent,
                  columns: 8,
                  emojiSizeMax: 28,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: Colors.transparent,
                  indicatorColor: accent,
                  iconColorSelected: accent,
                  iconColor: Colors.white54,
                  backspaceColor: accent,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: GlassTokens.base,
                  buttonIconColor: Colors.white70,
                ),
              ),
            ),
          1 => StickerGrid(gw: widget.gw, onPick: widget.onPick),
          _ => StickerGrid(gw: widget.gw, onPick: widget.onPick, gifOnly: true),
        },
      ),
    ]);
  }
}
