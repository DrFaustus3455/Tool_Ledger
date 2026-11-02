/// Frontend security boundaries. These checks improve usability only.
/// Production authorization, approval rules, exports and writes must be
/// revalidated by the Spring Boot backend on every request.
abstract final class SecurityPolicy {
  static const sessionCookieName = 'TOOLLEDGER_SESSION';
  static const maxImageBytes = 5 * 1024 * 1024;
  static const allowedImageExtensions = {'jpg', 'jpeg', 'png'};
  static const minPasswordLength = 12;

  static bool isAllowedImage(String name, int bytes) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    return bytes <= maxImageBytes && allowedImageExtensions.contains(extension);
  }

  static String? validateNewPassword(String value) {
    if (value.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include uppercase, lowercase and numeric characters.';
    }
    return null;
  }
}
