import 'package:flutter_test/flutter_test.dart';
import 'package:pg_manager/core/utils/indian_currency_format.dart';

void main() {
  group('formatIndianRupeeInteger', () {
    test('should_group_with_indian_system_when_large', () {
      expect(formatIndianRupeeInteger(1234567), '12,34,567');
      expect(formatIndianRupeeInteger(100000), '1,00,000');
      expect(formatIndianRupeeInteger(1000), '1,000');
    });

    test('should_not_add_commas_when_three_digits_or_less', () {
      expect(formatIndianRupeeInteger(999), '999');
      expect(formatIndianRupeeInteger(0), '0');
    });

    test('should_round_to_whole_rupees', () {
      expect(formatIndianRupeeInteger(12345.7), '12,346');
    });
  });

  group('indianRupeeCurrencyFormat', () {
    test('should_include_symbol_and_indian_grouping', () {
      expect(indianRupeeCurrencyFormat.format(1234567), '₹12,34,567');
    });
  });
}
