/// Authentication related constants
class AuthConstants {
  AuthConstants._();

  /// Test phone numbers that always use Firebase OTP (bypass quota)
  /// These numbers are configured in Firebase Console as test numbers
  /// and don't consume SMS quota or incur charges
  static const testPhoneNumbers = {
    '+919090909090',
    '+919898989898',
    '+917878787878',
    '+918423090444',
    '+919033333333',
    '+916767676767',
    '+918080808080',
    '+916391345357',
    // Test numbers configured in the pg-sathi Firebase Console.
    '+917275663331',
    '+919807557412',
    '+919532506142',
    '+916505553434',
    '+19532506142',
  };

  /// Checks if a phone number is a test number
  static bool isTestNumber(String phoneNumber) {
    // Remove spaces, dashes, parentheses and other special characters
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return testPhoneNumbers.contains(cleanedNumber);
  }
}
