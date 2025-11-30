/// Utility class for input validation
class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  /// Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate URL and return normalized version
  static String? normalizeUrl(String url) {
    if (url.isEmpty) return null;

    // Add https:// if no scheme is provided
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    if (isValidUrl(url)) {
      return url;
    }
    return null;
  }

  /// Validate password strength
  /// Returns null if valid, error message if invalid
  static String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  /// Check if string is empty or contains only whitespace
  static bool isEmptyOrWhitespace(String? value) {
    return value == null || value.trim().isEmpty;
  }

  /// Check if string is not empty
  static bool isNotEmpty(String? value) {
    return !isEmptyOrWhitespace(value);
  }

  /// Validate IP address format (IPv4)
  static bool isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    return parts.every((part) {
      final num = int.tryParse(part);
      return num != null && num >= 0 && num <= 255;
    });
  }

  /// Validate port number
  static bool isValidPort(String port) {
    final num = int.tryParse(port);
    return num != null && num > 0 && num <= 65535;
  }

  /// Validate localhost URL (with optional port)
  static bool isValidLocalhost(String url) {
    // Remove protocol if present
    url = url.replaceAll(RegExp(r'^https?://'), '');

    // Check for localhost patterns
    final localhostPattern = RegExp(
      r'^(localhost|127\.0\.0\.1)(:\d+)?(/.*)?$',
      caseSensitive: false,
    );

    if (localhostPattern.hasMatch(url)) {
      return true;
    }

    return isValidLanUrl(url);
  }

  /// Validate LAN IP (192.168.x.x or 10.x.x.x) with optional port/path
  static bool isValidLanUrl(String url) {
    if (url.isEmpty) return false;

    final normalized = url.startsWith('http://') || url.startsWith('https://')
        ? url
        : 'http://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;

    final lanPattern = RegExp(
      r'^(192\.168\.\d{1,3}\.\d{1,3}|10\.\d{1,3}\.\d{1,3}\.\d{1,3})$',
    );

    if (!lanPattern.hasMatch(uri.host)) {
      return false;
    }

    if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) {
      return false;
    }

    return true;
  }
}
