import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../domain/models.dart';
import 'rules.dart';

const _kRules = 'rules_v1';

class RulesController extends Notifier<List<Rule>> {
  @override
  List<Rule> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kRules);
    if (raw == null) return const [];
    try {
      return Rule.decodeAll(raw);
    } catch (_) {
      return const [];
    }
  }

  void _set(List<Rule> next) {
    state = next;
    ref.read(sharedPreferencesProvider).setString(_kRules, Rule.encodeAll(next));
  }

  void add(Rule r) => _set([...state, r]);
  void remove(String id) => _set([for (final r in state) if (r.id != id) r]);
  void toggle(String id) => _set([
        for (final r in state) r.id == id ? r.copyWith(enabled: !r.enabled) : r
      ]);

  /// Adds the rules of a pack, giving them fresh ids. Returns how many.
  int import(List<Rule> rules) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var i = 0;
    _set([
      ...state,
      for (final r in rules)
        Rule(
          id: '${stamp}_${i++}',
          name: r.name,
          action: r.action,
          enabled: r.enabled,
          chatContains: r.chatContains,
          textContains: r.textContains,
          kind: r.kind,
          folder: r.folder,
        ),
    ]);
    return rules.length;
  }
}

final rulesProvider =
    NotifierProvider<RulesController, List<Rule>>(RulesController.new);

/// Watches the chat list and applies matching rules to new messages.
final rulesRunnerProvider = Provider<void>((ref) {
  var previous = <int, ChatSummary>{};
  ref.listen<AsyncValue<List<ChatSummary>>>(chatsProvider, (_, next) {
    final chats = next.value;
    if (chats == null) return;
    final rules = ref.read(rulesProvider);
    final s = ref.read(settingsProvider.notifier);
    for (final hit in findHits(rules, previous, chats)) {
      final st = ref.read(settingsProvider);
      switch (hit.rule.action) {
        case RuleAction.pin:
          if (!st.pinned.contains(hit.chatId)) s.togglePin(hit.chatId);
        case RuleAction.hide:
          s.setHidden(hit.chatId, true);
        case RuleAction.ghostOn:
          s.setGhostOverride(hit.chatId, true);
        case RuleAction.ghostOff:
          s.setGhostOverride(hit.chatId, false);
        case RuleAction.addToFolder:
          final f = hit.rule.folder;
          if (f.isNotEmpty && !(st.folders[f]?.contains(hit.chatId) ?? false)) {
            s.toggleInFolder(f, hit.chatId);
          }
      }
    }
    previous = {for (final c in chats) c.id: c};
  });
});
