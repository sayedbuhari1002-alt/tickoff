/// Date helpers. Every habit record is keyed by a calendar day, never by a
/// timestamp, so all helpers work on date-only values in local time.

const List<String> _weekdaysShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthsShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthsLong = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Strips the time part (local time).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Adds [days] calendar days. Uses the DateTime constructor so daylight-saving
/// changes can never shift the result to the wrong day.
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) {
  final DateTime a = DateTime.utc(from.year, from.month, from.day);
  final DateTime b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

String _two(int n) => n.toString().padLeft(2, '0');

/// Storage key for a calendar day, e.g. `2026-10-27`.
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${_two(d.month)}-${_two(d.day)}';

/// Inverse of [dateKey]. Returns null when [key] is malformed.
DateTime? parseDateKey(String key) {
  final List<String> parts = key.split('-');
  if (parts.length != 3) return null;
  final int? y = int.tryParse(parts[0]);
  final int? m = int.tryParse(parts[1]);
  final int? d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > daysInMonth(y, m)) return null;
  return DateTime(y, m, d);
}

/// [count] consecutive days ending at [end], oldest first.
List<DateTime> daysEndingAt(DateTime end, {int count = 7}) {
  final DateTime last = dateOnly(end);
  return List<DateTime>.generate(
    count,
    (int i) => addDays(last, i - (count - 1)),
  );
}

/// `Mon`..`Sun`.
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// `Jan`..`Dec`.
String monthShort(DateTime d) => _monthsShort[d.month - 1];

/// `October 2026`.
String monthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// 1 -> `1st`, 2 -> `2nd`, 11 -> `11th`, 23 -> `23rd`.
String ordinal(int n) {
  final int mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

/// `27th Oct`.
String dayMonthLabel(DateTime d) => '${ordinal(d.day)} ${monthShort(d)}';

/// Dashboard heading prefix: `Today` for today, otherwise the weekday name.
String headerPrefix(DateTime selected, DateTime today) =>
    isSameDay(selected, today) ? 'Today' : weekdayShort(selected);

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

/// First day of the month containing [d].
DateTime monthStart(DateTime d) => DateTime(d.year, d.month, 1);

/// Last day of the month containing [d].
DateTime monthEnd(DateTime d) => DateTime(d.year, d.month + 1, 0);

/// `Mon, Wed, Fri` style list for weekday numbers (1 = Monday).
String weekdayList(Iterable<int> weekdays) {
  final List<int> sorted = weekdays.toList()..sort();
  return sorted.map((int w) => _weekdaysShort[w - 1]).join(', ');
}

/// Two-letter labels used by the day chips: Mo Tu We Th Fr Sa Su.
const List<String> weekdayChipLabels = <String>[
  'Mo',
  'Tu',
  'We',
  'Th',
  'Fr',
  'Sa',
  'Su',
];
