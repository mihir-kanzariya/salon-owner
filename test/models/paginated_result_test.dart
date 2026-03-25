import 'package:flutter_test/flutter_test.dart';
import 'package:saloon_app/features/consumer/home/data/repositories/salon_repository.dart';

void main() {
  group('PaginatedResult', () {
    group('constructor', () {
      test('stores all values correctly', () {
        final result = PaginatedResult<String>(
          items: ['a', 'b', 'c'],
          page: 1,
          totalPages: 3,
          total: 9,
        );

        expect(result.items, ['a', 'b', 'c']);
        expect(result.page, 1);
        expect(result.totalPages, 3);
        expect(result.total, 9);
      });

      test('works with empty items list', () {
        final result = PaginatedResult<int>(
          items: [],
          page: 1,
          totalPages: 0,
          total: 0,
        );

        expect(result.items, isEmpty);
        expect(result.page, 1);
        expect(result.totalPages, 0);
        expect(result.total, 0);
      });

      test('works with different generic types', () {
        final intResult = PaginatedResult<int>(
          items: [1, 2, 3],
          page: 1,
          totalPages: 2,
          total: 6,
        );
        expect(intResult.items, [1, 2, 3]);

        final mapResult = PaginatedResult<Map<String, dynamic>>(
          items: [
            {'id': 1},
            {'id': 2},
          ],
          page: 1,
          totalPages: 1,
          total: 2,
        );
        expect(mapResult.items.length, 2);
      });
    });

    group('hasMore', () {
      test('returns true when page is less than totalPages', () {
        final result = PaginatedResult<String>(
          items: ['a'],
          page: 1,
          totalPages: 3,
          total: 3,
        );
        expect(result.hasMore, isTrue);
      });

      test('returns true when page is 1 of 2', () {
        final result = PaginatedResult<String>(
          items: ['a'],
          page: 1,
          totalPages: 2,
          total: 2,
        );
        expect(result.hasMore, isTrue);
      });

      test('returns false when page equals totalPages', () {
        final result = PaginatedResult<String>(
          items: ['a'],
          page: 3,
          totalPages: 3,
          total: 3,
        );
        expect(result.hasMore, isFalse);
      });

      test('returns false when page exceeds totalPages', () {
        final result = PaginatedResult<String>(
          items: [],
          page: 5,
          totalPages: 3,
          total: 3,
        );
        expect(result.hasMore, isFalse);
      });

      test('returns false when totalPages is 1 and page is 1', () {
        final result = PaginatedResult<String>(
          items: ['a'],
          page: 1,
          totalPages: 1,
          total: 1,
        );
        expect(result.hasMore, isFalse);
      });

      test('returns false when totalPages is 0', () {
        final result = PaginatedResult<String>(
          items: [],
          page: 1,
          totalPages: 0,
          total: 0,
        );
        expect(result.hasMore, isFalse);
      });
    });
  });
}
