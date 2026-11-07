import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/icon_styles.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/i18n/tr.dart';
import '../../core/theme/glass.dart';

/// Pulls a Telegram login link out of arbitrary scanned text.
String? extractLoginLink(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'tg://login\?token=[A-Za-z0-9_\-=]+').firstMatch(raw);
  if (m != null) return m.group(0);
  final t = RegExp(r'https?://t\.me/login/[A-Za-z0-9_\-=]+').firstMatch(raw);
  return t?.group(0);
}

/// Camera scanner that returns the first QR text it sees.
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _ctl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _finish(String? v) {
    if (_done || v == null || v.isEmpty) return;
    _done = true;
    Navigator.pop(context, v);
  }

  Future<void> _fromGallery() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f == null) return;
    final cap = await _ctl.analyzeImage(f.path);
    final v = cap?.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (!mounted) return;
    if (v == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.t('No QR code found in that image',
              'مفيش كود QR في الصورة دي'))));
      return;
    }
    _finish(v);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.t('Scan QR code', 'مسح كود QR')),
          actions: [
            IconButton(
              icon: const SIcon(Icons.flashlight_on_outlined),
              onPressed: () => _ctl.toggleTorch(),
            ),
            IconButton(
              icon: const SIcon(Icons.cameraswitch_outlined),
              onPressed: () => _ctl.switchCamera(),
            ),
          ],
        ),
        body: Stack(children: [
          MobileScanner(
            controller: _ctl,
            onDetect: (c) => _finish(
                c.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull),
            errorBuilder: (c, e) => Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.t('Camera unavailable. Allow camera access or pick an image.',
                    'الكاميرا مش متاحة. اسمح بالوصول للكاميرا أو اختار صورة.'),
                textAlign: TextAlign.center,
              ),
            )),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.tonalIcon(
                icon: const SIcon(Icons.photo_library_outlined),
                label: Text(context.t('Pick from gallery', 'اختار من المعرض')),
                onPressed: _fromGallery,
              ),
            ),
          ),
        ]),
      );
}

/// Shows [data] as a big QR with copy.
Future<void> showQrSheet(BuildContext context, String title, String data) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => GlassSurface(
        radius: 24,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: data, size: 220),
          ),
          const SizedBox(height: 10),
          SelectableText(data,
              style: const TextStyle(color: GlassTokens.textSecondary)),
          TextButton.icon(
            icon: const SIcon(Icons.copy),
            label: Text(c.t('Copy', 'نسخ')),
            onPressed: () => Clipboard.setData(ClipboardData(text: data)),
          ),
        ]),
      ),
    );
