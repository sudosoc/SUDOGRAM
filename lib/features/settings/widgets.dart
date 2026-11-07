import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ui/icon_styles.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';

/// Small explanatory line under an option.
class SHint extends StatelessWidget {
  const SHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, height: 1.3, color: GlassTokens.textSecondary));
}

/// Glass card with an optional heading, used by every settings tab.
class SGroup extends StatelessWidget {
  const SGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(title!,
                  style: const TextStyle(
                      color: GlassTokens.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          GlassSurface(radius: 20, child: Column(children: children)),
        ]),
      );
}

/// A page whose body is a list of cards.
class SPage extends StatelessWidget {
  const SPage({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title)),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
            children: children),
      );
}

class STab {
  const STab(this.label, this.icon, this.build, {this.preview});
  final String label;
  final IconData icon;
  final WidgetBuilder build;

  /// Pinned above the scrolling options so changes show up live.
  final WidgetBuilder? preview;
}

/// Page with a tab bar; each tab scrolls on its own.
class STabbedPage extends StatelessWidget {
  const STabbedPage({super.key, required this.title, required this.tabs});
  final String title;
  final List<STab> tabs;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(title),
            bottom: TabBar(
              isScrollable: tabs.length > 3,
              tabs: [
                for (final t in tabs)
                  Tab(icon: SIcon(t.icon, size: 20), text: t.label, height: 56),
              ],
            ),
          ),
          body: TabBarView(children: [
            for (final t in tabs)
              Column(children: [
                if (t.preview != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Builder(builder: t.preview!),
                  ),
                Expanded(
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                      children: [Builder(builder: t.build)]),
                ),
              ]),
          ]),
        ),
      );
}

/// Chip-style choice stored in `x[key]`.
class ChoiceRow extends ConsumerWidget {
  const ChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.keyName,
    required this.current,
    required this.options,
    this.hint,
  });
  final IconData icon;
  final String title;
  final String keyName;
  final String current;
  final String? hint;

  /// value → label
  final Map<String, String> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: SIcon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hint != null) SHint(hint!),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final e in options.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: current == e.key,
                  onSelected: (_) =>
                      ref.read(settingsProvider.notifier).setX(keyName, e.key),
                ),
            ]),
          ]),
        ),
      );
}

class SwitchRow extends ConsumerWidget {
  const SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.keyName,
    required this.value,
    this.subtitle,
    this.hint,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? hint;
  final String keyName;
  final bool value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = subtitle ?? hint;
    return SwitchListTile(
      secondary: SIcon(icon),
      title: Text(title),
      subtitle: h == null ? null : SHint(h),
      value: value,
      onChanged: (v) => ref.read(settingsProvider.notifier).setX(keyName, v),
    );
  }
}

class SliderRow extends ConsumerWidget {
  const SliderRow({
    super.key,
    required this.icon,
    required this.title,
    required this.keyName,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.fmt,
    this.hint,
    this.asInt = false,
  });
  final IconData icon;
  final String title;
  final String keyName;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? fmt;
  final String? hint;

  /// Store an int instead of a double.
  final bool asInt;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: SIcon(icon),
        title: Text(
            '$title  ${fmt != null ? fmt!(value) : value.toStringAsFixed(1)}'),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hint != null) SHint(hint!),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (v) => ref
                .read(settingsProvider.notifier)
                .setX(keyName, asInt ? v.round() : v),
          ),
        ]),
      );
}
