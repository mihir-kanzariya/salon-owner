import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import '../config/api_config.dart';

enum UploadPreset { avatar, cover, gallery }

class _PresetConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;

  const _PresetConfig(this.maxWidth, this.maxHeight, this.quality);
}

const _presets = {
  UploadPreset.avatar: _PresetConfig(400, 400, 85),
  UploadPreset.cover: _PresetConfig(1200, 800, 70),
  UploadPreset.gallery: _PresetConfig(1080, 1080, 70),
};

class UploadService {
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final _api = ApiService();
  final _picker = ImagePicker();

  /// Pick image from gallery or camera, upload to Wasabi, return public URL.
  Future<String?> pickAndUpload({
    required String folder,
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1200,
    int maxHeight = 1200,
    int imageQuality = 80,
    UploadPreset? preset,
  }) async {
    final config = preset != null ? _presets[preset] : null;
    final effectiveWidth = config?.maxWidth ?? maxWidth;
    final effectiveHeight = config?.maxHeight ?? maxHeight;
    final effectiveQuality = config?.quality ?? imageQuality;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: effectiveWidth.toDouble(),
      maxHeight: effectiveHeight.toDouble(),
      imageQuality: effectiveQuality,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final contentType = _mimeType(file.name);

    return uploadBytes(
      folder: folder,
      fileName: file.name,
      bytes: bytes,
      contentType: contentType,
    );
  }

  /// Upload raw bytes to Wasabi via presigned URL. Returns public URL.
  Future<String?> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // 1. Get presigned URL from backend
    final res = await _api.post(
      ApiConfig.presignedUrl,
      body: {
        'folder': folder,
        'fileName': fileName,
        'contentType': contentType,
      },
    );

    final data = res['data'];
    final uploadUrl = data['uploadUrl'] as String;
    final publicUrl = data['publicUrl'] as String;

    // 2. PUT to presigned URL
    final uploadRes = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (uploadRes.statusCode >= 200 && uploadRes.statusCode < 300) {
      return publicUrl;
    }

    throw Exception('Upload failed: ${uploadRes.statusCode}');
  }

  String _mimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
