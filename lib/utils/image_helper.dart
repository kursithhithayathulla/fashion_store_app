import 'dart:ui' as ui;
import 'dart:typed_data';

class ImageHelper {
  /// Converts a Google Drive sharing link into a direct image rendering link.
  /// If it is not a Google Drive link, returns the original link as-is.
  static String convertDriveUrl(String url) {
    if (url.isEmpty) return url;
    
    if (!url.contains('drive.google.com') && !url.contains('docs.google.com')) {
      return url;
    }

    // Format: https://drive.google.com/file/d/FILE_ID/view?usp=sharing
    final RegExp fileIdRegExp = RegExp(r'\/file\/d\/([a-zA-Z0-9_-]+)');
    final Match? match = fileIdRegExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final String? fileId = match.group(1);
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://lh3.googleusercontent.com/d/$fileId';
      }
    }

    // Format: https://drive.google.com/open?id=FILE_ID
    final RegExp queryIdRegExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
    final Match? queryMatch = queryIdRegExp.firstMatch(url);
    if (queryMatch != null && queryMatch.groupCount >= 1) {
      final String? fileId = queryMatch.group(1);
      if (fileId != null && fileId.isNotEmpty) {
        return 'https://lh3.googleusercontent.com/d/$fileId';
      }
    }

    return url;
  }

  /// Resizes and compresses image bytes to stay well under the Firestore 1MB limit.
  /// Decodes the image, calculates target sizes to preserve the aspect ratio,
  /// and returns PNG bytes of the resized image.
  static Future<Uint8List> resizeAndCompressImage(Uint8List bytes, {int maxDimension = 256}) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final int width = image.width;
      final int height = image.height;
      
      int targetWidth = width;
      int targetHeight = height;
      
      if (width > height) {
        if (width > maxDimension) {
          targetWidth = maxDimension;
          targetHeight = (height * maxDimension / width).round();
        }
      } else {
        if (height > maxDimension) {
          targetHeight = maxDimension;
          targetWidth = (width * maxDimension / height).round();
        }
      }
      
      // Decode with target width and height to leverage engine-level scaling
      final ui.Codec resizeCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final ui.FrameInfo resizeFrameInfo = await resizeCodec.getNextFrame();
      final ui.Image resizedImage = resizeFrameInfo.image;
      
      final ByteData? byteData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return bytes;
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      // Fallback to original bytes in case of any decoding/resizing issues
      return bytes;
    }
  }
}
