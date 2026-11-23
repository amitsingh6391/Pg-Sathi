import 'package:equatable/equatable.dart';

/// Resident-specific values a saved reminder message is filled with.
class ReminderTemplateValues extends Equatable {
  const ReminderTemplateValues({
    required this.studentName,
    required this.libraryName,
    required this.expiry,
    this.amountText,
  });

  final String studentName;
  final String libraryName;
  final String expiry;

  /// Formatted amount including the currency symbol, e.g. "₹500".
  final String? amountText;

  @override
  List<Object?> get props => [studentName, libraryName, expiry, amountText];
}

/// Reusable reminder message with `{name}`, `{library}`, `{amount}` and
/// `{expiry}` placeholders.
abstract class ReminderTemplate {
  static const namePlaceholder = '{name}';
  static const libraryPlaceholder = '{library}';
  static const amountPlaceholder = '{amount}';
  static const expiryPlaceholder = '{expiry}';

  /// Fills the placeholders in [template] with the resident's [values].
  static String render(String template, ReminderTemplateValues values) {
    return template
        .replaceAll(namePlaceholder, values.studentName)
        .replaceAll(libraryPlaceholder, values.libraryName)
        .replaceAll(amountPlaceholder, values.amountText ?? '')
        .replaceAll(expiryPlaceholder, values.expiry);
  }

  /// Turns a concrete [message] back into a template by swapping the resident's
  /// values for their placeholders.
  static String fromMessage(String message, ReminderTemplateValues values) {
    final replacements = {
      values.libraryName: libraryPlaceholder,
      values.expiry: expiryPlaceholder,
      if (values.amountText != null) values.amountText!: amountPlaceholder,
      values.studentName: namePlaceholder,
    };
    var result = message;
    replacements.forEach((value, placeholder) {
      if (value.isNotEmpty) result = result.replaceAll(value, placeholder);
    });
    return result;
  }
}
