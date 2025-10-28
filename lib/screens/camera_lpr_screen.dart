import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/camera_lpr_service.dart';
import 'package:image_picker/image_picker.dart';

class CameraLPRScreen extends StatefulWidget {
  const CameraLPRScreen({super.key});

  @override
  State<CameraLPRScreen> createState() => _CameraLPRScreenState();
}

class _CameraLPRScreenState extends State<CameraLPRScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _statusText = 'แตะหน้าจอเพื่อถ่ายภาพป้ายทะเบียน';
  
  final FlutterTts _flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  String? _detectedPlate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _initializeTTS();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _statusText = '❌ ไม่พบกล้อง';
        });
        return;
      }

      // ใช้กล้องหลัง
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusText = '❌ เกิดข้อผิดพลาด: $e';
      });
    }
  }

  Future<void> _initializeTTS() async {
    await _flutterTts.setLanguage("th-TH");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _captureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusText = '📸 กำลังถ่ายภาพ...';
      _capturedImage = null;
      _detectedPlate = null;
    });

    try {
      // ถ่ายภาพ
      final XFile photo = await _controller!.takePicture();
      final File imageFile = File(photo.path);

      setState(() {
        _capturedImage = imageFile;
        _statusText = '🔄 กำลังประมวลผลด้วย AI...';
      });

      // ส่งไป Backend
      Map<String, dynamic> result = await CameraLPRService.detectLicensePlate(imageFile);

      if (result['success'] == true) {
        String plateText = result['combined_text'] ?? '';
        double confidence = result['confidence'] ?? 0.0;

        setState(() {
          _detectedPlate = plateText;
          _statusText = plateText.isNotEmpty 
            ? '✅ อ่านได้: $plateText'
            : '⚠️ ไม่พบป้ายทะเบียน';
        });

        // ใช้ TTS อ่านผลลัพธ์
        if (plateText.isNotEmpty) {
          await _speak(plateText);
          _showResultDialog(plateText, confidence);
        } else {
          await _speak('ไม่พบป้ายทะเบียนในภาพ');
        }
      } else {
        String errorMsg = result['message'] ?? 'เกิดข้อผิดพลาด';
        setState(() {
          _statusText = '❌ $errorMsg';
        });
        await _speak(errorMsg);
      }
    } catch (e) {
      setState(() {
        _statusText = '❌ เกิดข้อผิดพลาด: $e';
      });
      await _speak('เกิดข้อผิดพลาด');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // เลือกจากคลัง
  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      setState(() {
        _isProcessing = true;
        _statusText = 'กำลังประมวลผลด้วย AI...';
        _capturedImage = File(pickedFile.path);
      });

      await _processImage(_capturedImage!);
    } catch (e) {
      setState(() {
        _statusText = 'ไม่สามารถเลือกภาพได้: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ประมวลผลร่วมกัน
  Future<void> _processImage(File imageFile) async {
    setState(() {
      _capturedImage = imageFile;
    });

    Map<String, dynamic> result = await CameraLPRService.detectLicensePlate(imageFile);

    if (result['success'] == true) {
      String plateText = result['combined_text'] ?? '';
      double confidence = result['confidence'] ?? 0.0;

      setState(() {
        _detectedPlate = plateText;
        _statusText = plateText.isNotEmpty
        ?'อ่านได้: $plateText'
        :'ไม่พบป้ายทะเบียน';
      });

      if (plateText.isNotEmpty) {
        await _speak(plateText);
        _showResultDialog(plateText, confidence);
      } else {
        await _speak('ไม่พบป้ายทะเบียนในภาพ');
      }
    } else {
      String errorMsg = result['message'] ?? 'เกิดข้อผิดพลาดขึ้น';
      setState(() {
        _statusText = '$errorMsg';
      });
      await _speak(errorMsg);
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _showResultDialog(String plateText, double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('ตรวจจับสำเร็จ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_capturedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _capturedImage!,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Text(
                    'ป้ายทะเบียน',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    plateText,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ความมั่นใจ: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetCamera();
            },
            child: const Text('ถ่ายใหม่'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _resetCamera() {
    setState(() {
      _capturedImage = null;
      _detectedPlate = null;
      _statusText = 'แตะหน้าจอเพื่อถ่ายภาพป้ายทะเบียน';
    });
  }

  Future<void> _testConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    bool isHealthy = await CameraLPRService.checkApiHealth();
    
    if (mounted) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.error,
                color: isHealthy ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(isHealthy ? 'เชื่อมต่อสำเร็จ' : 'เชื่อมต่อล้มเหลว'),
            ],
          ),
          content: Text(
            isHealthy 
              ? 'Backend พร้อมใช้งาน' 
              : 'ไม่สามารถเชื่อมต่อกับ Backend ได้\nกรุณาตรวจสอบ URL และเปิด Backend',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('สแกนป้ายทะเบียน (กล้อง)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            onPressed: _testConnection,
            tooltip: 'ทดสอบการเชื่อมต่อ',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_isInitialized && _controller != null)
            IgnorePointer(
              ignoring: _isProcessing,
              child: CameraPreview(_controller!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // กรอบสี่เหลี่ยมแนะนำการวางป้าย
          if (_isInitialized && !_isProcessing)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'วางป้ายทะเบียนในกรอบนี้',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Status Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isProcessing)
                    const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isProcessing) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'แตะหน้าจอเพื่อถ่ายภาพ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ปุ่มเลือกภาพจากคลัง
          Positioned(
            bottom: 20,
            right: 20, //มุมขวาล่าง
            child: FloatingActionButton(
              heroTag: 'pick_gallery',
              backgroundColor: Colors.blueAccent,
              onPressed: _isProcessing ? null : _pickFromGallery,
              tooltip: 'เลือกจากคลังภาพ',
              child: const Icon(Icons.photo_library),
            ),
          ),

          // Captured Image Preview (ถ้ามี)
          if (_capturedImage != null && !_isProcessing)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    _capturedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}