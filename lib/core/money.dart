import 'package:intl/intl.dart';

class Money {
  const Money(this.minorUnits, this.currencyCode);

  final int minorUnits;
  final String currencyCode;

  double get majorUnits => minorUnits / 100;

  String format([String locale = 'en']) {
    return NumberFormat.currency(
      locale: locale,
      name: currencyCode,
      symbol: currencyCode == 'EGP' ? 'E£' : currencyCode,
      decimalDigits: 2,
    ).format(majorUnits);
  }

  static int parseMinor(String value) {
    var localized = value;
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabic = '۰۱۲۳۴۵۶۷۸۹';
    for (var index = 0; index < 10; index++) {
      localized = localized
          .replaceAll(arabicIndic[index], '$index')
          .replaceAll(easternArabic[index], '$index');
    }
    final normalized = localized
        .trim()
        .replaceAll(',', '')
        .replaceAll('٫', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(normalized);
    if (parsed == null) throw const FormatException('Invalid amount');
    return (parsed * 100).round();
  }
}
