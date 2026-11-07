/// 12-hour clock ("1:18 AM" / "1:18 ص").
String fmtTime12(DateTime t, {bool ar = false}) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  final suffix = t.hour < 12 ? (ar ? 'ص' : 'AM') : (ar ? 'م' : 'PM');
  return '$h:$m $suffix';
}

/// File size: KB below 1024 KB, MB above (what the user asked for).
String fmtSizeKbMb(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 2 : 1)} MB';
}
