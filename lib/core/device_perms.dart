import 'dart:async';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/telegram_gateway.dart';

/// Asks for location once; returns whether it is usable.
Future<bool> ensureLocationPermission() async {
  try {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  } catch (_) {
    return false;
  }
}

/// ISO country code (e.g. "EG") from the device position, or null.
Future<String?> detectIsoByLocation() async {
  try {
    if (!await ensureLocationPermission()) return null;
    final pos = await Geolocator.getLastKnownPosition() ??
        await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.low),
        ).timeout(const Duration(seconds: 8));
    final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude)
        .timeout(const Duration(seconds: 8));
    for (final m in marks) {
      final iso = m.isoCountryCode;
      if (iso != null && iso.isNotEmpty) return iso.toUpperCase();
    }
  } catch (_) {}
  return null;
}

Future<bool> ensureContactsPermission() async {
  try {
    final s = await FlutterContacts.permissions.request(PermissionType.read);
    return s == PermissionStatus.granted || s == PermissionStatus.limited;
  } catch (_) {
    return false;
  }
}

/// Imports the phone's address book into Telegram. Returns the number of
/// numbers sent, or -1 when permission was refused.
Future<int> syncPhoneContacts(TelegramGateway g) async {
  if (!await ensureContactsPermission()) return -1;
  final all = await FlutterContacts.getAll(
    properties: {ContactProperty.name, ContactProperty.phone},
  );
  final items = <Map<String, dynamic>>[];
  for (final c in all) {
    final name = (c.displayName ?? '').trim();
    for (final ph in c.phones) {
      final n = ph.number.replaceAll(RegExp(r'[^0-9+]'), '');
      if (n.length < 5) continue;
      items.add({
        '@type': 'contact',
        'phone_number': n,
        'first_name': (c.name?.first ?? '').isNotEmpty
            ? c.name!.first
            : (name.isEmpty ? n : name),
        'last_name': c.name?.last ?? '',
        'vcard': '',
        'user_id': 0,
      });
    }
  }
  for (var i = 0; i < items.length; i += 100) {
    await g.tdRaw({
      '@type': 'importContacts',
      'contacts': items.skip(i).take(100).toList(),
    }).timeout(const Duration(seconds: 40));
  }
  return items.length;
}
