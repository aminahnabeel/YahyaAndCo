import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageUploadService {
  static const String apiKey = '7fdeccce02323c07bc336422b9d64181';
  static const String apiUrl = 'https://api.imgbb.com/1/upload';

  static final ImageUploadService _instance = ImageUploadService._internal();

  factory ImageUploadService() {
    return _instance;
  }

  ImageUploadService._internal();

  Future<String?> uploadImage(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (!file.existsSync()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'key': apiKey,
          'image': base64Image,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'];
        }
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<bool> deleteImage(String deleteUrl) async {
    try {
      final response = await http.get(
        Uri.parse(deleteUrl),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }
}
