import 'package:flutter/widgets.dart';

/// Inline bilingual strings for newer screens: `context.t('Save', 'حفظ')`.
extension TrX on BuildContext {
  bool get isAr => Localizations.localeOf(this).languageCode == 'ar';
  String t(String en, String ar) => isAr ? ar : en;
}
