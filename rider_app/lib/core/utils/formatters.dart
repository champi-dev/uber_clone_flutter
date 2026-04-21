import 'package:intl/intl.dart';

final _cop = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
String formatCop(num v) => _cop.format(v);

String formatDate(DateTime d) => DateFormat('MMM d, h:mm a').format(d);
String formatDateShort(DateTime d) => DateFormat('MMM d').format(d);

String formatKm(num km) => '${km.toStringAsFixed(1)} km';
String formatMin(num m) => '${m.round()} min';
