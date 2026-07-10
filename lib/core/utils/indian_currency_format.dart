import 'package:intl/intl.dart';

/// Whole rupees with Indian digit grouping (lakhs/crores). No currency symbol.
///
/// Use: `'₹${formatIndianRupeeInteger(amount)}'`.
String formatIndianRupeeInteger(num amount) =>
    _indianRupeeInteger.format(amount);

final NumberFormat _indianRupeeInteger = NumberFormat.decimalPatternDigits(
  locale: 'en_IN',
  decimalDigits: 0,
);

/// Indian locale, ₹ symbol, no fraction digits. Reuse for `.format(amount)`.
final NumberFormat indianRupeeCurrencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
