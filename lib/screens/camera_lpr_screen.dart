import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart'; // ✅ เพิ่ม import
import '../services/camera_lpr_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_danger_service.dart';

class CameraLPRScreen extends StatefulWidget {
  final CameraDescription? camera; // ✅ เพิ่ม ? เพื่อให้เป็น nullable

  const CameraLPRScreen({
    super.key,
    this.camera, // optional parameter
  });

  @override
  State<CameraLPRScreen> createState() => _CameraLPRScreenState();
}

class _CameraLPRScreenState extends State<CameraLPRScreen> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isFromGallery = false;
  
  // State Management
  bool _isScanning = true; // กำลังสแกน
  bool _isProcessing = false;
  String _detectionResult = '';
  double _confidence = 0.0;
  DateTime? _lastDetectionTime;
  
  // Throttling
  static const Duration _detectionInterval = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _initTTS();
    _initCamera();
    _testFirestore();
  }

  Future<void> _testFirestore() async {
    await Future.delayed(Duration(seconds: 2));
    print('\n === ทดสอบ Firestore ===');

    final testCases = ['ทม2805', 'ทฬ1642'];

    for (String test in testCases) {
      print('\n ทดสอบ: "$test"');
      final result = await FirestoreDangerService.checkDangerousPlate(test);
      print('  ผลลัพธ์: $result');
    }

    print('\n=====================\n');
  }

  // 🆕 เริ่มต้นกล้อง (หากล้องเองถ้าไม่ได้ส่งมา)
  Future<void> _initCamera() async {
    try {
      // หากล้อง
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _detectionResult = 'ไม่พบกล้อง';
            _isScanning = false;
          });
        }
        return;
      }

      // ใช้กล้องที่ส่งมา หรือใช้กล้องแรก
      final selectedCamera = widget.camera ?? cameras.first;

      // เริ่มสแกน
      await _startScanning(selectedCamera);
      
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _detectionResult = 'เกิดข้อผิดพลาด: $e';
          _isScanning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // 🔊 ตั้งค่า Text-to-Speech
  Future<void> _initTTS() async {
    await _flutterTts.setLanguage("th-TH");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  // 📸 เริ่มสแกน (เปิดกล้อง)
  Future<void> _startScanning(CameraDescription camera) async {
    setState(() {
      _isScanning = true;
      _isProcessing = false;
      _detectionResult = '';
      _confidence = 0.0;
      _lastDetectionTime = null;
    });

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _autoDetectLoop();
    });
  }

  // 🔄 Auto Detection Loop
  Future<void> _autoDetectLoop() async {
    while (_isScanning && mounted) {
      // Throttling
      if (_lastDetectionTime != null) {
        final elapsed = DateTime.now().difference(_lastDetectionTime!);
        if (elapsed < _detectionInterval) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }
      }

      // ตรวจสอบว่ากล้องพร้อม
      if (_controller == null || 
          !_controller!.value.isInitialized || 
          _isProcessing) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      _lastDetectionTime = DateTime.now();
      await _detectLicensePlate();
    }
  }

  // 🎯 ตรวจจับป้ายทะเบียน
  Future<void> _detectLicensePlate() async {
    if (_isProcessing || !_isScanning) return;

    try {
      setState(() => _isProcessing = true);

      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      final result = await CameraLPRService.detectLicensePlate(imageFile);

      // ลบไฟล์ชั่วคราว
      try {
        await imageFile.delete();
      } catch (e) {
        debugPrint('Cannot delete temp file: $e');
      }

      // ✅ พบป้ายทะเบียน → หยุดและอ่านออกเสียงทันที
      if (result['success'] && 
          result['combined_text'] != null && 
          result['combined_text'].toString().trim().isNotEmpty) {
        
        await _onLicensePlateDetected(
          result['combined_text'].toString().trim(),
          result['confidence']?.toDouble() ?? 0.0,
        );
      }

    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // 🎉 เมื่อพบป้ายทะเบียน
  Future<void> _onLicensePlateDetected(String plateText, double confidence) async {
    print('ตรวจพบป้ายทะเบียน: $plateText');

    setState(() {
      _isScanning = false;
      _detectionResult = plateText;
      _confidence = confidence;
    });

    // ปิดกล้องชั่วคราว
    await _controller?.dispose();
    _controller = null;

    await _speakResult('ป้ายทะเบียน ${plateText.split('').join(' ')}');

    print('กำลังตรวจสอบในฐานข้อมูล');

    try {
      final dangerData = await FirestoreDangerService.checkDangerousPlate(plateText);
      print('ผลการตรวจสอบ: $dangerData');

      if (dangerData != null) {
        final reason = dangerData['reason'] ?? 'ไม่ได้ระบุเหตุผล';
        print('พบป้ายทะเบียนอันตราย เหตุผล: $reason');

        await _speakResult(
          'เตือน!   รถคันนี้อยู่ในรายชื่ออันตราย   เหตุผลคือ $reason ป้ายทะเบียน $plateText'
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('รถอันตราย: $reason'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        print('ไม่พบป้ายทะเบียนอันตราย');
        await _speakResult('รถคันนี้ปลอดภัย ป้ายทะเบียน $plateText');
      }

    } catch (e) {
      debugPrint('Error checking dangerous plate: $e');
      await _speakResult('ไม่สามารถตรวจสอบข้อมูลได้ กรุณาลองใหม่', spellOut: false);
    }
  }

  // เช้คป้ายทะเบียนใน firestore
  Future<Map<String, dynamic>?> _checkDangerousPlate(String plateText) async {
    try {
      final normalized = plateText.replaceAll(' ', '').toUpperCase();
      final snapshot = await FirebaseFirestore.instance
        .collection('dangerous_plates')
        .where('plate', isEqualTo: normalized)
        .limit(1)
        .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    } catch (e) {
      print('Error checking dangerous plate: $e');
      return null;
    }
  }

  // 📷 เลือกภาพจากแกลเลอรี่
  Future<void> _pickImageFromGallery() async {

    _isFromGallery = true;

    final wasScanning = _isScanning;
    if (_isScanning) {
      setState(() => _isScanning = false);
      await _controller?.dispose();
      _controller = null;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      if (wasScanning) {
        await _initCamera();
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _detectionResult = 'กำลังประมวลผล...';
    });

    try {
      final result = await CameraLPRService.detectLicensePlate(File(pickedFile.path));

      if (!mounted) return;

      // เช้คว่าเจอป้ายทะเบียนมั้ย
      if (result['success'] &&
          result['combined_text'] != null &&
          result['combined_text'].toString().trim().isNotEmpty) {

          final plateText = result['combined_text'].toString().trim();
          final confidence = result['confidence']?.toDouble() ?? 0.0;

          await _onLicensePlateDetected(plateText, confidence);

      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'ไม่พบป้ายทะเบียนในภาพ'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // กลับไปสแกนต่อ
          if (wasScanning) {
            _isFromGallery = false;
            await _initCamera();
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detectionResult = 'เกิดข้อผิดพลาด: $e';
        _confidence = 0.0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 🔊 อ่านผลลัพธ์ออกเสียง
  Future<void> _speakResult(String text, {bool spellOut = false}) async {
    try {
      // แยกตัวอักษรด้วยช่องว่างเพื่อให้อ่านชัดเจน
      String speakableText = spellOut ? text.split('').join(' ') : text;
      await _flutterTts.speak(speakableText);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isScanning ? _buildScanningView() : _buildResultView(),
    );
  }

  // 📷 หน้าจอสแกน
  Widget _buildScanningView() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && 
            _controller != null && 
            _controller!.value.isInitialized) {
          return Stack(
            children: [
              // Camera Preview
              Positioned.fill(
                child: CameraPreview(_controller!),
              ),

              // Scanning Indicator
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'กำลังสแกนป้ายทะเบียน...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Scanning Frame
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8 + 80,
                  height: MediaQuery.of(context).size.width * 0.4 + 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.green,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    painter: CornerPainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // จะหยุดสแกนไว้ก่อน
                      await _pickImageFromGallery();
                    },
                    icon: const Icon(Icons.photo_library, size: 32),
                    label: const Text('คลัง'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 126, 198, 127),
                      foregroundColor: Colors.green.shade700,
                      padding:const EdgeInsets.symmetric(vertical: 28),
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                  ),
                ),
              ),

              // ปุ่มทดสอบ Firebase
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      print('\n === เริ่มทดสอบ Firebase ===');

                      try {
                        final snapshot = await FirebaseFirestore.instance
                          .collection('dangerous_plates')
                          .get();

                        print('จำนวนเอกสารทั้งหมด: ${snapshot.docs.length}');

                        for (var doc in snapshot.docs) {
                          print('Document ID: ${doc.id}');
                          print('  Data: ${doc.data()}');
                        }
                      } catch (e) {
                        print('Error fetching all: $e');
                      }

                      print('\n ทดสอบการค้นหา "ทฬ1642"');
                      try {
                        final result = await FirestoreDangerService.checkDangerousPlate('ทฬ1642');
                        print('ผลลัพธ์: $result');

                        if (result != null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('เจอข้อมูล: ${result['reason']}'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ไม่เจอข้อมูล'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        print('Error checking: $e');
                      }
                      print('=====================\n');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'ทดสอบ Firebase',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      },
    );
  }

  // ✅ หน้าจอแสดงผลลัพธ์
  Widget _buildResultView() {
    return Container(
      width: double.infinity, // ✅ บังคับให้เต็มความกว้าง
      height: double.infinity, // ✅ บังคับให้เต็มความสูง
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade700,
            Colors.green.shade900,
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success Icon
                    _isProcessing
                      ? const SizedBox(
                        height: 80,
                        width: 80,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 6,
                        ),
                      )
                      : const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 80,
                        ),
                    const SizedBox(height: 24),

                    Text(
                      _isProcessing ? 'กำลังประมวลผล...' : 'ตรวจจับสำเร็จ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // License Plate Result
                    if (!_isProcessing && _detectionResult.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          if (_detectionResult.isNotEmpty) {
                            await _speakResult(_detectionResult);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'ป้ายทะเบียน',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _detectionResult,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _confidence > 0.7
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'ความมั่นใจ: ${(_confidence * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _confidence > 0.7
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // ปุ่มอ่านอีกรอบ
                    if (!_isProcessing && _detectionResult.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_detectionResult.isNotEmpty) {
                            await _speakResult(_detectionResult);
                          }
                        },
                        icon: const Icon(Icons.volume_up, size: 40),
                        label: const Text(
                          'อ่านอีกครั้ง',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.green.shade800,
                          padding: const EdgeInsets.symmetric(
                            vertical: 22,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ปุ่มด้านล่างสุด
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library, size: 32),
                  label: const Text('คลัง'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.camera_alt, size: 32),
                  label: const Text('สแกนใหม่'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎨 วาดมุมกรอบสแกน
class CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}