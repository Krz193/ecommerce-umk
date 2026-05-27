import 'package:intl/intl.dart';

class DateFormatter {
  static String formatDateTime(String value) {
    final dateTime = DateTime.parse(value);

    return DateFormat('dd MMM yyyy • HH:mm').format(dateTime);
  }
}
