import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'skeletons/shimmer_image.dart';

class SalonCard extends StatelessWidget {
  final String name;
  final String address;
  final String? coverImage;
  final double rating;
  final int ratingCount;
  final String? distance;
  final String genderType;
  final bool isOpen;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final double? minPrice;
  final double? maxPrice;

  const SalonCard({
    super.key,
    required this.name,
    required this.address,
    this.coverImage,
    this.rating = 0,
    this.ratingCount = 0,
    this.distance,
    this.genderType = 'unisex',
    this.isOpen = true,
    this.onTap,
    this.onFavorite,
    this.isFavorite = false,
    this.minPrice,
    this.maxPrice,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Stack(
              children: [
                ShimmerImage(
                  imageUrl: coverImage != null
                      ? (ApiConfig.imageUrl(coverImage) ?? coverImage!)
                      : null,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  errorWidget: Container(
                    height: 160,
                    color: AppColors.softSurface,
                    child: const Icon(Icons.store, size: 48, color: AppColors.textMuted),
                  ),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Open/Closed badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.success : AppColors.error,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOpen ? 'Open' : 'Closed',
                      style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Favorite button
                if (onFavorite != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? AppColors.error : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Info section
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: AppTextStyles.h4, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (distance != null)
                        Text(distance!, style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.ratingStar, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating > 0 ? rating.toStringAsFixed(1) : 'New',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimary),
                      ),
                      if (ratingCount > 0) ...[
                        Text(' ($ratingCount)', style: AppTextStyles.caption),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          genderType[0].toUpperCase() + genderType.substring(1),
                          style: const TextStyle(fontSize: 11, color: AppColors.accentDark, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (minPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          maxPrice != null && maxPrice != minPrice
                              ? '\u20B9${minPrice!.toStringAsFixed(0)} - \u20B9${maxPrice!.toStringAsFixed(0)}'
                              : '\u20B9${minPrice!.toStringAsFixed(0)}+',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
