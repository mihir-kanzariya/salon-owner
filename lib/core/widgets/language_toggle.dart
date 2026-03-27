import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/locale_provider.dart';
import '../constants/app_colors.dart';

/// Language toggle button — switches between English and Gujarati.
/// Shows as a solid teal pill with white text — highly visible in AppBar.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, locale, _) {
        return GestureDetector(
          onTap: () => locale.toggleLocale(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  locale.isEnglish ? 'ગુ' : 'EN',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
