import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/theme/glass.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
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
    _load();
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
          bio: _bio.text.trim());
      final name = _user.text.trim().replaceFirst('@', '');
      if (name != (_me?.username ?? '')) {
        if (!await gw.setUsername(name)) {
          _toast(l.usernameTaken);
          return;
        }
      }
      _toast(l.saved);
    } catch (e) {
      _toast(l.sendFailed('$e'));
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
      _toast(l.sendFailed('$e'));
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
              child: Text(l.cancelAction)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.logout)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(gatewayProvider).logOut();
    } catch (e) {
      _toast(l.sendFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final me = _me;
    final path = me?.avatar?.downloaded == true ? me!.avatar!.localPath : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(l.profile)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(
          child: GestureDetector(
            onTap: _photo,
            child: Stack(alignment: Alignment.bottomRight, children: [
              path != null && File(path).existsSync()
                  ? CircleAvatar(radius: 52, backgroundImage: FileImage(File(path)))
                  : AvatarCircle(
                      title: '${me?.firstName ?? ''}${me?.lastName ?? ''}', size: 104),
              const CircleAvatar(radius: 16, child: Icon(Icons.camera_alt, size: 16)),
            ]),
          ),
        ),
        TextButton(onPressed: _photo, child: Text(l.changePhoto)),
        TextField(controller: _first, decoration: InputDecoration(labelText: l.firstName)),
        const SizedBox(height: 12),
        TextField(controller: _last, decoration: InputDecoration(labelText: l.lastName)),
        const SizedBox(height: 12),
        TextField(
            controller: _bio,
            maxLength: 70,
            decoration: InputDecoration(labelText: l.bioLabel)),
        TextField(
            controller: _user,
            decoration: InputDecoration(labelText: l.username, prefixText: '@')),
        const SizedBox(height: 12),
        if ((me?.phone ?? '').isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: Text('+${me!.phone}'),
            subtitle: Text(l.phone,
                style: const TextStyle(color: GlassTokens.textSecondary)),
          ),
        const SizedBox(height: 8),
        FilledButton(
            onPressed: _busy ? null : _save, child: Text(l.vaultSave)),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout, color: GlassTokens.ringDanger),
          label: Text(l.logout,
              style: const TextStyle(color: GlassTokens.ringDanger)),
          onPressed: _logout,
        ),
      ]),
    );
  }
}
