import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import '../theme/glass_widgets.dart';
import '../theme/palm_icon.dart';

/// Shows a farm photo from any source the app uses:
/// a web address saved in Firebase, an asset, or a file just picked from the phone.
/// When there is no photo (or it cannot be loaded) a palm placeholder is shown.
class FarmImageView extends StatelessWidget {
  /// Web address (https://...), asset path (assets/...), local file path, or empty.
  final String path;
  final double height;
  final double? width;

  const FarmImageView({
    super.key,
    required this.path,
    this.height = 170,
    this.width = double.infinity,
  });

  /// Placeholder shown when there is no photo or it fails to load.
  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.beige,
      alignment: Alignment.center,
      child: PalmIcon(size: height < 100 ? 34 : 52, color: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return _placeholder();

    // Photo saved in Firebase Storage.
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // Spinner while the photo downloads.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // Photo bundled with the app.
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // Photo just chosen on this phone (not uploaded yet).
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}

/// Lets the user take a photo or choose one from the gallery.
class FarmPhotoPicker {
  FarmPhotoPicker._();

  /// Biggest photo size accepted (same limit as the Firebase Storage rules).
  static const int maxBytes = 5 * 1024 * 1024;

  static const List<String> allowedTypes = ['jpg', 'jpeg', 'png', 'webp'];

  /// Opens the Camera / Gallery choice and returns the chosen file path.
  /// Returns null if the user cancels or the photo is not accepted
  /// (an error pop-up explains why).
  static Future<String?> choose(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return null;

    XFile? picked;
    try {
      // The photo is shrunk first so it uploads quickly on a slow connection.
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (context.mounted) {
        showCenterMessage(
          context,
          'Allow access to the camera or photos in your phone settings, then try again.',
          success: false,
          title: 'Photo not added',
        );
      }
      return null;
    }
    if (picked == null || !context.mounted) return null;

    // Check the file type.
    final extension = picked.path.toLowerCase().split('.').last;
    if (!allowedTypes.contains(extension)) {
      showCenterMessage(
        context,
        'Choose a JPG, PNG or WebP photo.',
        success: false,
        title: 'Photo not added',
      );
      return null;
    }

    // Check the file size.
    if (await File(picked.path).length() >= maxBytes) {
      if (!context.mounted) return null;
      showCenterMessage(
        context,
        'The photo must be smaller than 5 MB.',
        success: false,
        title: 'Photo not added',
      );
      return null;
    }

    return picked.path;
  }
}

/// The "Farm Photo" box used by Add Farm and Farm Settings.
/// Empty: shows "Add farm photo". With a photo: shows it with Change / Remove.
class FarmPhotoBox extends StatelessWidget {
  final String imagePath;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const FarmPhotoBox({
    super.key,
    required this.imagePath,
    required this.onChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // No photo yet: tap anywhere on the box to add one.
    if (imagePath.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onChange,
        child: Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7F4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9DB8A5), width: 1.5),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
              SizedBox(height: 6),
              Text(
                'Add farm photo',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'JPG, PNG or WebP, up to 5 MB',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Photo chosen: show it with Change and Remove buttons on top.
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FarmImageView(path: imagePath, height: 170),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PhotoButton(
                icon: Icons.edit_outlined,
                label: 'Change',
                color: AppColors.primary,
                onTap: onChange,
              ),
              const SizedBox(width: 8),
              _PhotoButton(
                icon: Icons.delete_outline,
                label: 'Remove',
                color: AppColors.error,
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small white button drawn on top of the photo.
class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
