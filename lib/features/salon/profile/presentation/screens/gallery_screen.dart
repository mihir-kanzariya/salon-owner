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
import '../../../../../services/api_service.dart';
import '../../../../../services/upload_service.dart';
import '../../../../../config/api_config.dart';

const int _kMaxGalleryImages = 50;

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
  bool _isUploading = false;
  bool _isReorderMode = false;
  bool _isSaving = false;
  List<dynamic> _images = [];
  String? _coverImage;

  // Bulk upload tracking
  int _bulkTotal = 0;
  int _bulkCompleted = 0;
  List<String> _bulkFailures = [];

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
      _coverImage = (salon['cover_image'] ?? salon['coverImage'])?.toString();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Failed to load gallery', isError: true);
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _saveGallery(List<dynamic> updatedImages) async {
    try {
      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {'gallery': updatedImages},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────

  Future<void> _deleteImage(int index) async {
    final imageUrl = _images[index].toString();

    // Warn if deleting the cover image
    if (_coverImage != null && _coverImage == imageUrl) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cover Photo'),
          content: const Text(
            'This is your cover photo. Choose a new cover photo first, or the cover will be cleared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Anyway', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to remove this image from the gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousImages = List<dynamic>.from(_images);
    try {
      setState(() => _isDeleting = true);

      final updatedImages = List<dynamic>.from(_images);
      updatedImages.removeAt(index);

      // If deleting cover image, clear it
      Map<String, dynamic> body = {'gallery': updatedImages};
      if (_coverImage != null && _coverImage == imageUrl) {
        body['cover_image'] = '';
      }

      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: body,
      );

      setState(() {
        _images = updatedImages;
        if (_coverImage == imageUrl) _coverImage = null;
        _isDeleting = false;
      });

      _showSnackBar('Image removed');
    } catch (e) {
      setState(() {
        _images = previousImages;
        _isDeleting = false;
      });
      _showSnackBar('Failed to delete image', isError: true);
    }
  }

  // ── Set as Cover ────────────────────────────────────────────────────

  Future<void> _setAsCover(String imageUrl) async {
    try {
      setState(() => _isSaving = true);
      await _api.put(
        '${ApiConfig.salonDetail}/${widget.salonId}',
        body: {'cover_image': imageUrl},
      );
      setState(() {
        _coverImage = imageUrl;
        _isSaving = false;
      });
      _showSnackBar('Cover photo updated');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to update cover photo', isError: true);
    }
  }

  // ── Reorder ─────────────────────────────────────────────────────────

  void _toggleReorderMode() {
    if (_isReorderMode) {
      // Exiting reorder mode — save
      _saveReorder();
    }
    setState(() => _isReorderMode = !_isReorderMode);
  }

  Future<void> _saveReorder() async {
    final success = await _saveGallery(_images);
    if (success) {
      _showSnackBar('Gallery reordered');
    } else {
      _showSnackBar('Failed to save gallery order', isError: true);
      _loadGallery(); // Revert on failure
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  // ── Single Image Upload ─────────────────────────────────────────────

  Future<void> _onAddImage() async {
    if (_isUploading) return;

    if (_images.length >= _kMaxGalleryImages) {
      _showSnackBar('Maximum $_kMaxGalleryImages photos allowed', isError: true);
      return;
    }

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photo'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose Multiple Photos'),
              subtitle: Text(
                'Select up to ${_kMaxGalleryImages - _images.length} more',
                style: AppTextStyles.caption,
              ),
              onTap: () => Navigator.pop(ctx, 'multi'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    if (source == 'multi') {
      await _onBulkUpload();
      return;
    }

    final imageSource =
        source == 'camera' ? ImageSource.camera : ImageSource.gallery;

    setState(() => _isUploading = true);
    final previousImages = List<dynamic>.from(_images);
    try {
      final url = await UploadService().pickAndUpload(
        folder: 'salons/${widget.salonId}/gallery',
        source: imageSource,
        preset: UploadPreset.gallery,
      );
      if (url != null && mounted) {
        final updatedImages = List<dynamic>.from(_images)..add(url);
        final success = await _saveGallery(updatedImages);
        if (success) {
          setState(() => _images = updatedImages);
          _showSnackBar('Photo added');
        } else {
          setState(() => _images = previousImages);
          _showSnackBar('Failed to save photo', isError: true);
        }
      }
    } catch (e) {
      setState(() => _images = previousImages);
      _showSnackBar('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Bulk Upload ─────────────────────────────────────────────────────

  Future<void> _onBulkUpload() async {
    final remaining = _kMaxGalleryImages - _images.length;
    if (remaining <= 0) {
      _showSnackBar('Maximum $_kMaxGalleryImages photos allowed', isError: true);
      return;
    }

    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 70,
    );

    if (pickedFiles.isEmpty) return;

    final filesToUpload = pickedFiles.length > remaining
        ? pickedFiles.sublist(0, remaining)
        : pickedFiles;

    if (pickedFiles.length > remaining) {
      _showSnackBar(
        'Only uploading $remaining of ${pickedFiles.length} (gallery limit $_kMaxGalleryImages)',
        isError: true,
      );
    }

    setState(() {
      _isUploading = true;
      _bulkTotal = filesToUpload.length;
      _bulkCompleted = 0;
      _bulkFailures = [];
    });

    final previousImages = List<dynamic>.from(_images);
    final List<String> uploadedUrls = [];

    for (final file in filesToUpload) {
      try {
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        String contentType;
        switch (ext) {
          case 'png':
            contentType = 'image/png';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          default:
            contentType = 'image/jpeg';
        }

        // Check file size (skip if > 10MB)
        if (bytes.lengthInBytes > 10 * 1024 * 1024) {
          _bulkFailures.add(file.name);
          setState(() => _bulkCompleted++);
          continue;
        }

        final url = await UploadService().uploadBytes(
          folder: 'salons/${widget.salonId}/gallery',
          fileName: file.name,
          bytes: bytes,
          contentType: contentType,
        );

        if (url != null) {
          uploadedUrls.add(url);
        } else {
          _bulkFailures.add(file.name);
        }
      } catch (e) {
        _bulkFailures.add(file.name);
      }
      if (mounted) setState(() => _bulkCompleted++);
    }

    // Save all successfully uploaded URLs at once
    if (uploadedUrls.isNotEmpty) {
      final updatedImages = List<dynamic>.from(_images)..addAll(uploadedUrls);
      final success = await _saveGallery(updatedImages);
      if (success) {
        setState(() => _images = updatedImages);
      } else {
        setState(() => _images = previousImages);
        _showSnackBar('Failed to save photos to gallery', isError: true);
      }
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
        _bulkTotal = 0;
        _bulkCompleted = 0;
      });

      if (_bulkFailures.isNotEmpty) {
        _showSnackBar(
          '${uploadedUrls.length} uploaded, ${_bulkFailures.length} failed',
          isError: _bulkFailures.isNotEmpty && uploadedUrls.isEmpty,
        );
      } else if (uploadedUrls.isNotEmpty) {
        _showSnackBar('${uploadedUrls.length} photos added');
      }
      _bulkFailures = [];
    }
  }

  // ── Viewer ──────────────────────────────────────────────────────────

  void _viewImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageView(imageUrl: imageUrl),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (_images.isNotEmpty && !_isLoading && !_isDeleting && !_isUploading)
            TextButton.icon(
              onPressed: _toggleReorderMode,
              icon: Icon(
                _isReorderMode ? Icons.check : Icons.reorder,
                size: 20,
                color: _isReorderMode ? AppColors.success : AppColors.primary,
              ),
              label: Text(
                _isReorderMode ? 'Done' : 'Reorder',
                style: AppTextStyles.labelMedium.copyWith(
                  color: _isReorderMode ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      body: _buildBody(),
      floatingActionButton:
          _images.isNotEmpty && !_isLoading && !_isDeleting && !_isReorderMode && !_isUploading
              ? FloatingActionButton(
                  onPressed: _onAddImage,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add_a_photo, color: AppColors.white),
                )
              : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SkeletonList(
        count: 6,
        child: SkeletonBox(height: 160, borderRadius: 12),
      );
    }

    if (_isUploading) {
      return _buildUploadProgress();
    }

    if (_isDeleting || _isSaving) {
      return LoadingWidget(
        message: _isDeleting ? 'Removing image...' : 'Saving...',
      );
    }

    if (_images.isEmpty) {
      return _buildEmptyState();
    }

    if (_isReorderMode) {
      return _buildReorderableList();
    }

    return RefreshIndicator(
      onRefresh: _loadGallery,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Gallery grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) => _buildImageCard(index),
          ),
          const SizedBox(height: 16),
          // Gallery tip / nudge
          _buildGalleryTip(),
          const SizedBox(height: 80), // FAB clearance
        ],
      ),
    );
  }

  // ── Upload Progress ─────────────────────────────────────────────────

  Widget _buildUploadProgress() {
    if (_bulkTotal > 1) {
      final progress = _bulkTotal > 0 ? _bulkCompleted / _bulkTotal : 0.0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                    Text(
                      '$_bulkCompleted/$_bulkTotal',
                      style: AppTextStyles.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Uploading photos...', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              Text(
                '$_bulkCompleted of $_bulkTotal complete',
                style: AppTextStyles.bodySmall,
              ),
              if (_bulkFailures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '${_bulkFailures.length} failed',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return const LoadingWidget(message: 'Uploading photo...');
  }

  // ── Empty State (Task 3) ────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add your first photos',
              style: AppTextStyles.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Salons with 5+ photos get 40% more bookings',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _onAddImage,
                icon: const Icon(Icons.add, size: 24, color: AppColors.white),
                label: const Text(
                  'Add Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gallery Tip (Task 4) ────────────────────────────────────────────

  Widget _buildGalleryTip() {
    if (_images.length >= 5) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Great gallery! Your photos help customers choose you.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final needed = 8 - _images.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u{1F4A1}', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add more photos!',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Salons with 8+ photos get 40% more bookings. '
                  'You have ${_images.length} photo${_images.length == 1 ? '' : 's'}. '
                  'Add $needed more to boost visibility.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reorderable List (Task 1) ───────────────────────────────────────

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _images.length,
      onReorder: _onReorder,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scale = 1.0 + 0.05 * animation.value;
            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final imageUrl = _images[index].toString();
        final isCover = _coverImage != null && _coverImage == imageUrl;

        return Container(
          key: ValueKey('reorder_${index}_$imageUrl'),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.drag_handle,
                  color: AppColors.textMuted,
                  size: 24,
                ),
              ),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CachedNetworkImage(
                    imageUrl: ApiConfig.imageUrl(imageUrl) ?? imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AppColors.shimmerBase),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.softSurface,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 24, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photo ${index + 1}',
                      style: AppTextStyles.labelLarge,
                    ),
                    if (isCover)
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: AppColors.ratingStar),
                          const SizedBox(width: 4),
                          Text(
                            'Cover photo',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.ratingStar,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Image Card (Normal Mode) ────────────────────────────────────────

  Widget _buildImageCard(int index) {
    final imageUrl = _images[index].toString();
    final isCover = _coverImage != null && _coverImage == imageUrl;

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
                  child: Container(color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.softSurface,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 32, color: AppColors.textMuted),
                      SizedBox(height: 4),
                      Text('Failed to load',
                          style:
                              TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
              // Gradient overlay at top
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
              // Cover badge (star)
              if (isCover)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.ratingStar,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: AppColors.white),
                        SizedBox(width: 3),
                        Text(
                          'Cover',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Popup menu (delete + set as cover)
              Positioned(
                top: 6,
                right: 6,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'cover') {
                      _setAsCover(imageUrl);
                    } else if (value == 'delete') {
                      _deleteImage(index);
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (ctx) => [
                    if (!isCover)
                      const PopupMenuItem(
                        value: 'cover',
                        child: Row(
                          children: [
                            Icon(Icons.star_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Set as Cover'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_vert,
                      size: 16,
                      color: AppColors.white,
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
