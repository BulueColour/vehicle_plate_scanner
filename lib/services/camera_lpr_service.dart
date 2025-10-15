import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CameraLPRService {
  // ⚠️ เปลี่ยน URL นี้เป็น Backend ของคุณ
  // ตัวอย่าง: 'http://192.168.1.100:8000' หรือ 'https://your-api.com'
  static const String baseUrl = 'http://10.0.2.2:8000';
  
  /// ส่งภาพไปยัง Backend เพื่อตรวจจับและอ่านป้ายทะเบียน
  static Future<Map<String, dynamic>> detectLicensePlate(File imageFile) async {
    try {
      if (kDebugMode) {
        print('📤 Sending image to: $baseUrl/detect');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/detect'),
      );

      // แนบไฟล์ภาพ (field name ต้องตรงกับที่ Backend ต้องการ เช่น 'file')
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // ⚠️ ต้องตรงกับชื่อ parameter ใน Backend
          imageFile.path,
        ),
      );

      // ส่ง request พร้อม timeout
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - Backend ไม่ตอบกลับภายใน 30 วินาที');
        },
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        Map<String, dynamic> result = json.decode(response.body);
        
        // ⚠️ ปรับตามโครงสร้าง JSON ที่ Backend ส่งกลับ
        // กรณีที่ 1: Backend ส่ง combined_text
        if (result.containsKey('combined_text')) {
          return {
            'success': true,
            'combined_text': result['combined_text'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'message': result['message'] ?? 'ตรวจจับสำเร็จ',
          };
        }
        
        // กรณีที่ 2: Backend ส่ง plate_number และ province แยกกัน
        else if (result.containsKey('plate_number')) {
          String plateNumber = result['plate_number'] ?? '';
          String province = result['province'] ?? '';
          String combined = '$plateNumber ${province.isNotEmpty ? province : ""}'.trim();
          
          return {
            'success': true,
            'combined_text': combined,
            'plate_number': plateNumber,
            'province': province,
            'confidence': result['confidence'] ?? 0.0,
            'message': result['message'] ?? 'ตรวจจับสำเร็จ',
          };
        }
        
        // กรณีที่ 3: Backend ส่ง text หรือชื่ออื่น
        else if (result.containsKey('text')) {
          return {
            'success': true,
            'combined_text': result['text'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'message': result['message'] ?? 'ตรวจจับสำเร็จ',
          };
        }
        
        // ถ้าไม่มี field ที่คาดหวัง
        else {
          return {
            'success': false,
            'combined_text': '',
            'confidence': 0.0,
            'message': 'Backend ส่ง format ไม่ถูกต้อง: ${result.keys.join(", ")}',
          };
        }
      } else if (response.statusCode == 400) {
        // Bad Request - อาจเป็นภาพไม่ถูกต้องหรือไม่พบป้ายทะเบียน
        try {
          Map<String, dynamic> error = json.decode(response.body);
          return {
            'success': false,
            'combined_text': '',
            'confidence': 0.0,
            'message': error['message'] ?? error['detail'] ?? 'ไม่พบป้ายทะเบียนในภาพ',
          };
        } catch (e) {
          return {
            'success': false,
            'combined_text': '',
            'confidence': 0.0,
            'message': 'ไม่พบป้ายทะเบียนในภาพ',
          };
        }
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'combined_text': '',
          'confidence': 0.0,
          'message': 'เกิดข้อผิดพลาดจาก Server (500)',
        };
      } else {
        return {
          'success': false,
          'combined_text': '',
          'confidence': 0.0,
          'message': 'เกิดข้อผิดพลาดจาก Server (${response.statusCode})',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'combined_text': '',
        'confidence': 0.0,
        'message': 'ไม่สามารถเชื่อมต่อกับ Server ได้ กรุณาตรวจสอบ:\n1. URL ถูกต้องหรือไม่\n2. Backend เปิดอยู่หรือไม่\n3. อินเทอร์เน็ตเชื่อมต่ออยู่หรือไม่',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'combined_text': '',
        'confidence': 0.0,
        'message': 'เกิดข้อผิดพลาดในการส่งข้อมูล: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ API Error: $e');
      }
      return {
        'success': false,
        'combined_text': '',
        'confidence': 0.0,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// ตรวจสอบสถานะ API (Health Check)
  static Future<bool> checkApiHealth() async {
    try {
      if (kDebugMode) {
        print('🔍 Checking API health: $baseUrl/health');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      bool isHealthy = response.statusCode == 200;
      
      if (kDebugMode) {
        print(isHealthy ? '✅ API is healthy' : '❌ API is not healthy');
      }
      
      return isHealthy;
    } on SocketException {
      if (kDebugMode) {
        print('❌ Cannot connect to API');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Health check failed: $e');
      }
      return false;
    }
  }
}