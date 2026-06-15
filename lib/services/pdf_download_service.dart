import 'dart:io';
import 'dart:developer' as developer;

class PdfDownloadService {
  /// Save PDF bytes to Downloads folder with Android 10+ scoped storage support
  /// Returns the file path if successful, throws exception on failure
  static Future<String> savePdfToDownloads({
    required List<int> pdfBytes,
    required String fileName,
  }) async {
    try {
      // Get the Downloads directory path
      // On Android 10+, this respects scoped storage with MANAGE_EXTERNAL_STORAGE permission
      final downloadsPath = '/storage/emulated/0/Download';
      final downloadsDir = Directory(downloadsPath);

      // Ensure directory exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Create file path
      final filePath = '$downloadsPath/$fileName';
      final file = File(filePath);

      // Write PDF bytes to file
      await file.writeAsBytes(pdfBytes);

      // Log the successful save for debugging
      developer.log('PDF saved successfully', name: 'PdfDownloadService');
      developer.log('File path: $filePath', name: 'PdfDownloadService');

      return filePath;
    } catch (e) {
      developer.log(
        'Error saving PDF',
        name: 'PdfDownloadService',
        error: e,
        stackTrace: StackTrace.current,
      );
      rethrow;
    }
  }
}
