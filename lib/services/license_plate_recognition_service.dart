import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class LicensePlateRecognitionService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  static Future<Map<String, dynamic>> detectLicensePlate(File imageFile) async {
    try {
      print('Using URL: $baseUrl');
      
      // ทดสอบ health check ก่อน
      print('Checking API health...');
      final healthResponse = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      if (healthResponse.statusCode != 200) {
        throw Exception('API Health check failed: ${healthResponse.statusCode}');
      }
      
      print('API Health check successful');
      
      // ปรับขนาดรูปภาพ
      File optimizedImage = await _optimizeImage(imageFile);
      print('Image optimized');
      
      // ส่งรูปภาพไป API
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect-license-plate'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', optimizedImage.path),
      );
      
      print('Sending request to API...');
      var response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      
      var responseData = await response.stream.bytesToString();
      print('Response received: ${response.statusCode}');
      print('Response data: $responseData');
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('API Error: ${response.statusCode} - $responseData');
      }
      
    } catch (e) {
      print('Error in detectLicensePlate: $e');
      throw Exception('การตรวจจับป้ายทะเบียนล้มเหลว: $e');
    }
  }
  
  static Future<File> _optimizeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image != null) {
        if (image.width > 1024 || image.height > 1024) {
          image = img.copyResize(image, width: 1024);
        }
        
        final tempDir = await getTemporaryDirectory();
        final fileName = 'optimized_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newFile = File(path.join(tempDir.path, fileName));
        
        final optimizedBytes = img.encodeJpg(image, quality: 85);
        await newFile.writeAsBytes(optimizedBytes);
        
        return newFile;
      }
      return imageFile;
    } catch (e) {
      print('Error optimizing image: $e');
      return imageFile;
    }
  }
  
  static Future<bool> checkApiHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      print('Health check response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('API Health check failed: $e');
      return false;
    }
  }
  
  static String cleanLicensePlateText(String rawText) {
    String cleaned = rawText.replaceAll(RegExp(r'[^\u0E00-\u0E7F0-9]'), '');
    RegExp pattern = RegExp(r'(\d{1,2})([ก-ฮ]{1,3})(\d{1,4})');
    RegExpMatch? match = pattern.firstMatch(cleaned);
    
    if (match != null) {
      String digits1 = match.group(1) ?? '';
      String thaiLetters = match.group(2) ?? '';
      String digits2 = match.group(3) ?? '';
      return '$digits1$thaiLetters$digits2';
    }
    
    return cleaned.length > 10 ? cleaned.substring(0, 10) : cleaned;
  }
}