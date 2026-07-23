import 'package:intl/intl.dart';

class DateFormatter {
  static String format(DateTime date) {
    return DateFormat('dd MMM yyyy • HH:mm').format(date.toLocal());
  }

  static String formatDateTime(String value) {
    final dateTime = DateTime.parse(value).toLocal();

    return DateFormat('dd MMM yyyy • HH:mm').format(dateTime);
  }
}
