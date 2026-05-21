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
}
