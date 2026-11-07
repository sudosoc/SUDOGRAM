import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/i18n/tr.dart';
import '../../core/live_location.dart';
import '../../core/theme/glass.dart';
import '../../core/ui/icon_styles.dart';
import '../../core/ui/notice.dart';
import '../../domain/models.dart';

/// Map card for a location message (tiles load when online; a styled grid
/// is shown otherwise). Live locations get a badge and a stop button.
class LocationCard extends ConsumerWidget {
  const LocationCard({super.key, required this.m});
  final ChatMessage m;

  static const _w = 240.0, _h = 150.0, _z = 16;

  Widget _map(LocationData loc) {
    final n = math.pow(2, _z).toDouble();
    final latR = loc.lat * math.pi / 180;
    final px = (loc.lon + 180) / 360 * n * 256;
    final py = (1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n * 256;
    final left = px - _w / 2, top = py - _h / 2;
    final tiles = <Widget>[];
    for (var tx = (left / 256).floor(); tx <= ((left + _w) / 256).floor(); tx++) {
      for (var ty = (top / 256).floor(); ty <= ((top + _h) / 256).floor(); ty++) {
        tiles.add(Positioned(
          left: tx * 256 - left,
          top: ty * 256 - top,
          width: 256,
          height: 256,
          child: Image.network(
            'https://tile.openstreetmap.org/$_z/$tx/$ty.png',
            headers: const {'User-Agent': 'SUDOGRAM personal client'},
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ));
      }
    }
    return ColorFiltered(
      // dark, slightly blue map to match the glass look
      colorFilter: const ColorFilter.matrix([
        -0.6, 0, 0, 0, 255 * 0.78,
        0, -0.6, 0, 0, 255 * 0.82,
        0, 0, -0.7, 0, 255 * 0.95,
        0, 0, 0, 1, 0,
      ]),
      child: Stack(clipBehavior: Clip.hardEdge, children: tiles),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = m.loc ?? parseLocation(m.text);
    if (loc == null) return const SizedBox.shrink();
    final accent = GlassScope.of(context).accent;
    final ar = context.isAr;
    return GestureDetector(
      onTap: () => _openWith(context, loc),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: _w,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: _h,
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent.withValues(alpha: 0.35), const Color(0xFF14141C)],
                    ),
                  ),
                ),
                CustomPaint(painter: _GridPainter()),
                _map(loc),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Icon(Icons.location_on, size: 40, color: accent, shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ]),
                  ),
                ),
                if (loc.live)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF453A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.sensors, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(ar ? 'مباشر' : 'LIVE',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
              ]),
            ),
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(children: [
                SIcon(Icons.place_outlined, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${loc.lat.toStringAsFixed(5)}, ${loc.lon.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: GlassTokens.textSecondary),
                  ),
                ),
                if (loc.live && m.outgoing)
                  InkWell(
                    onTap: () async {
                      try {
                        await LiveLocation.stop(m.chatId);
                        await ref.read(gatewayProvider).tdRaw({
                          '@type': 'editMessageLiveLocation',
                          'chat_id': m.chatId,
                          'message_id': m.id,
                          'location': null,
                          'live_period': 0,
                          'heading': 0,
                          'proximity_alert_radius': 0,
                        });
                        if (context.mounted) {
                          notice(context, context.t('Live location stopped', 'تم إيقاف الموقع المباشر'),
                              kind: NoticeKind.success);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          notice(context, friendlyError(e, ar: ar), kind: NoticeKind.error);
                        }
                      }
                    },
                    child: Text(context.t('Stop', 'إيقاف'),
                        style: const TextStyle(
                            color: Color(0xFFFF453A), fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> _go(BuildContext c, String url) async {
  Navigator.of(c).pop();
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && c.mounted) {
    notice(c, c.t('No app could open this', 'مفيش تطبيق قدر يفتحه'), kind: NoticeKind.error);
  }
}

/// WhatsApp-style "open this place in…" sheet.
void _openWith(BuildContext context, LocationData l) {
  final ll = '${l.lat},${l.lon}';
  Widget row(IconData i, String t, VoidCallback f) => ListTile(
        leading: SIcon(i),
        title: Text(t),
        onTap: f,
      );
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text(context.t('Open location in…', 'فتح الموقع في…'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(ll),
          ),
          row(Icons.map_outlined, 'Google Maps',
              () => _go(sheet, 'https://www.google.com/maps/search/?api=1&query=$ll')),
          row(Icons.navigation_outlined, 'Waze',
              () => _go(sheet, 'https://waze.com/ul?ll=$ll&navigate=yes')),
          row(Icons.local_taxi_outlined, 'Uber',
              () => _go(sheet,
                  'https://m.uber.com/ul/?action=setPickup&pickup=my_location&dropoff[latitude]=${l.lat}&dropoff[longitude]=${l.lon}')),
          row(Icons.apps, context.t('Other map apps…', 'تطبيقات خرائط تانية…'),
              () => _go(sheet, 'geo:$ll?q=$ll')),
          row(Icons.public, 'OpenStreetMap',
              () => _go(sheet, 'https://www.openstreetmap.org/?mlat=${l.lat}&mlon=${l.lon}#map=17/${l.lat}/${l.lon}')),
          row(Icons.copy, context.t('Copy coordinates', 'نسخ الإحداثيات'), () {
            Clipboard.setData(ClipboardData(text: ll));
            Navigator.of(sheet).pop();
            notice(context, context.t('Copied', 'تم النسخ'), kind: NoticeKind.success);
          }),
        ]),
      ),
    ),
  );
}

/// Reads "📍 https://maps.google.com/?q=lat,lon" (archived copies).
LocationData? parseLocation(String text) {
  final r = RegExp(r'q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(text);
  if (r == null) return null;
  return LocationData(double.parse(r.group(1)!), double.parse(r.group(2)!));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    for (double y = 0; y < s.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
