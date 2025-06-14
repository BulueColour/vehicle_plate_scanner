import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // สำหรับ rootBundle
import 'package:image_picker/image_picker.dart';
import 'dart:io';  // สำหรับ File
import 'package:path_provider/path_provider.dart';  // สำหรับ getTemporaryDirectory
import '../widgets/custom_button.dart';
import '../services/plate_recognition_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String? _plateNumber;
  String? _scanStatus;
  Map<String, dynamic>? _vehicleData;

  // Demo assets images
  final List<String> _testImages = [
    'assets/test_plates/3603.jpg',
    'assets/test_plates/4992.jpg',
    'assets/test_plates/6557.png',
  ];

  int _currentTestImageIndex = 0;
  // Plate recognition service
  late PlateRecognitionService _recognitionService;

  // Demo data
  final Map<String, Map<String, dynamic>> _demoDatabase = {
    'บม 3107': {
      'owner': 'นายสิทธิพงศ์ บุญเทียน',
      'brand': 'Audi',
      'model': 'R8',
      'color': 'White',
      'year': '2020',
      'province': 'นครราชสีมา',
    },
    'ขค 5678': {
      'owner': 'นางสาวสุรางคณา เพียรดี',
      'brand': 'Mercedez Benz',
      'model': 'AMG CLS 53',
      'color': 'White',
      'year': '2021',
      'province': 'นครราชสีมา',
    },
    'กข 1234': {
      'owner': 'นายสมชาย ใจดี',
      'brand': 'Toyota',
      'model': 'Camry',
      'color': 'ขาวมุก',
      'year': '2020',
      'province': 'กรุงเทพมหานคร',
    },
  };

  @override
  void initState() {
    super.initState();
    _recognitionService = PlateRecognitionService();
  }

  @override
  void dispose() {
    _recognitionService.dispose();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90, // คุณภาพภาพ 90%
    );

    if (image != null) {
      _processImage(image);
    }
  }

  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image != null) {
      _processImage(image);
    }
  }

  Future<void> _scanFromAssets() async {
    try {
      // เลือกภาพจาก assets แบบวนลูป
      String assetPath = _testImages[_currentTestImageIndex];
      _currentTestImageIndex =
          (_currentTestImageIndex + 1) % _testImages.length;

      // แสดง dialog เลือกภาพ
      bool? useImage = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ใช้ภาพทดสอบ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('จะใช้ภาพนี้ในการทดสอบหรือไม่?'),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('เลือกภาพอื่น'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ใช้ภาพนี้'),
            ),
          ],
        ),
      );

      if (useImage != true) {
        // ถ้าไม่ใช้ภาพนี้ ให้เรียกฟังก์ชันใหม่เพื่อดูภาพถัดไป
        _scanFromAssets();
        return;
      }

      // แปลง asset เป็น File
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer;

      // สร้างไฟล์ชั่วคราว
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(tempPath);
      await file.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

      // แปลงเป็น XFile
      final xFile = XFile(file.path);

      // ประมวลผลภาพ
      _processImage(xFile);
    } catch (e) {
      print('❌ Error loading asset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่สามารถโหลดภาพได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processImage(XFile image) async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'กำลังประมวลผลภาพ...';
      _plateNumber = null;
      _vehicleData = null;
    });

    try {
      // ขั้นตอนที่ 1: ประมวลผลภาพด้วย ML Kit
      setState(() => _scanStatus = 'กำลังตรวจจับป้ายทะเบียน...');

      // ปรับปรุงคุณภาพภาพก่อน (optional)
      // final processedImage = await _recognitionService.preprocessImage(image);

      // ประมวลผลภาพ
      final detectedPlate = await _recognitionService.processImage(image);

      if (detectedPlate != null) {
        setState(() {
          _scanStatus = 'พบป้ายทะเบียน: $detectedPlate';
          _plateNumber = detectedPlate;
        });

        // ขั้นตอนที่ 2: ค้นหาข้อมูลในฐานข้อมูล
        await Future.delayed(const Duration(seconds: 1)); // จำลอง delay

        // ค้นหาข้อมูล (ตอนนี้ใช้ demo data)
        _vehicleData = _findVehicleData(detectedPlate);

        setState(() {
          _isScanning = false;
          _scanStatus = null;
        });
      } else {
        // ถ้าไม่พบป้ายทะเบียน ใช้ demo mode
        setState(() {
          _scanStatus = 'ไม่พบป้ายทะเบียน กำลังใช้โหมด Demo...';
        });

        await Future.delayed(const Duration(seconds: 2));

        // Demo: Random result
        setState(() {
          _isScanning = false;
          _plateNumber = DateTime.now().second.isEven ? 'กข 1234' : 'ขค 5678';
          _vehicleData = _demoDatabase[_plateNumber];
          _scanStatus = null;
        });
      }
    } catch (e) {
      print('❌ Error in _processImage: $e');
      setState(() {
        _isScanning = false;
        _scanStatus = 'เกิดข้อผิดพลาด: $e';
      });

      // แสดง error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('เกิดข้อผิดพลาด'),
          content: Text('ไม่สามารถประมวลผลภาพได้\n$e'),
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

  Map<String, dynamic>? _findVehicleData(String plateNumber) {
    // ทำความสะอาดเลขทะเบียน
    String cleanPlate = plateNumber.replaceAll(RegExp(r'\s+'), ' ').trim();

    // ค้นหาแบบตรงทั้งหมด
    if (_demoDatabase.containsKey(cleanPlate)) {
      return _demoDatabase[cleanPlate];
    }

    // ค้นหาแบบบางส่วน (ไม่รวมจังหวัด)
    String plateWithoutProvince = cleanPlate.split(' ').take(2).join(' ');
    for (String key in _demoDatabase.keys) {
      if (key.contains(plateWithoutProvince) ||
          plateWithoutProvince.contains(key)) {
        return _demoDatabase[key];
      }
    }

    return null;
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_vehicleData != null ? 'พบข้อมูล' : 'ไม่พบข้อมูล'),
        content: _vehicleData != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ทะเบียน: $_plateNumber',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('เจ้าของ', _vehicleData!['owner']),
                  _buildInfoRow('ยี่ห้อ', _vehicleData!['brand']),
                  _buildInfoRow('รุ่น', _vehicleData!['model']),
                  _buildInfoRow('สี', _vehicleData!['color']),
                  _buildInfoRow('ปี', _vehicleData!['year']),
                  _buildInfoRow('จังหวัด', _vehicleData!['province']),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text('ไม่พบข้อมูลทะเบียน "$_plateNumber" ในระบบ'),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _plateNumber = null;
                _vehicleData = null;
              });
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
                          Text(
                            _scanStatus ?? 'กำลังประมวลผล...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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
                            'กดปุ่มด้านล่างเพื่อสแกน',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'รองรับป้ายทะเบียนไทย',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
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
                  color:
                      _vehicleData != null ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vehicleData != null
                        ? Colors.green[300]!
                        : Colors.red[300]!,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _vehicleData != null
                              ? Icons.check_circle
                              : Icons.error,
                          color: _vehicleData != null
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ผลการสแกน: $_plateNumber',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: 'ดูรายละเอียด',
                      onPressed: _showResultDialog,
                      color: _vehicleData != null
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ],
                ),
              ),

            if (_plateNumber != null && !_isScanning)
              const SizedBox(height: 16),

            // Scan Buttons
            Column(
              children: [
                // แถวแรก: ถ่ายภาพและเลือกจากคลัง
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
                const SizedBox(height: 12),
                // แถวที่สอง: ใช้ภาพทดสอบ
                CustomButton(
                  text: 'ใช้ภาพทดสอบ (Assets)',
                  onPressed: _isScanning ? () {} : _scanFromAssets,
                  color: Colors.purple[700],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Info Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ระบบใช้ AI ในการตรวจจับและอ่านป้ายทะเบียน',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
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
