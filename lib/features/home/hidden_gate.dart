import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../l10n/app_localizations.dart';
import 'hidden_screen.dart';

String hashPin(String salt, String code) =>
    sha256.convert(utf8.encode('$salt:$code')).toString();

bool verifyPin(AppSettings s, String code) =>
    s.hasHiddenPin && hashPin(s.hiddenPinSalt, code) == s.hiddenPinHash;

String newSalt() {
  final r = Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) r.nextInt(256)]);
}

/// Asks for whatever protects the hidden chats (system biometrics and / or
/// the own passcode). Returns true when the user got through. Does not
/// change the vault state by itself.
Future<bool> requireHiddenAuth(BuildContext context, WidgetRef ref) async {
  final s = ref.read(settingsProvider);
  if (!s.hiddenAuth && !s.hasHiddenPin) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
            backgroundColor: GlassTokens.base,
            body: HiddenGateView(
              onUnlocked: () => Navigator.of(ctx).pop(true),
              onCancel: () => Navigator.of(ctx).pop(false),
            ),
          )));
  return ok ?? false;
}

/// Entry point used by every "open hidden chats" gesture.
Future<void> openHiddenChats(BuildContext context, WidgetRef ref) async {
  final nav = Navigator.of(context);
  final vault = ref.read(vaultUnlockProvider.notifier);
  if (!ref.read(vaultUnlockProvider)) {
    if (!await requireHiddenAuth(context, ref)) return;
    vault.open();
  }
  await nav.push(
      MaterialPageRoute<void>(builder: (_) => const HiddenChatsScreen()));
}

/// The lock screen: biometrics first (when enabled), then the own passcode
/// (digits with a keypad, or a word).
class HiddenGateView extends ConsumerStatefulWidget {
  const HiddenGateView(
      {super.key, required this.onUnlocked, required this.onCancel});

  final VoidCallback onUnlocked;
  final VoidCallback onCancel;

  @override
  ConsumerState<HiddenGateView> createState() => _HiddenGateViewState();
}

class _HiddenGateViewState extends ConsumerState<HiddenGateView> {
  bool _deviceDone = false;
  bool _busy = false;
  String _code = '';
  int _fails = 0;
  DateTime _lockedUntil = DateTime(2000);
  final _text = TextEditingController();
  bool _error = false;

  AppSettings get _s => ref.read(settingsProvider);

  @override
  void initState() {
    super.initState();
    _deviceDone = !_s.hiddenAuth;
    WidgetsBinding.instance.addPostFrameCallback((_) => _next());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!mounted) return;
    if (!_deviceDone) {
      await _device();
      return;
    }
    if (!_s.hasHiddenPin) widget.onUnlocked();
  }

  Future<void> _device() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    final ok = await ref
        .read(vaultUnlockProvider.notifier)
        .deviceAuth(l.vaultAuthReason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _deviceDone = ok;
    });
    if (ok) _next();
  }

  void _submit(String code) {
    if (DateTime.now().isBefore(_lockedUntil)) return;
    if (verifyPin(_s, code)) {
      widget.onUnlocked();
      return;
    }
    HapticFeedback.heavyImpact();
    _fails++;
    setState(() {
      _code = '';
      _text.clear();
      _error = true;
      if (_fails >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _fails = 0;
      }
    });
  }

  void _key(String k, int len) {
    if (DateTime.now().isBefore(_lockedUntil)) return;
    setState(() {
      _error = false;
      if (k == '<') {
        if (_code.isNotEmpty) _code = _code.substring(0, _code.length - 1);
      } else if (_code.length < len) {
        _code += k;
      }
    });
    if (_code.length == len) _submit(_code);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider);
    final locked = DateTime.now().isBefore(_lockedUntil);
    final kind = s.hiddenPinKind;
    final digits = kind != 'text';
    final len = int.tryParse(kind) ?? 4;
    final showCode = _deviceDone && s.hasHiddenPin;

    Widget keypad() {
      Widget key(String k) => Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: 72,
              height: 56,
              child: k.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _key(k, len),
                      style: TextButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18))),
                      child: k == '<'
                          ? const Icon(Icons.backspace_outlined)
                          : Text(k, style: const TextStyle(fontSize: 22)),
                    ),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(mainAxisSize: MainAxisSize.min, children: [for (final k in row) key(k)]),
      ]);
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48, color: GlassTokens.ghost),
            const SizedBox(height: 12),
            Text(l.hiddenChatsTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            if (!showCode) ...[
              if (_busy) const CircularProgressIndicator(),
              if (!_busy)
                FilledButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l.unlock),
                  onPressed: _device,
                ),
            ] else ...[
              Text(locked ? l.gateTooMany : (_error ? l.gateWrong : l.gateEnterCode),
                  style: TextStyle(
                      color: _error || locked
                          ? GlassTokens.ringDanger
                          : GlassTokens.textSecondary)),
              const SizedBox(height: 14),
              if (digits) ...[
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < len; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _code.length ? Colors.white : Colors.transparent,
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                ]),
                const SizedBox(height: 18),
                keypad(),
              ] else
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _text,
                    obscureText: true,
                    autofocus: true,
                    enabled: !locked,
                    textAlign: TextAlign.center,
                    onSubmitted: _submit,
                    decoration: InputDecoration(hintText: l.gateEnterCode),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            TextButton(onPressed: widget.onCancel, child: Text(l.cancelAction)),
          ]),
        ),
      ),
    );
  }
}
