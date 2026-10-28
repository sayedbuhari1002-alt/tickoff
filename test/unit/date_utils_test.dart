import 'package:flutter_test/flutter_test.dart';
import 'package:tickoff_replacement/core/utils/date_utils.dart';

void main() {
  group('dateKey / parseDateKey', () {
    test('formats with zero padding', () {
      expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(dateKey(DateTime(2026, 10, 27, 23, 59)), '2026-10-27');
    });

    test('round-trips', () {
      final DateTime d = DateTime(2024, 2, 29);
      expect(parseDateKey(dateKey(d)), d);
    });

    test('rejects malformed or impossible keys', () {
      expect(parseDateKey('2026-13-01'), isNull);
      expect(parseDateKey('2026-02-30'), isNull);
      expect(parseDateKey('hello'), isNull);
      expect(parseDateKey('2026-10'), isNull);
    });
  });

  group('day arithmetic', () {
    test('dateOnly strips time', () {
      expect(dateOnly(DateTime(2026, 10, 27, 18, 55)), DateTime(2026, 10, 27));
    });

    test('addDays crosses month and year boundaries', () {
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('daysBetween counts calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 27)), 1);
      expect(daysBetween(DateTime(2026, 10, 27), DateTime(2026, 10, 26)), -1);
      expect(daysBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), 365);
    });

    test('daysInMonth handles leap years', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 10), 31);
    });

    test('daysEndingAt returns oldest first', () {
      final List<DateTime> days = daysEndingAt(DateTime(2026, 10, 27));
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 10, 21));
      expect(days.last, DateTime(2026, 10, 27));
    });
  });

  group('labels', () {
    test('ordinal', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(4), '4th');
      expect(ordinal(11), '11th');
      expect(ordinal(12), '12th');
      expect(ordinal(13), '13th');
      expect(ordinal(21), '21st');
      expect(ordinal(22), '22nd');
      expect(ordinal(23), '23rd');
      expect(ordinal(27), '27th');
    });

    test('dayMonthLabel and monthYear', () {
      final DateTime d = DateTime(2026, 10, 27);
      expect(dayMonthLabel(d), '27th Oct');
      expect(monthYear(d), 'October 2026');
      expect(weekdayShort(d), 'Tue');
    });

    test('headerPrefix', () {
      final DateTime today = DateTime(2026, 10, 27);
      expect(headerPrefix(today, today), 'Today');
      expect(headerPrefix(DateTime(2026, 10, 26), today), 'Mon');
    });
  });
}
