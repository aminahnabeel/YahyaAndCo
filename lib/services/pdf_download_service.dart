import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class PdfDownloadService {
  static const MethodChannel _channel = MethodChannel('yahya_and_co/files');

  static Future<String> savePdfToDownloads({
    required List<int> pdfBytes,
    required String fileName,
  }) async {
    try {
      if (Platform.isAndroid) {
        final savedPath = await _channel
            .invokeMethod<String>('savePdf', {
              'fileName': fileName,
              'bytes': Uint8List.fromList(pdfBytes),
            })
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () => throw TimeoutException(
                'Android did not respond while saving the PDF. Please rebuild and reinstall the APK.',
              ),
            );
        if (savedPath == null || savedPath.isEmpty) {
          throw StateError('Android did not return a saved PDF location');
        }
        return savedPath;
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      await File(filePath).writeAsBytes(pdfBytes, flush: true);

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
