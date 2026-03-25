import 'package:flutter_test/flutter_test.dart';
import 'package:saloon_app/core/utils/time_utils.dart';

void main() {
  group('formatTime12h', () {
    group('AM times', () {
      test('converts midnight 00:00 to 12:00 AM', () {
        expect(formatTime12h('00:00'), '12:00 AM');
      });

      test('converts 01:00 to 1:00 AM', () {
        expect(formatTime12h('01:00'), '1:00 AM');
      });

      test('converts 09:00 to 9:00 AM', () {
        expect(formatTime12h('09:00'), '9:00 AM');
      });

      test('converts 09:30 to 9:30 AM', () {
        expect(formatTime12h('09:30'), '9:30 AM');
      });

      test('converts 11:59 to 11:59 AM', () {
        expect(formatTime12h('11:59'), '11:59 AM');
      });
    });

    group('PM times', () {
      test('converts 12:00 to 12:00 PM (noon)', () {
        expect(formatTime12h('12:00'), '12:00 PM');
      });

      test('converts 13:00 to 1:00 PM', () {
        expect(formatTime12h('13:00'), '1:00 PM');
      });

      test('converts 14:30 to 2:30 PM', () {
        expect(formatTime12h('14:30'), '2:30 PM');
      });

      test('converts 18:00 to 6:00 PM', () {
        expect(formatTime12h('18:00'), '6:00 PM');
      });

      test('converts 21:00 to 9:00 PM', () {
        expect(formatTime12h('21:00'), '9:00 PM');
      });

      test('converts 23:59 to 11:59 PM', () {
        expect(formatTime12h('23:59'), '11:59 PM');
      });
    });

    group('edge cases', () {
      test('returns empty string for null input', () {
        expect(formatTime12h(null), '');
      });

      test('returns empty string for empty string input', () {
        expect(formatTime12h(''), '');
      });

      test('returns original string for input without colon', () {
        expect(formatTime12h('0900'), '0900');
      });

      test('returns original string for invalid numeric parts', () {
        expect(formatTime12h('abc:def'), 'abc:def');
      });

      test('handles time with seconds (e.g. 14:30:00)', () {
        // parts.length >= 2 so it should still parse hours and minutes
        expect(formatTime12h('14:30:00'), '2:30 PM');
      });
    });
  });

  group('formatTimeRange12h', () {
    test('formats a full range correctly', () {
      expect(
        formatTimeRange12h('09:00', '18:00'),
        '9:00 AM - 6:00 PM',
      );
    });

    test('formats a range with same AM/PM period', () {
      expect(
        formatTimeRange12h('09:00', '11:30'),
        '9:00 AM - 11:30 AM',
      );
    });

    test('handles null start time', () {
      expect(
        formatTimeRange12h(null, '18:00'),
        ' - 6:00 PM',
      );
    });

    test('handles null end time', () {
      expect(
        formatTimeRange12h('09:00', null),
        '9:00 AM - ',
      );
    });

    test('handles both null times', () {
      expect(
        formatTimeRange12h(null, null),
        ' - ',
      );
    });

    test('formats midnight to noon range', () {
      expect(
        formatTimeRange12h('00:00', '12:00'),
        '12:00 AM - 12:00 PM',
      );
    });
  });
}
