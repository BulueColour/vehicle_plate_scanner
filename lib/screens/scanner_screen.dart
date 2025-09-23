import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/custom_button.dart';
import '../services/database_service.dart';
import '../services/license_plate_recognition_service.dart'; // เพิ่มบรรทัดนี้
import '../models/user_model.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isScanning = false;
  String? _plateNumber;
  UserModel? _vehicleOwner;
  File? _selectedImage; // เพิ่มตัวแปรนี้

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

  // แทนที่ method _processImage() เดิมด้วยโค้ดใหม่ที่ใช้ YOLOv8 + OCR
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isScanning = true;
      _plateNumber = null;
      _vehicleOwner = null;
    });

    try {
      // ตรวจสอบการเชื่อมต่อ API ก่อน
      bool apiHealthy = await LicensePlateRecognitionService.checkApiHealth();
      if (!apiHealthy) {
        throw Exception('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }

      // เรียก API เพื่อตรวจจับป้ายทะเบียน
      Map<String, dynamic> result = await LicensePlateRecognitionService.detectLicensePlate(_selectedImage!);
      
      if (result['success'] == true && result['combined_text'] != null) {
        String detectedPlate = result['combined_text'].toString();
        
        if (detectedPlate.isNotEmpty) {
          setState(() {
            _plateNumber = detectedPlate;
          });
          
          // ค้นหาข้อมูลจากฐานข้อมูล Firebase
          final userData = await _databaseService.getUserByLicensePlate(detectedPlate);
          
          setState(() {
            _vehicleOwner = userData;
          });
          
          // แสดงผลลัพธ์ทันที
          _showDetectionResult(detectedPlate, result['confidence'] ?? 0.0);
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

  // เพิ่ม method ใหม่สำหรับแสดงผลลัพธ์การตรวจจับ
  void _showDetectionResult(String plateNumber, double confidence) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _vehicleOwner != null ? Icons.check_circle : Icons.info_outline,
              color: _vehicleOwner != null ? Colors.green[600] : Colors.orange[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _vehicleOwner != null ? 'พบข้อมูล' : 'ตรวจจับสำเร็จ',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ป้ายทะเบียน
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'ป้ายทะเบียน',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      plateNumber.isNotEmpty ? plateNumber : '-',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
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
              // ข้อมูลเจ้าของรถ
              if (_vehicleOwner != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูลเจ้าของรถ:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('ชื่อ', _vehicleOwner!.name ?? 'ไม่ระบุ'),
                      _buildInfoRow('อีเมล', _vehicleOwner!.email),
                      _buildInfoRow('โทรศัพท์', _vehicleOwner!.phoneNumber!),
                      if (_vehicleOwner!.facebook != null)
                        _buildInfoRow('Facebook', _vehicleOwner!.facebook!),
                      if (_vehicleOwner!.additionalInfo != null)
                        _buildInfoRow('ข้อมูลเพิ่มเติม', _vehicleOwner!.additionalInfo!),
                      const SizedBox(height: 8),
                      Text(
                        'ลงทะเบียนเมื่อ: ${_formatDate(_vehicleOwner!.createAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.orange[400],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ไม่พบข้อมูลป้ายทะเบียนนี้ในระบบ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_vehicleOwner != null) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showContactOptions();
              },
              child: const Text('ติดต่อ'),
            ),
          ],
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScan();
            },
            child: const Text('สแกนใหม่'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }



  // เพิ่ม method สำหรับแสดง error dialog
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

  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_vehicleOwner != null ? 'พบข้อมูล' : 'ไม่พบข้อมูล'),
        content: _vehicleOwner != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ป้ายทะเบียน: $_plateNumber',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('เจ้าของ', _vehicleOwner!.name ?? 'ไม่ระบุ'),
                        _buildInfoRow('อีเมล', _vehicleOwner!.email),
                        _buildInfoRow('โทรศัพท์', _vehicleOwner!.phoneNumber!),
                        if (_vehicleOwner!.facebook != null)
                          _buildInfoRow('Facebook', _vehicleOwner!.facebook!),
                        if (_vehicleOwner!.additionalInfo != null)
                          _buildInfoRow('ข้อมูลเพิ่มเติม', _vehicleOwner!.additionalInfo!),
                        const SizedBox(height: 8),
                        Text(
                          'ลงทะเบียนเมื่อ: ${_formatDate(_vehicleOwner!.createAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ป้ายทะเบียน: $_plateNumber',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('ไม่พบข้อมูลป้ายทะเบียนนี้ในระบบ'),
                ],
              ),
        actions: [
          if (_vehicleOwner != null) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showContactOptions();
              },
              child: const Text('ติดต่อ'),
            ),
          ],
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScan();
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showContactOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ติดต่อเจ้าของรถ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(_vehicleOwner!.phoneNumber!),
              onTap: () {
                // TODO: Implement phone call
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('โทร: ${_vehicleOwner!.phoneNumber}'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(_vehicleOwner!.email),
              onTap: () {
                // TODO: Implement email
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('อีเมล: ${_vehicleOwner!.email}'),
                  ),
                );
              },
            ),
            if (_vehicleOwner!.facebook != null)
              ListTile(
                leading: const Icon(Icons.facebook),
                title: Text(_vehicleOwner!.facebook!),
                onTap: () {
                  // TODO: Implement Facebook
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Facebook: ${_vehicleOwner!.facebook!}'),
                    ),
                  );
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _plateNumber = null;
      _vehicleOwner = null;
      _selectedImage = null;
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('สแกนป้ายทะเบียน'),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
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
                                : 'กดปุ่มด้านล่างเพื่อสแกน',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Result Display
            if (_plateNumber != null && !_isScanning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _vehicleOwner != null 
                    ? Colors.green[50] 
                    : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vehicleOwner != null 
                      ? Colors.green[300]! 
                      : Colors.orange[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _vehicleOwner != null 
                            ? Icons.check_circle 
                            : Icons.info,
                          color: _vehicleOwner != null 
                            ? Colors.green[700] 
                            : Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded( // ใช้ Expanded เพื่อให้ข้อความสามารถขึ้นบรรทัดใหม่ได้
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ผลการสแกน:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _plateNumber!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                maxLines: 2, // อนุญาตสูงสุด 2 บรรทัด
                                overflow: TextOverflow.visible,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _vehicleOwner != null 
                        ? 'พบข้อมูลในระบบ' 
                        : 'ไม่พบข้อมูลในระบบ',
                      style: TextStyle(
                        color: _vehicleOwner != null 
                          ? Colors.green[800] 
                          : Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'ดูรายละเอียด',
                      onPressed: _showResultDialog,
                      color: _vehicleOwner != null 
                        ? Colors.green[700] 
                        : Colors.orange[700],
                    ),
                  ],
                ),
              ),
            
            if (_plateNumber != null && !_isScanning)
              const SizedBox(height: 16),
            
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
            
            // Reset Button (if has result)
            if (_plateNumber != null && !_isScanning)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _resetScan,
                  child: const Text('สแกนใหม่'),
                ),
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