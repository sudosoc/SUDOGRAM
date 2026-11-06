import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthStep step) async {
    final g = ref.read(gatewayProvider);
    final v = _c.text.trim();
    if (v.isEmpty) return;
    setState(() => _busy = true);
    try {
      switch (step) {
        case AuthStep.waitPhone:
          await g.submitPhone(v);
        case AuthStep.waitCode:
          await g.submitCode(v);
        case AuthStep.waitPassword:
          await g.submitPassword(v);
        default:
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _c.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authProvider).value ?? AuthState.initializing;
    final (title, hint) = switch (auth.step) {
      AuthStep.waitCode => (l.loginCodeTitle, l.loginCodeHint),
      AuthStep.waitPassword => (l.loginPasswordTitle, l.loginPasswordHint),
      _ => (l.loginPhoneTitle, l.loginPhoneHint),
    };
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassSurface(
              blur: true,
              radius: 28,
              shadow: true,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _c,
                    autofocus: true,
                    obscureText: auth.step == AuthStep.waitPassword,
                    keyboardType: auth.step == AuthStep.waitPassword
                        ? TextInputType.text
                        : TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(hintText: hint),
                    onSubmitted: (_) => _submit(auth.step),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 8),
                    Text(auth.error!,
                        style: const TextStyle(color: GlassTokens.ringDanger)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => _submit(auth.step),
                    child: Text(l.next),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
