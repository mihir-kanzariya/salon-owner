/// Converts a 24-hour time string (e.g. "09:00", "14:30") to 12-hour AM/PM format.
/// Returns "9:00 AM", "2:30 PM", etc.
String formatTime12h(String? time24) {
  if (time24 == null || time24.isEmpty) return '';
  try {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour -= 12;
    }
    return '$hour:$minute $period';
  } catch (_) {
    return time24;
  }
}

/// Formats a time range like "09:00 - 14:30" to "9:00 AM - 2:30 PM".
String formatTimeRange12h(String? startTime, String? endTime) {
  return '${formatTime12h(startTime)} - ${formatTime12h(endTime)}';
}
