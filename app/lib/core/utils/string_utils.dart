/// Utility class for string manipulation
class StringUtils {
  // Private constructor to prevent instantiation
  StringUtils._();

  /// Truncate string with ellipsis if it exceeds max length
  static String truncate(
    String? text,
    int maxLength, {
    String ellipsis = '...',
  }) {
    if (text == null || text.isEmpty) return '';
    if (maxLength <= 0) return '';
    if (text.length <= maxLength) return text;
    if (maxLength <= ellipsis.length) return text.substring(0, maxLength);

    return '${text.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  /// Capitalize first letter of string
  static String capitalizeFirst(String? text) {
    if (text == null || text.isEmpty) return '';
    return text[0].toUpperCase() + (text.length > 1 ? text.substring(1) : '');
  }

  /// Capitalize first letter of each word
  static String capitalizeWords(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map((word) => capitalizeFirst(word)).join(' ');
  }

  /// Remove extra whitespace (multiple spaces, tabs, newlines)
  static String removeExtraWhitespace(String? text) {
    if (text == null) return '';
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Remove all whitespace
  static String removeAllWhitespace(String? text) {
    if (text == null) return '';
    return text.replaceAll(RegExp(r'\s'), '');
  }

  /// Get initials from name (e.g., "John Doe" -> "JD")
  static String getInitials(String? name, {int maxInitials = 2}) {
    if (name == null || name.isEmpty) return '';
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(maxInitials)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .join();
    return initials;
  }

  /// Check if string contains only numbers
  static bool isNumeric(String? text) {
    if (text == null || text.isEmpty) return false;
    return RegExp(r'^[0-9]+$').hasMatch(text);
  }

  /// Check if string contains only alphanumeric characters
  static bool isAlphanumeric(String? text) {
    if (text == null || text.isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }

  /// Format file size (bytes to human readable)
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Mask sensitive information (e.g., password, API key)
  static String mask(
    String? text, {
    int visibleChars = 4,
    String maskChar = '*',
  }) {
    if (text == null || text.isEmpty) return '';
    if (visibleChars < 0) visibleChars = 0;
    if (text.length <= visibleChars) {
      return maskChar * text.length;
    }
    final masked = maskChar * (text.length - visibleChars);
    return masked + text.substring(text.length - visibleChars);
  }

  /// Extract domain from URL
  static String? extractDomain(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return null;
    }
  }
}
