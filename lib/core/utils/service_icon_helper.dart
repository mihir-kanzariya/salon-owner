import 'package:flutter/material.dart';

class ServiceIconHelper {
  static IconData getIcon(String? categoryName, String serviceName) {
    final name = (categoryName ?? serviceName).toLowerCase();

    if (name.contains('hair') || name.contains('cut') || name.contains('trim')) {
      return Icons.content_cut;
    }
    if (name.contains('beard') || name.contains('shav')) {
      return Icons.face;
    }
    if (name.contains('facial') || name.contains('skin') || name.contains('cleanup')) {
      return Icons.spa;
    }
    if (name.contains('massage') || name.contains('body') || name.contains('spa')) {
      return Icons.self_improvement;
    }
    if (name.contains('nail') || name.contains('manicure') || name.contains('pedicure')) {
      return Icons.back_hand_outlined;
    }
    if (name.contains('color') || name.contains('dye') || name.contains('highlight')) {
      return Icons.palette;
    }
    if (name.contains('bridal') || name.contains('makeup') || name.contains('make-up')) {
      return Icons.brush;
    }
    if (name.contains('wax') || name.contains('thread')) {
      return Icons.auto_fix_high;
    }
    if (name.contains('keratin') || name.contains('treatment') || name.contains('straighten') || name.contains('smooth')) {
      return Icons.straighten;
    }
    return Icons.design_services_outlined;
  }
}
