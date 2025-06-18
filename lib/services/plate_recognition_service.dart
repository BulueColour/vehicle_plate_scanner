// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:image/image.dart' as img;
// import 'package:image_picker/image_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

// class PlateRecognitionService {
//   // Text recognizers
//   final TextRecognizer _textRecognizer = TextRecognizer();

//   /// ประมวลผลภาพและดึงเลขทะเบียน
//   Future<String?> processImage(XFile imageFile) async {
//     try {
//       print('🔍 เริ่มประมวลผลภาพ: ${imageFile.path}');
      
//       // Method 1: ลองใช้ Google ML Kit ก่อน
//       String? mlKitResult = await _processWithMLKit(imageFile);
//       if (mlKitResult != null) {
//         print('✅ ML Kit พบป้ายทะเบียน: $mlKitResult');
//         return mlKitResult;
//       }
      
//       // Method 2: ใช้ Tesseract OCR
//       String? tesseractResult = await _processWithTesseract(imageFile);
//       if (tesseractResult != null) {
//         print('✅ Tesseract พบป้ายทะเบียน: $tesseractResult');
//         return tesseractResult;
//       }
      
//       print('❌ ไม่พบป้ายทะเบียน');
//       return null;
      
//     } catch (e) {
//       print('❌ Error processing image: $e');
//       return null;
//     }
//   }
  
//   /// ประมวลผลด้วย Google ML Kit
//   Future<String?> _processWithMLKit(XFile imageFile) async {
//     try {
//       final inputImage = InputImage.fromFilePath(imageFile.path);
      
//       // ลองทั้ง default และ Thai recognizer
//       final recognizedText = await _textRecognizer.processImage(inputImage);
      
//       // รวม text ทั้งหมด
//       String allText = recognizedText.text;
//       print('📝 ML Kit OCR: $allText');
      
//       // หาเลขทะเบียน
//       return _extractPlateNumber(allText);
      
//     } catch (e) {
//       print('❌ ML Kit error: $e');
//       return null;
//     }
//   }
  
//   /// ประมวลผลด้วย Tesseract OCR
//   Future<String?> _processWithTesseract(XFile imageFile) async {
//     try {
//       // Preprocess image ก่อน
//       File? processedFile = await _preprocessImage(imageFile);
//       String imagePath = processedFile?.path ?? imageFile.path;
      
//       // OCR ด้วย Tesseract
//       String? extractedText = await FlutterTesseractOcr.extractText(
//         imagePath,
//         language: 'tha+eng',
//         args: {
//           "psm": "6", // Uniform block of text
//           "preserve_interword_spaces": "1",
//           "tessedit_char_whitelist": "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ0123456789 -",
//         },
//       );
      
//       // Clean up
//       if (processedFile != null) {
//         await processedFile.delete();
//       }
      
//       print('📝 Tesseract OCR: $extractedText');
      
//       // หาเลขทะเบียน
//       return _extractPlateNumber(extractedText ?? '');
      
//     } catch (e) {
//       print('❌ Tesseract error: $e');
//       return null;
//     }
//   }
  
//   /// Preprocess ภาพเพื่อเพิ่มประสิทธิภาพ OCR
//   Future<File?> _preprocessImage(XFile imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       img.Image? image = img.decodeImage(bytes);
//       if (image == null) return null;
      
//       // Resize ถ้าภาพใหญ่เกินไป
//       if (image.width > 1000) {
//         double scale = 1000 / image.width;
//         image = img.copyResize(image, 
//           width: 1000,
//           height: (image.height * scale).round()
//         );
//       }
      
//       // Convert to grayscale
//       image = img.grayscale(image);
      
//       // Increase contrast
//       image = img.adjustColor(image, contrast: 1.5);
      
//       // Save processed image
//       final directory = await getTemporaryDirectory();
//       final path = '${directory.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
//       final processedFile = File(path);
//       await processedFile.writeAsBytes(img.encodeJpg(image, quality: 95));
      
//       return processedFile;
      
//     } catch (e) {
//       print('❌ Error preprocessing image: $e');
//       return null;
//     }
//   }
  
//   /// แยกเลขทะเบียนจากข้อความ
//   String? _extractPlateNumber(String text) {
//     if (text.isEmpty) return null;
    
//     // ทำความสะอาดข้อความ
//     String cleanText = text
//         .replaceAll('\n', ' ')
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .trim();
    
//     // แก้ตัวอักษรที่อ่านผิดบ่อย
//     cleanText = _fixCommonOCRErrors(cleanText);
    
//     // กรองเอาเฉพาะอักษรไทยและตัวเลข
//     cleanText = _keepOnlyThaiAndNumbers(cleanText);
    
//     print('📝 Clean text: $cleanText');
    
//     // Pattern สำหรับป้ายทะเบียนไทย
//     List<RegExp> patterns = [
//       // รถยนต์ทั่วไป: กข 1234
//       RegExp(r'([ก-ฮ]{1,2})\s*(\d{1,4})'),
//       // รถพิเศษ: 1กก 9999
//       RegExp(r'(\d{1,2})\s*([ก-ฮ]{1,2})\s*(\d{1,4})'),
//       // แค่อักษร: ก 1234
//       RegExp(r'([ก-ฮ])\s*(\d{4})'),
//     ];
    
//     // ค้นหา pattern ที่ match
//     for (RegExp pattern in patterns) {
//       final matches = pattern.allMatches(cleanText);
//       if (matches.isNotEmpty) {
//         String plateNumber = matches.first.group(0)!.trim();
        
//         // จัดรูปแบบให้สวย
//         plateNumber = _formatPlateNumber(plateNumber);
        
//         // หาจังหวัด
//         String? province = _extractProvince(cleanText);
        
//         // รวมเลขทะเบียนกับจังหวัด
//         if (province != null) {
//           return '$plateNumber $province';
//         }
        
//         return plateNumber;
//       }
//     }
    
//     return null;
//   }
  
//   /// กรองเฉพาะอักษรไทยและตัวเลข
//   String _keepOnlyThaiAndNumbers(String text) {
//     return text
//         .replaceAll(RegExp(r'[^ก-ฮ0-9\s]'), ' ')
//         .replaceAll(RegExp(r'\s+'), ' ')
//         .trim();
//   }
  
//   /// แก้ OCR errors ที่พบบ่อย
//   String _fixCommonOCRErrors(String text) {
//     Map<String, String> replacements = {
//       // เลขไทยเป็นเลขอารบิก
//       '๐': '0', '๑': '1', '๒': '2', '๓': '3', '๔': '4',
//       '๕': '5', '๖': '6', '๗': '7', '๘': '8', '๙': '9',
//       // ตัวอักษรที่มักอ่านผิด
//       'O': '0', 'o': '0', 'I': '1', 'l': '1',
//       'Z': '2', 'S': '5', 's': '5', 'G': '6',
//       // อักษรไทยที่มักสับสน
//       'ฤ': 'ร', 'ฦ': 'ล',
//     };
    
//     String fixed = text;
//     replacements.forEach((key, value) {
//       fixed = fixed.replaceAll(key, value);
//     });
    
//     return fixed;
//   }
  
//   /// จัดรูปแบบเลขทะเบียน
//   String _formatPlateNumber(String plate) {
//     // ลบ space ทั้งหมด
//     String clean = plate.replaceAll(' ', '');
    
//     // แยกตัวอักษรและตัวเลข
//     final thaiLetters = RegExp(r'[ก-ฮ]+');
//     final numbers = RegExp(r'\d+');
    
//     // หาตัวอักษรไทย
//     final letterMatch = thaiLetters.firstMatch(clean);
//     if (letterMatch == null) return plate;
    
//     String letters = letterMatch.group(0)!;
    
//     // หาตัวเลข
//     final numberMatches = numbers.allMatches(clean).toList();
//     if (numberMatches.isEmpty) return letters;
    
//     // ถ้ามีเลขนำหน้า (1กก 9999)
//     if (clean.startsWith(RegExp(r'\d'))) {
//       String leadingNumber = numberMatches.first.group(0)!;
//       String trailingNumber = numberMatches.length > 1 ? numberMatches[1].group(0)! : '';
//       return '$leadingNumber$letters $trailingNumber'.trim();
//     }
    
//     // ป้ายทะเบียนปกติ (กข 1234)
//     String mainNumber = numberMatches.first.group(0)!;
//     return '$letters $mainNumber';
//   }
  
//   /// หาจังหวัดจากข้อความ
//   String? _extractProvince(String text) {
//     // รายชื่อจังหวัด (เพิ่มได้ตามต้องการ)
//     List<String> provinces = [
//       // ภาคกลาง
//       'กรุงเทพมหานคร', 'กำแพงเพชร', 'ชัยนาท', 'นครนายก', 'นครปฐม',
//       'นครสวรรค์', 'นนทบุรี', 'ปทุมธานี', 'พระนครศรีอยุธยา', 'พิจิตร',
//       'พิษณุโลก', 'เพชรบูรณ์', 'ลพบุรี', 'สมุทรปราการ', 'สมุทรสงคราม',
//       'สมุทรสาคร', 'สระบุรี', 'สิงห์บุรี', 'สุโขทัย', 'สุพรรณบุรี',
//       'อ่างทอง', 'อุทัยธานี',
      
//       // ภาคเหนือ
//       'เชียงราย', 'เชียงใหม่', 'น่าน', 'พะเยา', 'แพร่', 'แม่ฮ่องสอน',
//       'ลำปาง', 'ลำพูน', 'อุตรดิตถ์',
      
//       // ภาคตะวันออกเฉียงเหนือ
//       'กาฬสินธุ์', 'ขอนแก่น', 'ชัยภูมิ', 'นครพนม', 'นครราชสีมา',
//       'บึงกาฬ', 'บุรีรัมย์', 'มหาสารคาม', 'มุกดาหาร', 'ยโสธร',
//       'ร้อยเอ็ด', 'เลย', 'ศรีสะเกษ', 'สกลนคร', 'สุรินทร์',
//       'หนองคาย', 'หนองบัวลำภู', 'อุดรธานี', 'อุบลราชธานี', 'อำนาจเจริญ',
      
//       // ภาคตะวันออก
//       'จันทบุรี', 'ฉะเชิงเทรา', 'ชลบุรี', 'ตราด', 'ปราจีนบุรี',
//       'ระยอง', 'สระแก้ว',
      
//       // ภาคตะวันตก
//       'กาญจนบุรี', 'ตาก', 'ประจวบคีรีขันธ์', 'เพชรบุรี', 'ราชบุรี',
      
//       // ภาคใต้
//       'กระบี่', 'ชุมพร', 'ตรัง', 'นครศรีธรรมราช', 'นราธิวาส',
//       'ปัตตานี', 'พังงา', 'พัทลุง', 'ภูเก็ต', 'ยะลา',
//       'ระนอง', 'สงขลา', 'สตูล', 'สุราษฎร์ธานี',
//     ];
    
//     // คำย่อจังหวัด
//     Map<String, String> abbreviations = {
//       'กทม': 'กรุงเทพมหานคร',
//       'นครราช': 'นครราชสีมา', 
//       'นครศรี': 'นครศรีธรรมราช',
//       'อยุธยา': 'พระนครศรีอยุธยา',
//     };
    
//     String lowerText = text.toLowerCase();
    
//     // ตรวจสอบคำย่อก่อน
//     for (var entry in abbreviations.entries) {
//       if (lowerText.contains(entry.key.toLowerCase())) {
//         return entry.value;
//       }
//     }
    
//     // เรียงจากยาวไปสั้น
//     provinces.sort((a, b) => b.length.compareTo(a.length));
    
//     // ค้นหาจังหวัด
//     for (String province in provinces) {
//       if (lowerText.contains(province.toLowerCase())) {
//         return province;
//       }
//     }
    
//     return null;
//   }
  
//   /// ทำความสะอาด resources
//   void dispose() {
//     _textRecognizer.close();
//   }
// }