import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'yolo_detection_service.dart';

class PlateRecognitionService {
  // YOLO service สำหรับหาป้ายทะเบียน
  final YoloDetectionService _yoloService = YoloDetectionService();

  // Text recognizer สำหรับ OCR (backup)
  final TextRecognizer _textRecognizer = TextRecognizer();

  // Object detector สำหรับหาป้ายทะเบียน (backup)
  late final ObjectDetector _objectDetector;

  PlateRecognitionService() {
    // Initialize services
    _initialize();

    // Initialize object detector as backup
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: false,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  /// Initialize YOLO service
  Future<void> _initialize() async {
    try {
      await _yoloService.initialize();
      print('✅ YOLO service initialized');
    } catch (e) {
      print('❌ Failed to initialize YOLO: $e');
    }
  }

  /// ประมวลผลภาพและดึงเลขทะเบียน (ใช้ YOLO + OCR)
  Future<String?> processImage(XFile imageFile) async {
    try {
      print('🔍 เริ่มประมวลผลภาพ: ${imageFile.path}');

      // Step 1: ใช้ YOLO หาป้ายทะเบียน
      List<Detection> detections =
          await _yoloService.detectLicensePlates(imageFile);

      if (detections.isEmpty) {
        print('❌ YOLO ไม่พบป้ายทะเบียน - ใช้ OCR ทั้งภาพ');
        // Fallback: ถ้า YOLO ไม่เจอ ให้ OCR ทั้งภาพ
        return await _processFullImage(imageFile);
      }

      // Step 2: เลือก detection ที่มั่นใจที่สุด
      Detection bestDetection =
          detections.reduce((a, b) => a.confidence > b.confidence ? a : b);

      print('📍 พบป้ายทะเบียน: ${bestDetection}');

      // Step 3: Crop ป้ายทะเบียน
      File? croppedFile =
          await _yoloService.cropDetection(imageFile, bestDetection);

      if (croppedFile == null) {
        print('❌ ไม่สามารถ crop ได้ - ใช้ OCR ทั้งภาพ');
        return await _processFullImage(imageFile);
      }

      // Step 4: Preprocess ภาพที่ crop แล้ว
      File? processedFile = await _enhanceImageForOCR(croppedFile);

      // Step 5: OCR ด้วย Tesseract
      String? extractedText = await FlutterTesseractOcr.extractText(
        processedFile?.path ?? croppedFile.path,
        language: 'tha+eng', // ภาษาไทย + อังกฤษ
        args: {
          "psm": "8", // Treat as single line
          "preserve_interword_spaces": "1",
          "tessedit_char_whitelist":
              "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ0123456789 ",
        },
      );

      print('📝 OCR Result: $extractedText');

      // Step 6: Clean up temp files
      await croppedFile.delete();
      if (processedFile != null) await processedFile.delete();

      // Step 7: กรองและจัดรูปแบบเลขทะเบียน
      String? plateNumber = _extractPlateNumber(extractedText ?? '');

      print('✅ ผลลัพธ์: $plateNumber');
      return plateNumber;
    } catch (e) {
      print('❌ Error processing image: $e');
      return null;
    }
  }

  /// Process full image without YOLO (fallback)
  Future<String?> _processFullImage(XFile imageFile) async {
    try {
      // Preprocess ภาพก่อน OCR
      File? processedFile = await preprocessImage(imageFile);

      String? extractedText = await FlutterTesseractOcr.extractText(
        processedFile?.path ?? imageFile.path,
        language: 'tha+eng',
        args: {
          "psm": "6", // Uniform block of text
          "preserve_interword_spaces": "1",
          "tessedit_char_whitelist":
              "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ0123456789 ",
        },
      );

      if (processedFile != null) await processedFile.delete();

      return _extractPlateNumber(extractedText ?? '');
    } catch (e) {
      print('❌ Error in fallback OCR: $e');
      return null;
    }
  }

  /// Enhance image specifically for OCR
  Future<File?> _enhanceImageForOCR(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize if too small
      // Resize if too small
      if (image.width < 300) {
        double scale = 300 / image.width;
        image = img.copyResize(image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
            interpolation: img.Interpolation.cubic);
      }

      // Convert to grayscale
      image = img.grayscale(image);

      // Increase contrast
      image = img.adjustColor(image, contrast: 1.8, brightness: 1.1);

      // Apply slight blur to reduce noise
      image = img.gaussianBlur(image, radius: 1);

      // Sharpen
      // Sharpen
      image = img.convolution(image,
          filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1, offset: 0);

      // Save enhanced image
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final enhancedFile = File(path);
      await enhancedFile.writeAsBytes(img.encodeJpg(image, quality: 95));

      return enhancedFile;
    } catch (e) {
      print('❌ Error enhancing image: $e');
      return null;
    }
  }

  /// ครอปภาพป้ายทะเบียน (สำหรับการพัฒนาต่อ)
  Future<File?> cropLicensePlate(XFile imageFile, Rect plateArea) async {
    try {
      // อ่านภาพ
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // ครอปภาพ
      img.Image cropped = img.copyCrop(
        image,
        x: plateArea.left.toInt(),
        y: plateArea.top.toInt(),
        width: plateArea.width.toInt(),
        height: plateArea.height.toInt(),
      );

      // บันทึกภาพที่ครอป
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/cropped_plate_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final croppedFile = File(path);
      await croppedFile.writeAsBytes(img.encodeJpg(cropped));

      return croppedFile;
    } catch (e) {
      print('❌ Error cropping image: $e');
      return null;
    }
  }

  /// แยกเลขทะเบียนจากข้อความที่ OCR ได้
  String? _extractPlateNumber(String text) {
    print('📝 ข้อความที่ OCR ได้: $text');

    // ลบช่องว่างและขึ้นบรรทัดใหม่
    String cleanText = text.replaceAll('\n', ' ').trim();

    // กรองเอาเฉพาะอักษรไทยและตัวเลข
    cleanText = _keepOnlyThaiAndNumbers(cleanText);
    print('📝 ข้อความหลังกรอง: $cleanText');

    // ดึงข้อมูลป้ายทะเบียน
    Map<String, String>? plateData = _extractPlateData(cleanText);

    if (plateData != null) {
      String result = plateData['plate']!;

      // เพิ่มจังหวัดถ้าพบ
      if (plateData['province'] != null && plateData['province']!.isNotEmpty) {
        result += ' ${plateData['province']}';
      }

      return result;
    }

    return null;
  }

  // เพิ่มฟังก์ชันกรองเฉพาะอักษรไทยและตัวเลข
  String _keepOnlyThaiAndNumbers(String text) {
    // เก็บเฉพาะ: อักษรไทย (ก-ฮ), ตัวเลข (0-9), และ space
    return text
        .replaceAll(RegExp(r'[^ก-ฮ0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ฟังก์ชันใหม่สำหรับดึงข้อมูลป้ายทะเบียนและจังหวัด
  Map<String, String>? _extractPlateData(String text) {
    // Pattern สำหรับป้ายทะเบียนไทย (เฉพาะภาษาไทยและตัวเลข)
    List<RegExp> platePatterns = [
      // ป้ายทะเบียนรถยนต์ทั่วไป
      RegExp(r'([ก-ฮ]{1,2})\s*(\d{1,4})'), // กข 1234
      RegExp(r'(\d{1,2})\s*([ก-ฮ]{1,2})\s*(\d{1,4})'), // 1กก 9999
      RegExp(r'([ก-ฮ])\s*(\d{4})'), // ก 1234
    ];

    String? plateNumber;
    String? province;

    // หาเลขทะเบียน
    for (RegExp pattern in platePatterns) {
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        plateNumber = matches.first.group(0)?.trim();

        // จัดรูปแบบให้สวยงาม
        if (plateNumber != null) {
          plateNumber = _formatPlateNumber(plateNumber);
        }
        break;
      }
    }

    // หาจังหวัดจากข้อความ
    province = _extractProvinceFromText(text);

    if (plateNumber != null) {
      return {
        'plate': plateNumber,
        'province': province ?? '',
      };
    }

    return null;
  }

  // จัดรูปแบบเลขทะเบียนให้สวยงาม
  String _formatPlateNumber(String plate) {
    // ลบ space ทั้งหมดก่อน
    String clean = plate.replaceAll(' ', '');

    // แยกตัวอักษรและตัวเลข
    final thaiLetters = RegExp(r'[ก-ฮ]+');
    final numbers = RegExp(r'\d+');

    // หาตัวอักษรไทย
    final letterMatch = thaiLetters.firstMatch(clean);
    if (letterMatch == null) return plate;

    String letters = letterMatch.group(0)!;
    String remaining = clean.substring(letterMatch.end);

    // หาตัวเลข
    final numberMatch = numbers.firstMatch(remaining);
    if (numberMatch == null) return '$letters $remaining'.trim();

    String firstNumbers = numberMatch.group(0)!;

    // ถ้ามีตัวเลขนำหน้า (เช่น 1กก 9999)
    if (clean.startsWith(RegExp(r'\d'))) {
      final leadingNumber = numbers.firstMatch(clean)?.group(0) ?? '';
      return '$leadingNumber$letters $firstNumbers'.trim();
    }

    // ป้ายทะเบียนปกติ (กข 1234)
    return '$letters $firstNumbers'.trim();
  }

  // ปรับปรุงฟังก์ชันหาจังหวัด
  String? _extractProvinceFromText(String text) {
    // รายชื่อจังหวัดทั้งหมด 77 จังหวัด
    List<String> provinces = [
      // ภาคกลาง
      'กรุงเทพมหานคร', 'กำแพงเพชร', 'ชัยนาท', 'นครนายก', 'นครปฐม',
      'นครสวรรค์', 'นนทบุรี', 'ปทุมธานี', 'พระนครศรีอยุธยา', 'พิจิตร',
      'พิษณุโลก', 'เพชรบูรณ์', 'ลพบุรี', 'สมุทรปราการ', 'สมุทรสงคราม',
      'สมุทรสาคร', 'สระบุรี', 'สิงห์บุรี', 'สุโขทัย', 'สุพรรณบุรี',
      'อ่างทอง', 'อุทัยธานี',

      // ภาคเหนือ
      'เชียงราย', 'เชียงใหม่', 'น่าน', 'พะเยา', 'แพร่', 'แม่ฮ่องสอน',
      'ลำปาง', 'ลำพูน', 'อุตรดิตถ์',

      // ภาคตะวันออกเฉียงเหนือ
      'กาฬสินธุ์', 'ขอนแก่น', 'ชัยภูมิ', 'นครพนม', 'นครราชสีมา',
      'บึงกาฬ', 'บุรีรัมย์', 'มหาสารคาม', 'มุกดาหาร', 'ยโสธร',
      'ร้อยเอ็ด', 'เลย', 'ศรีสะเกษ', 'สกลนคร', 'สุรินทร์',
      'หนองคาย', 'หนองบัวลำภู', 'อุดรธานี', 'อุบลราชธานี', 'อำนาจเจริญ',

      // ภาคตะวันออก
      'จันทบุรี', 'ฉะเชิงเทรา', 'ชลบุรี', 'ตราด', 'ปราจีนบุรี',
      'ระยอง', 'สระแก้ว',

      // ภาคตะวันตก
      'กาญจนบุรี', 'ตาก', 'ประจวบคีรีขันธ์', 'เพชรบุรี', 'ราชบุรี',

      // ภาคใต้
      'กระบี่', 'ชุมพร', 'ตรัง', 'นครศรีธรรมราช', 'นราธิวาส',
      'ปัตตานี', 'พังงา', 'พัทลุง', 'ภูเก็ต', 'ยะลา',
      'ระนอง', 'สงขลา', 'สตูล', 'สุราษฎร์ธานี',
    ];

    // เรียงจากยาวไปสั้น เพื่อหาชื่อยาวก่อน (เช่น "นครศรีธรรมราช" ก่อน "นคร")
    provinces.sort((a, b) => b.length.compareTo(a.length));

    String lowerText = text.toLowerCase();

    for (String province in provinces) {
      if (lowerText.contains(province.toLowerCase())) {
        return province;
      }
    }

    return null;
  }

  // เพิ่มฟังก์ชันแก้ไข OCR errors ที่พบบ่อย
  String _fixCommonOCRErrors(String plate) {
    return plate
        .replaceAll('0', '0')
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .replaceAll('๐', '0')
        .replaceAll('1', '1')
        .replaceAll('I', '1')
        .replaceAll('l', '1')
        .replaceAll('๑', '1');
  }

  /// แยกชื่อจังหวัดจากข้อความ
  String? _extractProvince(String text) {
    // รายชื่อจังหวัดในประเทศไทย (เพิ่มได้ตามต้องการ)
    List<String> provinces = [
      'กรุงเทพมหานคร', 'นครราชสีมา', 'เชียงใหม่', 'ขอนแก่น',
      'สงขลา', 'นครศรีธรรมราช', 'อุดรธานี', 'สุราษฎร์ธานี',
      'ภูเก็ต', 'ชลบุรี', 'นนทบุรี', 'ปทุมธานี', 'สมุทรปราการ',
      'พระนครศรีอยุธยา', 'ระยอง', 'หาดใหญ่', 'นครปฐม',
      // เพิ่มจังหวัดอื่นๆ ตามต้องการ
    ];

    String lowerText = text.toLowerCase();
    for (String province in provinces) {
      if (lowerText.contains(province.toLowerCase())) {
        return province;
      }
    }

    return null;
  }

  /// ทำความสะอาด resources
  void dispose() {
    _textRecognizer.close();
    _objectDetector.close();
    _yoloService.dispose();
  }

  /// ฟังก์ชันสำหรับปรับปรุงคุณภาพภาพก่อนประมวลผล
  Future<File?> preprocessImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // ปรับความคมชัด
      image = img.adjustColor(image, contrast: 1.5);

      // แปลงเป็นขาวดำ (อาจช่วยให้ OCR ทำงานดีขึ้น)
      image = img.grayscale(image);

      // บันทึกภาพที่ปรับปรุงแล้ว
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(path);
      await processedFile.writeAsBytes(img.encodeJpg(image));

      return processedFile;
    } catch (e) {
      print('❌ Error preprocessing image: $e');
      return null;
    }
  }

  /// Get detection results (for display/debugging)
  Future<List<Detection>> getDetections(XFile imageFile) async {
    try {
      return await _yoloService.detectLicensePlates(imageFile);
    } catch (e) {
      print('❌ Error getting detections: $e');
      return [];
    }
  }
}
