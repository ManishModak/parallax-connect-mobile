import 'package:intl/intl.dart';

/// Utility class for date and time formatting
class DateFormatter {
  // Private constructor to prevent instantiation
  DateFormatter._();

  /// Format timestamp to time string (e.g., "2:30 PM")
  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Format timestamp to date string (e.g., "Jan 15, 2024")
  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Format timestamp to full date and time (e.g., "Jan 15, 2024 at 2:30 PM")
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(dateTime);
  }

  /// Format timestamp to relative time (e.g., "2 hours ago", "Just now")
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Get date group label for chat history (e.g., "Today", "Yesterday", "Jan 15")
  static String getDateGroupLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEEE').format(dateTime); // Day name
    } else if (dateTime.year == now.year) {
      return DateFormat('MMM dd').format(dateTime);
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  /// Check if two dates are on the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
