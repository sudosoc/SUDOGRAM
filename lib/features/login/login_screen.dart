import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import 'countries.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _codeFocus = FocusNode();
  Country _country = detectCountry();
  bool _busy = false;
  bool _showPass = false;
  String? _localError;
  AuthStep? _lastStep;
  bool _forcePhone = false;
  int _resendLeft = 0;
  Timer? _tick;

  AuthStep _view(AuthState a) =>
      _forcePhone &&
          (a.step == AuthStep.waitCode ||
              a.step == AuthStep.waitPassword ||
              a.step == AuthStep.waitQr)
      ? AuthStep.waitPhone
      : a.step;

  void _goBack(AuthState a) {
    if (_forcePhone) {
      setState(() => _forcePhone = false);
    } else if (a.step == AuthStep.waitCode ||
        a.step == AuthStep.waitPassword ||
        a.step == AuthStep.waitQr) {
      setState(() => _forcePhone = true);
    } else if (ref.read(settingsProvider).accounts.length > 1) {
      final slot = ref.read(settingsProvider).activeSlot;
      ref.read(settingsProvider.notifier).removeAccount(slot);
      wipeSlot(slot);
    } else {
      SystemNavigator.pop();
    }
  }

  bool _canGoBack(AuthState a) =>
      _forcePhone ||
      a.step == AuthStep.waitCode ||
      a.step == AuthStep.waitPassword ||
      a.step == AuthStep.waitQr ||
      ref.read(settingsProvider).accounts.length > 1;

  @override
  void dispose() {
    _tick?.cancel();
    _phone.dispose();
    _code.dispose();
    _pass.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPhone() async {
    final p = normalizePhone(_country, _phone.text);
    if (!p.valid) {
      setState(
        () => _localError = context.t(
          'Check the number: ${_country.en} numbers have ${_country.min}${_country.min == _country.max ? '' : '–${_country.max}'} digits (no need for the leading 0).',
          'راجع الرقم: أرقام ${_country.ar} من ${_country.min}${_country.min == _country.max ? '' : '–${_country.max}'} أرقام (من غير الصفر الأول).',
        ),
      );
      return;
    }
    setState(() {
      _localError = null;
      _forcePhone = false;
    });
    await _run(() => ref.read(gatewayProvider).submitPhone(p.e164));
  }

  Future<void> _sendCode(int len) async {
    final v = _code.text.trim();
    if (v.length != len || _busy) return;
    await _run(() => ref.read(gatewayProvider).submitCode(v));
    if (mounted) _code.clear();
  }

  Future<void> _sendPass() async {
    final v = _pass.text;
    if (v.isEmpty) return;
    await _run(() => ref.read(gatewayProvider).submitPassword(v));
  }

  void _pickCountry() async {
    final c = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CountrySheet(),
    );
    if (c != null) setState(() => _country = c);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider).value ?? AuthState.initializing;
    if (_lastStep != auth.step) {
      _lastStep = auth.step;
      _localError = null;
      _forcePhone = false;
      if (auth.step == AuthStep.waitCode) {
        _resendLeft = auth.resendIn;
        _tick?.cancel();
        _tick = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || _resendLeft <= 0) {
            t.cancel();
            return;
          }
          setState(() => _resendLeft--);
        });
      }
      if (auth.step == AuthStep.waitCode) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _codeFocus.requestFocus(),
        );
      }
    }
    final pal = _country.palette;
    final view = _view(auth);
    final bgColors = view == AuthStep.waitPhone || view == AuthStep.waitQr
        ? pal
        : [
            GlassTokens.accentDefault,
            GlassTokens.accentDefault.withValues(alpha: .4),
          ];
    final err = _localError ?? auth.error;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack(auth);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                for (final c
                    in (bgColors.length < 2
                        ? [...bgColors, bgColors.first]
                        : bgColors))
                  c.withValues(alpha: .28),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GlassSurface(
                  blur: true,
                  radius: 28,
                  shadow: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_canGoBack(auth))
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: Text(
                              _forcePhone
                                  ? context.t('Back', 'رجوع')
                                  : (auth.step == AuthStep.waitPhone ||
                                            auth.step == AuthStep.initializing
                                        ? context.t(
                                            'Back to my account',
                                            'رجوع لحسابي',
                                          )
                                        : context.t(
                                            'Change number / method',
                                            'تغيير الرقم / الطريقة',
                                          )),
                            ),
                            onPressed: () => _goBack(auth),
                          ),
                        ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          child: KeyedSubtree(
                            key: ValueKey(view),
                            child: switch (view) {
                              AuthStep.waitCode => _codeView(auth),
                              AuthStep.waitPassword => _passView(),
                              AuthStep.waitQr => _qrView(auth),
                              _ => _phoneView(),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // error banner shared by every step
        bottomNavigationBar: err == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    err,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GlassTokens.ringDanger),
                  ),
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------- phone

  Widget _phoneView() {
    final t = Theme.of(context).textTheme;
    final parsed = normalizePhone(_country, _phone.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('Sign in', 'تسجيل الدخول'), style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          context.t(
            'Enter your Telegram phone number.',
            'اكتب رقم تليجرام بتاعك.',
          ),
          style: const TextStyle(color: GlassTokens.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          textDirection: TextDirection.ltr,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickCountry,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      for (final c
                          in (_country.palette.length < 2
                              ? [..._country.palette, _country.palette.first]
                              : _country.palette))
                        c.withValues(alpha: .45),
                    ],
                  ),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 6),
                    Text(
                      '+${_country.dial}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(fontSize: 20, letterSpacing: 1.5),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  LengthLimitingTextInputFormatter(18),
                ],
                decoration: InputDecoration(
                  hintText: context.t('Phone number', 'رقم الهاتف'),
                ),
                onChanged: (_) => setState(() => _localError = null),
                onSubmitted: (_) => _sendPhone(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DigitTicker(
          text: _phone.text.isEmpty
              ? ''
              : '+${_country.dial} ${parsed.national}',
          ok: parsed.valid,
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _sendPhone,
          child: Text(context.t('Next', 'التالي')),
        ),
        const SizedBox(height: 6),
        if (ref.watch(settingsProvider).accounts.length > 1)
          TextButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: Text(
              context.t('Back to my other account', 'رجوع لحسابي التاني'),
            ),
            onPressed: () {
              final slot = ref.read(settingsProvider).activeSlot;
              ref.read(settingsProvider.notifier).removeAccount(slot);
              wipeSlot(slot);
            },
          ),
        TextButton.icon(
          icon: const Icon(Icons.qr_code_2),
          label: Text(context.t('Log in with QR code', 'الدخول بكود QR')),
          onPressed: _busy
              ? null
              : () {
                  setState(() => _forcePhone = false);
                  _run(() => ref.read(gatewayProvider).requestQrLogin());
                },
        ),
      ],
    );
  }

  // ------------------------------------------------------------ code

  String _kindName(String k) => switch (k) {
    'telegram' => context.t('a Telegram message', 'رسالة تليجرام'),
    'sms' => context.t('an SMS', 'رسالة SMS'),
    'call' => context.t('a phone call', 'مكالمة هاتفية'),
    'flash' || 'missed' => context.t('a missed call', 'مكالمة فائتة'),
    'fragment' => 'Fragment',
    _ => context.t('another method', 'طريقة تانية'),
  };

  String _codeHint(AuthState a) {
    final n = a.codeLength;
    return switch (a.codeType) {
      'telegram' => context.t(
        'We sent a $n-digit code to your Telegram account (open Telegram on another device).',
        'بعتنالك كود من $n أرقام على حساب تليجرام بتاعك (افتح تليجرام على جهازك التاني).',
      ),
      'sms' => context.t(
        'We sent a $n-digit code by SMS to your phone.',
        'بعتنالك كود من $n أرقام برسالة SMS على رقمك.',
      ),
      'call' => context.t(
        'We are calling you: listen for the $n-digit code.',
        'هنكلمك: اسمع الكود المكون من $n أرقام.',
      ),
      'flash' || 'missed' => context.t(
        'You will get a missed call: the last $n digits of its number are the code.',
        'هتجيلك مكالمة فائتة: آخر $n أرقام من رقمها هما الكود.',
      ),
      _ => context.t(
        'A $n-digit code was sent to you.',
        'اتبعتلك كود من $n أرقام.',
      ),
    };
  }

  Widget _codeView(AuthState auth) {
    final len = auth.codeLength;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('Enter the code', 'اكتب الكود'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.send_rounded,
              size: 18,
              color: GlassTokens.accentDefault,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _codeHint(auth),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: GlassTokens.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: () => _codeFocus.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _code,
                builder: (_, v, _) => Row(
                  textDirection: TextDirection.ltr,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < len; i++)
                      _CodeBox(
                        char: i < v.text.length ? v.text[i] : '',
                        active: i == v.text.length,
                      ),
                  ],
                ),
              ),
              // invisible field that actually receives the digits
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _code,
                    focusNode: _codeFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(len),
                    ],
                    onChanged: (v) {
                      setState(() {});
                      if (v.length == len) _sendCode(len);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_busy)
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          )
        else ...[
          if (auth.nextType != null)
            TextButton(
              onPressed: _resendLeft > 0
                  ? null
                  : () => _run(() => ref.read(gatewayProvider).resendCode()),
              child: Text(
                _resendLeft > 0
                    ? context.t(
                        'Send by ${_kindName(auth.nextType!)} in ${_resendLeft}s',
                        'إرسال عن طريق ${_kindName(auth.nextType!)} بعد $_resendLeft ث',
                      )
                    : context.t(
                        "Didn't get it? Send by ${_kindName(auth.nextType!)}",
                        'ماوصلش؟ ابعتها عن طريق ${_kindName(auth.nextType!)}',
                      ),
              ),
            ),
          Text(
            context.t(
              'It verifies automatically.',
              'بيتأكد لوحده أول ما تكمله.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: GlassTokens.textSecondary),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------- password

  Widget _passView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _pass,
          builder: (_, v, _) {
            final n = v.text.length;
            return Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: n == 0 ? 0 : 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  builder: (_, a, _) => Transform.scale(
                    scale: 1 + .25 * a,
                    child: Icon(
                      n == 0 ? Icons.lock_outline : Icons.lock_open_rounded,
                      size: 44,
                      color: Color.lerp(
                        GlassTokens.textSecondary,
                        GlassTokens.accentDefault,
                        a,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 14,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: [
                      for (var i = 0; i < n.clamp(0, 24); i++)
                        TweenAnimationBuilder<double>(
                          key: ValueKey('d$i'),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          builder: (_, a, _) => Container(
                            width: 8 * a,
                            height: 8 * a,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HSVColor.fromAHSV(
                                1,
                                (i * 27) % 360.0,
                                .55,
                                1,
                              ).toColor(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          context.t('Two-step verification', 'التحقق بخطوتين'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.t(
            'Your account has a cloud password.',
            'حسابك عليه باسورد سحابي.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: GlassTokens.textSecondary),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pass,
          autofocus: true,
          obscureText: !_showPass,
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            hintText: context.t('Password', 'الباسورد'),
            suffixIcon: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          onSubmitted: (_) => _sendPass(),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _sendPass,
          child: Text(context.t('Next', 'التالي')),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- QR

  Widget _qrView(AuthState auth) {
    final link = auth.qrLink ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('Log in with QR', 'الدخول بـ QR'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        if (link.isEmpty)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(data: link, size: 200),
            ),
          ),
        const SizedBox(height: 14),
        Text(
          context.t(
            '1. Open Telegram on your other device\n2. Settings → Devices → Link Desktop Device\n3. Point it at this code',
            '١. افتح تليجرام على جهازك التاني\n٢. الإعدادات ← الأجهزة ← ربط جهاز\n٣. وجّه الكاميرا على الكود',
          ),
          style: const TextStyle(color: GlassTokens.textSecondary),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.phone_android),
          label: Text(
            context.t('Use phone number instead', 'استخدم رقم الهاتف'),
          ),
          onPressed: () => setState(() => _forcePhone = true),
        ),
      ],
    );
  }
}

/// One animated cell of the verification code.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char, required this.active});
  final String char;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 46,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: char.isEmpty ? .05 : .14),
        border: Border.all(
          color: active
              ? GlassTokens.accentDefault
              : (char.isEmpty ? Colors.white24 : Colors.white54),
          width: active ? 2 : 1,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (c, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: a, child: c),
        ),
        child: Text(
          char,
          key: ValueKey(char),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Shows the normalised number with every character popping in.
class _DigitTicker extends StatelessWidget {
  const _DigitTicker({required this.text, required this.ok});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        textDirection: TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < text.length; i++)
            TweenAnimationBuilder<double>(
              key: ValueKey('$i${text[i]}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (_, a, _) => Opacity(
                opacity: a.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - a)),
                  child: Text(
                    text[i],
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ok
                          ? GlassTokens.accentDefault
                          : GlassTokens.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          if (ok)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(
                Icons.check_circle,
                size: 18,
                color: GlassTokens.accentDefault,
              ),
            ),
        ],
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();
  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().replaceFirst('+', '');
    final list = [
      for (final c in countries)
        if (q.isEmpty ||
            c.en.toLowerCase().contains(q) ||
            c.ar.contains(q) ||
            c.dial.startsWith(q) ||
            c.iso.toLowerCase() == q)
          c,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      maxChildSize: .95,
      builder: (_, sc) => GlassSurface(
        radius: 24,
        blur: true,
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: context.t(
                    'Search country or code',
                    'ابحث عن دولة أو كود',
                  ),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(context.isAr ? c.ar : c.en),
                    trailing: Text(
                      '+${c.dial}',
                      style: const TextStyle(color: GlassTokens.textSecondary),
                    ),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
