import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/license_plate_recognition_service.dart'; // เพิ่มบรรทัดนี้
import '../models/user_model.dart';

class PlateRegistrationScreen extends StatefulWidget {
  const PlateRegistrationScreen({super.key});

  @override
  State<PlateRegistrationScreen> createState() => _PlateRegistrationScreenState();
}

class _PlateRegistrationScreenState extends State<PlateRegistrationScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isScanning = false;
  String? _plateNumber;
  Map<String, dynamic>? _userData;
  File? _selectedImage; // เพิ่มตัวแปรนี้

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _userData = args;
    }
  }

  Future<void> _scanFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      await _processImage();
    }
  }

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      await _processImage();
    }
  }

  // แทนที่ method _processImage() เดิมด้วยโค้ดนี้
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isScanning = true;
      _plateNumber = null;
    });

    try {
      // ตรวจสอบการเชื่อมต่อ API ก่อน
      bool apiHealthy = await LicensePlateRecognitionService.checkApiHealth();
      if (!apiHealthy) {
        throw Exception('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }

      // เรียก API เพื่อตรวจจับป้ายทะเบียน
      Map<String, dynamic> result = await LicensePlateRecognitionService.detectLicensePlate(_selectedImage!);
      
      if (result['success'] == true && result['license_plate'] != null) {
        String detectedPlate = result['license_plate'].toString();
        String cleanedPlate = LicensePlateRecognitionService.cleanLicensePlateText(detectedPlate);
        
        if (cleanedPlate.isNotEmpty) {
          setState(() {
            _plateNumber = cleanedPlate;
          });
          
          _showDetectionResult(cleanedPlate, result['confidence'] ?? 0.0);
        } else {
          throw Exception('ไม่สามารถอ่านป้ายทะเบียนได้ กรุณาถ่ายภาพใหม่');
        }
      } else {
        String errorMessage = result['message'] ?? 'ไม่พบป้ายทะเบียนในภาพ';
        throw Exception(errorMessage);
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  // เพิ่ม method ใหม่สำหรับแสดงผลลัพธ์
  void _showDetectionResult(String plateNumber, double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 8),
            const Text('พบป้ายทะเบียน'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    plateNumber,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ความมั่นใจ: ${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('ป้ายทะเบียนถูกต้องหรือไม่?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _plateNumber = null;
                _selectedImage = null;
              });
            },
            child: const Text('ถ่ายใหม่'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('ถูกต้อง'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text('เกิดข้อผิดพลาด'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  // method อื่นๆ ยังเหมือนเดิม...
  void _completeRegistration() async {
    if (_plateNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาสแกนป้ายทะเบียนก่อน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isScanning = true);

    try {
      // ตรวจสอบว่าป้ายทะเบียนซ้ำหรือไม่
      bool plateExists = await _databaseService.isLicensePlateExists(_plateNumber!);
      if (plateExists) {
        throw 'ป้ายทะเบียน $_plateNumber มีในระบบแล้ว กรุณาใช้ป้ายทะเบียนอื่น';
      }

      // สร้างบัญชี Firebase Auth
      final userCredential = await _authService.createUserWithEmailAndPassword(
        _userData!['email'],
        _userData!['password'],
      );

      if (userCredential?.user == null) {
        throw 'ไม่สามารถสร้างบัญชีได้';
      }

      // สร้างข้อมูลผู้ใช้ใน Firestore
      UserModel newUser = UserModel(
        uid: userCredential!.user!.uid,
        licensePlateNumber: _plateNumber!,
        email: _userData!['email'],
        phoneNumber: _userData!['phone'],
        createAt: DateTime.now(),
      );

      await _databaseService.createUser(newUser);

      setState(() => _isScanning = false);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text('สำเร็จ!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ลงทะเบียนเสร็จสิ้น'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('อีเมล: ${_userData!['email']}'),
                      Text('โทรศัพท์: ${_userData!['phone']}'),
                      Text('ป้ายทะเบียน: $_plateNumber'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
                child: const Text('เข้าสู่ระบบ'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      setState(() => _isScanning = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('สแกนป้ายทะเบียน'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '2',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ขั้นตอนที่ 2 จาก 2',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                        Text(
                          'สแกนป้ายทะเบียนรถของคุณ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Camera Preview Area
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.blue[300]!,
                    width: 2,
                  ),
                ),
                child: _isScanning
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue[700]!,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'กำลังประมวลผลด้วย AI...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'YOLO + OCR กำลังทำงาน',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // แสดงภาพที่เลือกถ้ามี
                          if (_selectedImage != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 150,
                                width: 250,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            Icon(
                              Icons.camera_alt,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          Text(
                            _selectedImage != null 
                                ? 'ภาพที่เลือก' 
                                : 'กดปุ่มด้านล่างเพื่อสแกนป้ายทะเบียน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          
                          if (_plateNumber != null) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Text(
                                'ป้ายทะเบียน: $_plateNumber',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Scan Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'ถ่ายภาพ',
                    onPressed: _isScanning ? () {} : _scanFromCamera,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'เลือกจากคลัง',
                    onPressed: _isScanning ? () {} : _scanFromGallery,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Complete Registration Button
            if (_plateNumber != null)
              CustomButton(
                text: 'ยืนยันการลงทะเบียน',
                onPressed: _completeRegistration,
                color: Colors.green[700],
                isLoading: _isScanning,
              ),
            
            const SizedBox(height: 16),
            
            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology,
                    size: 20,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ใช้ AI: YOLOv8 + EasyOCR สำหรับป้ายทะเบียนไทย',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}