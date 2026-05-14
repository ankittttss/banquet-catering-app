import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_text_styles.dart';

/// Outcome of the photo picker sheet. The caller decides what to do —
/// the sheet itself never touches the network.
sealed class PhotoPickerResult {
  const PhotoPickerResult();
}

class PhotoPickedBytes extends PhotoPickerResult {
  const PhotoPickedBytes(this.bytes);
  final Uint8List bytes;
}

class PhotoRemoved extends PhotoPickerResult {
  const PhotoRemoved();
}

class PhotoPickerCancelled extends PhotoPickerResult {
  const PhotoPickerCancelled();
}

class PhotoPickerError extends PhotoPickerResult {
  const PhotoPickerError(this.message);
  final String message;
}

/// Shows a bottom sheet with Camera / Gallery / Remove options and
/// returns the picked + compressed bytes (~50–150 KB JPEG) or a
/// [PhotoRemoved] / [PhotoPickerCancelled] result.
///
/// [hasExisting] hides the "Remove photo" row when the user has no
/// avatar set yet.
Future<PhotoPickerResult> showPhotoPickerSheet(
  BuildContext context, {
  bool hasExisting = false,
}) async {
  final result = await showModalBottomSheet<PhotoPickerResult>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PhotoSheet(hasExisting: hasExisting),
  );
  return result ?? const PhotoPickerCancelled();
}

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.hasExisting});
  final bool hasExisting;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    HapticFeedback.selectionClick();
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        // image_picker re-encodes to JPEG with these limits applied on
        // the platform side, so we get a manageable file before our
        // own compression pass.
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (xfile == null) {
        if (context.mounted) Navigator.pop(context, const PhotoPickerCancelled());
        return;
      }

      final raw = await xfile.readAsBytes();
      // Second-pass compression for predictable sizes (~50–150 KB).
      // Web doesn't support flutter_image_compress, so fall back to
      // the picker's already-shrunk bytes there.
      Uint8List bytes;
      try {
        bytes = await FlutterImageCompress.compressWithList(
          raw,
          minWidth: 800,
          minHeight: 800,
          quality: 85,
          format: CompressFormat.jpeg,
        );
      } catch (_) {
        bytes = raw;
      }

      if (context.mounted) {
        Navigator.pop(context, PhotoPickedBytes(bytes));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context, PhotoPickerError('$e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Profile photo',
                style: AppTextStyles.heading2,
              ),
            ),
            _OptionRow(
              icon: Icons.photo_camera_rounded,
              iconBg: const Color(0xFFEBF4FF),
              iconColor: const Color(0xFF2B6CB0),
              label: 'Take photo',
              onTap: () => _pick(context, ImageSource.camera),
            ),
            _OptionRow(
              icon: Icons.photo_library_rounded,
              iconBg: const Color(0xFFEAFAF1),
              iconColor: const Color(0xFF1BA672),
              label: 'Choose from gallery',
              onTap: () => _pick(context, ImageSource.gallery),
            ),
            if (hasExisting)
              _OptionRow(
                icon: Icons.delete_outline_rounded,
                iconBg: const Color(0xFFFFF1F2),
                iconColor: AppColors.primary,
                label: 'Remove photo',
                labelColor: AppColors.primary,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, const PhotoRemoved());
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.labelColor,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pagePadding, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
