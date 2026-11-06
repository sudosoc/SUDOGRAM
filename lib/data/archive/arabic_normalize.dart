/// Folds text so Arabic and English search is forgiving:
/// tashkeel and tatweel removed, alef/yaa/taa-marbuta variants unified,
/// Arabic-Indic digits mapped to ASCII, Latin lower-cased.
String normalizeForSearch(String input) {
  final out = StringBuffer();
  for (final r in input.runes) {
    // Tashkeel, superscript alef, tatweel, quranic marks.
    if ((r >= 0x064B && r <= 0x065F) ||
        r == 0x0670 ||
        r == 0x0640 ||
        (r >= 0x06D6 && r <= 0x06ED)) {
      continue;
    }
    if (r == 0x0622 || r == 0x0623 || r == 0x0625 || r == 0x0671) {
      out.writeCharCode(0x0627); // آ أ إ ٱ → ا
    } else if (r == 0x0649 || r == 0x06CC) {
      out.writeCharCode(0x064A); // ى ی → ي
    } else if (r == 0x0629) {
      out.writeCharCode(0x0647); // ة → ه
    } else if (r == 0x06A9) {
      out.writeCharCode(0x0643); // ک → ك
    } else if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else {
      out.write(String.fromCharCode(r).toLowerCase());
    }
  }
  return out.toString();
}
