import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/loading_widget.dart';
import '../../../../../core/widgets/skeletons/shimmer_image.dart';
import '../../../../../core/widgets/skeletons/skeleton_layouts.dart';
import '../../../../../core/widgets/skeletons/skeleton_elements.dart';
import '../../../../../core/widgets/empty_state_widget.dart';
import '../../../../../services/api_service.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../config/api_config.dart';

class GalleryScreen extends StatefulWidget {
  final String salonId;

  const GalleryScreen({super.key, required this.salonId});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  bool _isDeleting = false;
  List<dynamic> _images = [];

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      setState(() => _isLoading = true);
      final res = await _api.get('${ApiConfig.salonDetail}/${widget.salonId}');
      final salon = res['data'] ?? {};
      _images = List<dynamic>.from(salon['gallery'] ?? []);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Failed to load gallery'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteImage(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to remove this image from the gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isDeleting = true);

      final updatedImages = List<dynamic>.from(_images);
      updatedImages.removeAt(index);

      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {'gallery': updatedImages},
      );

      setState(() {
        _images = updatedImages;
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Image removed'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Failed to delete image'),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isUploading = false;

  Future<void> _onAddImage() async {
    if (_isUploading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await UploadService().pickAndUpload(
        folder: 'salons/${widget.salonId}/gallery',
        source: source,
        preset: UploadPreset.gallery,
      );
      if (url != null && mounted) {
        final updatedImages = List<dynamic>.from(_images)..add(url);
        await _api.put(
          '${ApiConfig.salonDetail}/${widget.salonId}',
          body: {'gallery': updatedImages},
        );
        setState(() => _images = updatedImages);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [
                Icon(Icons.check_circle, color: AppColors.white, size: 20),
                SizedBox(width: 8),
                Text('Photo added'),
              ]),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text('Upload failed: $e')),
            ]),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _viewImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_images.length} photos',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const SkeletonList(child: SkeletonBox(height: 160, borderRadius: 12), count: 6)
          : _isUploading
              ? const LoadingWidget(message: 'Uploading photo...')
              : _isDeleting
                  ? const LoadingWidget(message: 'Removing image...')
                  : _images.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.photo_library_outlined,
                      title: 'No Photos Yet',
                      subtitle:
                          'Add photos to showcase your salon and attract more customers.',
                      actionText: 'Add Photo',
                      onAction: _onAddImage,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadGallery,
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return _buildImageCard(index);
                        },
                      ),
                    ),
      floatingActionButton: _images.isNotEmpty && !_isLoading && !_isDeleting
          ? FloatingActionButton(
              onPressed: _onAddImage,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_a_photo, color: AppColors.white),
            )
          : null,
    );
  }

  Widget _buildImageCard(int index) {
    final imageUrl = _images[index].toString();

    return GestureDetector(
      onTap: () => _viewImage(imageUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              CachedNetworkImage(
                imageUrl: ApiConfig.imageUrl(imageUrl) ?? imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: AppColors.shimmerBase,
                  highlightColor: AppColors.shimmerHighlight,
                  child: Container(
                    color: Colors.white,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.softSurface,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 32,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Failed to load',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Gradient overlay at top for delete button visibility
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Delete button
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _deleteImage(index),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-screen image viewer
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: ShimmerImage(
            imageUrl: ApiConfig.imageUrl(imageUrl) ?? imageUrl,
            fit: BoxFit.contain,
            errorWidget: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 12),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
