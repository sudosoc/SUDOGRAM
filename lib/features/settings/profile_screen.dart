import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/ui/notice.dart';
import '../../core/ui/icon_styles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../core/i18n/tr.dart';
import '../../l10n/app_localizations.dart';

import 'package:flutter/services.dart';

import '../chat/avatar.dart';

/// Own profile: photo, name, bio, username, phone, log out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _bio = TextEditingController();
  final _user = TextEditingController();
  ProfileInfo? _me;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_first, _last, _bio, _user]) {
      c.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _load();
  }

  bool get _dirty {
    final m = _me;
    if (m == null) return false;
    return _first.text.trim() != m.firstName ||
        _last.text.trim() != m.lastName ||
        _bio.text.trim() != m.bio ||
        _user.text.trim().replaceFirst('@', '') != m.username;
  }

  Future<void> _load() async {
    final gw = ref.read(gatewayProvider);
    final me = await gw.me();
    if (me == null || !mounted) return;
    final a = me.avatar;
    if (a != null && !a.downloaded) gw.downloadFile(a.fileId);
    setState(() {
      _me = me;
      _first.text = me.firstName;
      _last.text = me.lastName;
      _bio.text = me.bio;
      _user.text = me.username;
    });
    if (a != null && !a.downloaded) {
      Future<void>.delayed(const Duration(seconds: 2), () async {
        final again = await gw.me();
        if (again != null && mounted) setState(() => _me = again);
      });
    }
  }

  void _toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final gw = ref.read(gatewayProvider);
    setState(() => _busy = true);
    try {
      await gw.updateProfile(
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
        bio: _bio.text.trim(),
      );
      final name = _user.text.trim().replaceFirst('@', '');
      if (name != (_me?.username ?? '')) {
        if (!await gw.setUsername(name)) {
          _toast(l.usernameTaken);
          return;
        }
      }
      _toast(l.saved);
      final fresh = await gw.me();
      if (fresh != null && mounted) setState(() => _me = fresh);
      ref.invalidate(meProvider);
    } catch (e) {
      _toast(friendlyError(e, ar: l.localeName == 'ar'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _photo() async {
    final l = AppLocalizations.of(context);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    try {
      await ref.read(gatewayProvider).setProfilePhoto(x.path);
      _toast(l.saved);
      await _load();
    } catch (e) {
      _toast(friendlyError(e, ar: l.localeName == 'ar'));
    }
  }

  Future<void> _logout() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.logout),
        content: Text(l.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gatewayProvider).logOut();
    } catch (e) {
      _toast(friendlyError(e, ar: l.localeName == 'ar'));
    }
  }

  Widget _info(IconData i, String v, String label) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SIcon(i),
    title: Text(v),
    subtitle: Text(
      label,
      style: const TextStyle(color: GlassTokens.textSecondary),
    ),
    onTap: () {
      Clipboard.setData(ClipboardData(text: v));
      _toast(context.t('Copied', 'اتنسخ'));
    },
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = _me;
    final path = me?.avatar?.downloaded == true ? me!.avatar!.localPath : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l.profile),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _photo,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  path != null && File(path).existsSync()
                      ? CircleAvatar(
                          radius: 52,
                          backgroundImage: FileImage(File(path)),
                        )
                      : AvatarCircle(
                          title: '${me?.firstName ?? ''}${me?.lastName ?? ''}',
                          size: 104,
                        ),
                  const CircleAvatar(
                    radius: 16,
                    child: SIcon(Icons.camera_alt, size: 16),
                  ),
                ],
              ),
            ),
          ),
          TextButton(onPressed: _photo, child: Text(l.changePhoto)),
          TextField(
            controller: _first,
            decoration: InputDecoration(labelText: l.firstName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _last,
            decoration: InputDecoration(labelText: l.lastName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLength: 70,
            decoration: InputDecoration(labelText: l.bioLabel),
          ),
          TextField(
            controller: _user,
            decoration: InputDecoration(labelText: l.username, prefixText: '@'),
          ),
          const SizedBox(height: 12),
          if ((me?.phone ?? '').isNotEmpty)
            _info(Icons.phone_outlined, '+${me!.phone}', l.phone),
          if (me != null)
            _info(Icons.tag, '${me.id}', context.t('User ID', 'رقم الحساب')),
          if ((me?.username ?? '').isNotEmpty)
            _info(
              Icons.link,
              't.me/${me!.username}',
              context.t('Profile link', 'لينك البروفايل'),
            ),
          if ((me?.bio ?? '').isNotEmpty)
            _info(Icons.info_outline, me!.bio, l.bioLabel),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => SizeTransition(
              sizeFactor: a,
              child: FadeTransition(opacity: a, child: c),
            ),
            child: _dirty
                ? Padding(
                    key: const ValueKey('save'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _load,
                            child: Text(context.t('Discard', 'تجاهل')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _save,
                            child: Text(l.vaultSave),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('nosave')),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const SIcon(Icons.logout, color: GlassTokens.ringDanger),
            label: Text(
              l.logout,
              style: const TextStyle(color: GlassTokens.ringDanger),
            ),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }
}
