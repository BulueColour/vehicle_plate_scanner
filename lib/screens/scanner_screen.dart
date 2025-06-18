import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String? _plateNumber;
  Map<String, dynamic>? _vehicleData;

  // Demo data
  final Map<String, Map<String, dynamic>> _demoDatabase = {
    'กข 1234': {
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
  };

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
    
    // Demo: จำลองการประมวลผล
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isScanning = false;
        // Demo: Random result
        _plateNumber = DateTime.now().second.isEven ? 'กข 1234' : 'ขค 5678';
        _vehicleData = _demoDatabase[_plateNumber];
      });
    });
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
                  Text('ทะเบียน: $_plateNumber'),
                  const SizedBox(height: 8),
                  Text('เจ้าของ: ${_vehicleData!['owner']}'),
                  Text('ยี่ห้อ: ${_vehicleData!['brand']}'),
                  Text('รุ่น: ${_vehicleData!['model']}'),
                  Text('สี: ${_vehicleData!['color']}'),
                  Text('ปี: ${_vehicleData!['year']}'),
                  Text('จังหวัด: ${_vehicleData!['province']}'),
                ],
              )
            : const Text('ไม่พบข้อมูลทะเบียนนี้ในระบบ'),
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
                            'กดปุ่มด้านล่างเพื่อสแกน',
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
                  color: _vehicleData != null 
                    ? Colors.green[50] 
                    : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vehicleData != null 
                      ? Colors.green[300]! 
                      : Colors.red[300]!,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'ผลการสแกน: $_plateNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      'Demo: ระบบจะแสดงผลแบบสุ่ม (กข 1234 หรือ ขค 5678)',
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