import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';

class PlateRegistrationScreen extends StatefulWidget {
  const PlateRegistrationScreen({super.key});

  @override
  State<PlateRegistrationScreen> createState() => _PlateRegistrationScreenState();
}

class _PlateRegistrationScreenState extends State<PlateRegistrationScreen> {
  bool _isScanning = false;
  String? _plateNumber;
  Map<String, dynamic>? _userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // รับข้อมูลที่ส่งมาจากหน้า register
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _userData = args;
    }
  }

  Future<void> _scanFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null) {
      _processImage();
    }
  }

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      _processImage();
    }
  }

  void _processImage() {
    setState(() => _isScanning = true);
    
    // Demo: จำลองการประมวลผล OCR
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isScanning = false;
        // Demo: สุ่มผลลัพธ์
        final List<String> demoPlates = ['กข 1234', 'ขค 5678', 'คง 9999', 'งจ 7777'];
        _plateNumber = demoPlates[DateTime.now().millisecond % demoPlates.length];
      });
    });
  }

  void _completeRegistration() {
    if (_plateNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาสแกนป้ายทะเบียนก่อน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // จำลองการบันทึกข้อมูลลง Firebase
    setState(() => _isScanning = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isScanning = false);
      
      // แสดงผลสำเร็จ
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
                    Text('ชื่อ: ${_userData!['name']}'),
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
                Navigator.pop(context); // ปิด dialog
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
    });
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
                            'กำลังประมวลผล...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'กดปุ่มด้านล่างเพื่อสแกนป้ายทะเบียน',
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
                    Icons.info_outline,
                    size: 20,
                    color: Colors.amber[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'หมายเหตุ: ระบบต้องการหมายเลขป้ายทะเบียนของคุณในการลงทะเบียน',
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