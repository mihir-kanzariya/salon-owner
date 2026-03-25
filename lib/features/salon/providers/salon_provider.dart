import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../config/api_config.dart';

class SalonProvider extends ChangeNotifier {
  String? _salonId;
  String? _myRole;
  String? _memberId;
  bool _loaded = false;
  Map<String, dynamic>? _salonData;

  String? get salonId => _salonId;
  String? get myRole => _myRole;
  String? get memberId => _memberId;
  bool get loaded => _loaded;
  Map<String, dynamic>? get salonData => _salonData;

  bool get isStylist => _myRole == 'stylist';
  bool get isReceptionist => _myRole == 'receptionist';
  bool get isOwnerOrManager =>
      _myRole == 'owner' || _myRole == 'manager';
  /// Roles that can manage bookings but not salon settings.
  bool get isStaffRole => isStylist || isReceptionist;

  Future<void> loadSalonData() async {
    try {
      final res = await ApiService().get(ApiConfig.mySalons);
      final salons = res['data'] as List<dynamic>? ?? [];

      if (salons.isNotEmpty) {
        final salon = salons[0] as Map<String, dynamic>;
        _salonData = salon;
        _salonId = salon['id']?.toString();
        _myRole = salon['my_role']?.toString();
        _memberId = salon['my_member_id']?.toString();
      }

      _loaded = true;
      notifyListeners();
    } catch (_) {
      _loaded = true;
      notifyListeners();
    }
  }

  void clear() {
    _salonData = null;
    _salonId = null;
    _myRole = null;
    _memberId = null;
    _loaded = false;
    notifyListeners();
  }
}
