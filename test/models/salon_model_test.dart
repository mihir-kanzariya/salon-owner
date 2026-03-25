import 'package:flutter_test/flutter_test.dart';
import 'package:saloon_app/features/consumer/home/data/models/salon_model.dart';

void main() {
  group('SalonModel', () {
    group('fromJson', () {
      test('parses complete JSON data correctly', () {
        final json = {
          'id': 'salon-123',
          'name': 'Premium Cuts',
          'description': 'A luxury salon experience',
          'phone': '+919876543210',
          'address': '123 Main Street, Ahmedabad',
          'city': 'Ahmedabad',
          'latitude': '23.0225',
          'longitude': '72.5714',
          'gender_type': 'male',
          'cover_image': 'https://example.com/cover.jpg',
          'gallery': ['https://example.com/1.jpg', 'https://example.com/2.jpg'],
          'amenities': ['WiFi', 'AC', 'Parking'],
          'operating_hours': {
            'monday': {'is_open': true, 'open': '09:00', 'close': '21:00'},
            'tuesday': {'is_open': true, 'open': '09:00', 'close': '21:00'},
            'sunday': {'is_open': false},
          },
          'booking_settings': {'slot_duration': 30, 'max_advance_days': 7},
          'rating_avg': '4.5',
          'rating_count': 120,
          'is_active': true,
          'distance': '2.5',
          'owner': {'id': 'owner-1', 'name': 'John Doe'},
          'services': [
            {'id': 's1', 'name': 'Haircut', 'price': 300}
          ],
          'members': [
            {'id': 'm1', 'name': 'Staff Member'}
          ],
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.id, 'salon-123');
        expect(salon.name, 'Premium Cuts');
        expect(salon.description, 'A luxury salon experience');
        expect(salon.phone, '+919876543210');
        expect(salon.address, '123 Main Street, Ahmedabad');
        expect(salon.city, 'Ahmedabad');
        expect(salon.latitude, 23.0225);
        expect(salon.longitude, 72.5714);
        expect(salon.genderType, 'male');
        expect(salon.coverImage, 'https://example.com/cover.jpg');
        expect(salon.gallery, hasLength(2));
        expect(salon.gallery[0], 'https://example.com/1.jpg');
        expect(salon.amenities, ['WiFi', 'AC', 'Parking']);
        expect(salon.operatingHours['monday']['is_open'], isTrue);
        expect(salon.bookingSettings['slot_duration'], 30);
        expect(salon.ratingAvg, 4.5);
        expect(salon.ratingCount, 120);
        expect(salon.isActive, isTrue);
        expect(salon.distance, 2.5);
        expect(salon.owner?['name'], 'John Doe');
        expect(salon.services, hasLength(1));
        expect(salon.members, hasLength(1));
      });

      test('uses defaults for minimal JSON with null/missing fields', () {
        final json = <String, dynamic>{};

        final salon = SalonModel.fromJson(json);

        expect(salon.id, '');
        expect(salon.name, '');
        expect(salon.description, isNull);
        expect(salon.phone, '');
        expect(salon.address, '');
        expect(salon.city, isNull);
        expect(salon.latitude, 0);
        expect(salon.longitude, 0);
        expect(salon.genderType, 'unisex');
        expect(salon.coverImage, isNull);
        expect(salon.gallery, isEmpty);
        expect(salon.amenities, isEmpty);
        expect(salon.operatingHours, isEmpty);
        expect(salon.bookingSettings, isEmpty);
        expect(salon.ratingAvg, 0);
        expect(salon.ratingCount, 0);
        expect(salon.isActive, isTrue);
        expect(salon.distance, isNull);
        expect(salon.owner, isNull);
        expect(salon.services, isNull);
        expect(salon.members, isNull);
      });

      test('handles empty string values', () {
        final json = {
          'id': '',
          'name': '',
          'phone': '',
          'address': '',
          'latitude': '',
          'longitude': '',
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.id, '');
        expect(salon.name, '');
        expect(salon.phone, '');
        expect(salon.address, '');
        expect(salon.latitude, 0); // double.tryParse('') returns null -> fallback 0
        expect(salon.longitude, 0);
      });

      test('handles zero values for numeric fields', () {
        final json = {
          'id': 'salon-0',
          'name': 'Zero Salon',
          'phone': '0000000000',
          'address': 'Nowhere',
          'latitude': '0',
          'longitude': '0',
          'rating_avg': '0',
          'rating_count': 0,
          'distance': '0',
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.latitude, 0.0);
        expect(salon.longitude, 0.0);
        expect(salon.ratingAvg, 0.0);
        expect(salon.ratingCount, 0);
        expect(salon.distance, 0.0);
      });

      test('parses latitude and longitude from numeric types', () {
        final json = {
          'id': 'salon-num',
          'name': 'Numeric Salon',
          'phone': '1234567890',
          'address': '456 Street',
          'latitude': 23.0225, // double, not string
          'longitude': 72.5714, // double, not string
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.latitude, 23.0225);
        expect(salon.longitude, 72.5714);
      });

      test('parses rating_avg from numeric type', () {
        final json = {
          'id': 'salon-r',
          'name': 'Rated Salon',
          'phone': '111',
          'address': 'Addr',
          'rating_avg': 3.7, // double, not string
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.ratingAvg, 3.7);
      });

      test('handles null distance gracefully', () {
        final json = {
          'id': 'salon-d',
          'name': 'Distant Salon',
          'phone': '222',
          'address': 'Far away',
          'distance': null,
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.distance, isNull);
      });

      test('handles empty gallery and amenities arrays', () {
        final json = {
          'id': 'salon-e',
          'name': 'Empty Salon',
          'phone': '333',
          'address': 'Empty St',
          'gallery': [],
          'amenities': [],
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.gallery, isEmpty);
        expect(salon.amenities, isEmpty);
      });

      test('handles is_active false', () {
        final json = {
          'id': 'salon-inactive',
          'name': 'Closed Salon',
          'phone': '444',
          'address': 'Closed St',
          'is_active': false,
        };

        final salon = SalonModel.fromJson(json);

        expect(salon.isActive, isFalse);
      });
    });

    group('distanceText', () {
      test('returns empty string when distance is null', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: null,
        );
        expect(salon.distanceText, '');
      });

      test('returns meters when distance is less than 1 km', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 0.5,
        );
        expect(salon.distanceText, '500m');
      });

      test('returns meters for very small distance', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 0.15,
        );
        expect(salon.distanceText, '150m');
      });

      test('returns km with one decimal for distance >= 1', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 2.5,
        );
        expect(salon.distanceText, '2.5 km');
      });

      test('returns km for exactly 1 km', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 1.0,
        );
        expect(salon.distanceText, '1.0 km');
      });

      test('returns km for large distances', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 15.3,
        );
        expect(salon.distanceText, '15.3 km');
      });

      test('returns 0m when distance is 0', () {
        final salon = SalonModel(
          id: '1',
          name: 'Test',
          phone: '123',
          address: 'Addr',
          latitude: 0,
          longitude: 0,
          distance: 0.0,
        );
        // 0.0 < 1, so (0.0 * 1000).round() = 0 => "0m"
        expect(salon.distanceText, '0m');
      });
    });
  });
}
