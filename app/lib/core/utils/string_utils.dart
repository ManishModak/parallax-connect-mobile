/// Utility class for string manipulation
class StringUtils {
  // Private constructor to prevent instantiation
  StringUtils._();

  /// Truncate string with ellipsis if it exceeds max length
  static String truncate(
    String text,
    int maxLength, {
    String ellipsis = '...',
  }) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Capitalize first letter of string
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Capitalize first letter of each word
  static String capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) => capitalizeFirst(word)).join(' ');
  }

  /// Remove extra whitespace (multiple spaces, tabs, newlines)
  static String removeExtraWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Remove all whitespace
  static String removeAllWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s'), '');
  }

  /// Get initials from name (e.g., "John Doe" -> "JD")
  static String getInitials(String name, {int maxInitials = 2}) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(maxInitials)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join();
    return initials;
  }

  /// Check if string contains only numbers
  static bool isNumeric(String text) {
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }

  /// Check if string contains only alphanumeric characters
  static bool isAlphanumeric(String text) {
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }

  /// Format file size (bytes to human readable)
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Mask sensitive information (e.g., password, API key)
  static String mask(
    String text, {
    int visibleChars = 4,
    String maskChar = '*',
  }) {
    if (text.length <= visibleChars) {
      return maskChar * text.length;
    }
    final masked = maskChar * (text.length - visibleChars);
    return masked + text.substring(text.length - visibleChars);
  }

  /// Extract domain from URL
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }
}
