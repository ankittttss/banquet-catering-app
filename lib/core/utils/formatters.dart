import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _time = DateFormat('hh:mm a');

  static String currency(num amount) => _currency.format(amount);
  static String date(DateTime date) => _date.format(date);
  static String time(DateTime time) => _time.format(time);
}
