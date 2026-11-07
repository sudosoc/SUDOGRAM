import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../domain/telegram_gateway.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet with the user's installed sticker sets (static previews).
Future<void> showStickerPicker(BuildContext context, TelegramGateway gw,
    {required void Function(StickerItem) onPick}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(12),
      child: GlassSurface(
        blur: true,
        radius: 24,
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: StickerGrid(gw: gw, onPick: (s) {
            Navigator.of(context).pop();
            onPick(s);
          }),
        ),
      ),
    ),
  );
}

/// Sticker sets (or only GIFs when [gifOnly]) as a grid with set tabs.
class StickerGrid extends StatefulWidget {
  const StickerGrid(
      {super.key, required this.gw, required this.onPick, this.gifOnly = false});
  final TelegramGateway gw;
  final void Function(StickerItem) onPick;
  final bool gifOnly;

  @override
  State<StickerGrid> createState() => _PickerState();
}

class _PickerState extends State<StickerGrid> {
  late final Future<List<StickerSetInfo>> _sets = widget.gifOnly
      ? Future.value([const StickerSetInfo(-1, 'GIF')])
      : widget.gw.stickerSets();
  int _sel = 0;
  Future<List<StickerItem>>? _items;
  List<StickerSetInfo> _list = const [];

  Future<List<StickerItem>> _itemsFor(StickerSetInfo s) =>
      s.id == -1 ? widget.gw.savedGifs() : widget.gw.stickerSetItems(s.id);

  void _load(int i) {
    _sel = i;
    _items = _itemsFor(_list[i]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<StickerSetInfo>>(
      future: _sets,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: Text(l.connecting));
        }
        _list = snap.data ?? const [];
        if (_list.isEmpty) return Center(child: Text(l.noResults));
        _items ??= _itemsFor(_list.first);
        return Column(children: [
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var i = 0; i < _list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(_list[i].title, maxLines: 1),
                    selected: i == _sel,
                    onSelected: (_) => setState(() => _load(i)),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<StickerItem>>(
              future: _items,
              builder: (_, s) {
                final items = s.data ?? const <StickerItem>[];
                if (s.connectionState != ConnectionState.done) {
                  return Center(child: Text(l.connecting));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4),
                  itemCount: items.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => widget.onPick(items[i]),
                    child: _Thumb(gw: widget.gw, item: items[i]),
                  ),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.gw, required this.item});
  final TelegramGateway gw;
  final StickerItem item;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: gw.fetchFile(item.thumbFileId),
      builder: (_, snap) {
        final p = snap.data;
        if (p == null) {
          return Center(
              child: Text(item.emoji, style: const TextStyle(fontSize: 28)));
        }
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Image.file(File(p),
              errorBuilder: (_, _, _) => Center(child: Text(item.emoji))),
        );
      },
    );
  }
}
