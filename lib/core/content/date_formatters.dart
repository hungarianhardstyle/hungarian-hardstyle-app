import 'package:intl/intl.dart';

String formatHungarianDate(String value) {
  try {
    return DateFormat('yyyy. MMM d.', 'hu_HU').format(DateTime.parse(value));
  } catch (_) {
    return value;
  }
}

String formatEventDate(String dateValue, String timeValue) {
  try {
    final date = formatHungarianDate(dateValue);
    return timeValue.isEmpty ? date : '$date - $timeValue';
  } catch (_) {
    if (timeValue.isEmpty) return dateValue.isEmpty ? 'Hamarosan' : dateValue;
    return '$dateValue - $timeValue';
  }
}
