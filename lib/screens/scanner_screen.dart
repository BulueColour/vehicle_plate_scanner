import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';
import '../services/database_service.dart';
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

  void _processImage() async {
    setState(() {
      _isScanning = true;
      _plateNumber = null;
      _vehicleOwner = null;
    });
    
    try {
      // Demo: จำลองการประมวลผล OCR
      await Future.delayed(const Duration(seconds: 3));
      
      // Demo: สุ่มผลลัพธ์ป้ายทะเบียน
      final List<String> demoPlates = ['กข 1234', 'ขค 5678', 'คง 9999', 'งจ 7777', 'ABC123'];
      final randomPlate = demoPlates[DateTime.now().millisecond % demoPlates.length];
      
      setState(() {
        _plateNumber = randomPlate;
      });

      // ค้นหาข้อมูลจากฐานข้อมูล Firebase
      final userData = await _databaseService.getUserByLicensePlate(randomPlate);
      
      setState(() {
        _vehicleOwner = userData;
        _isScanning = false;
      });

    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
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
                        _buildInfoRow('โทรศัพท์', _vehicleOwner!.phoneNumber),
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
              title: Text(_vehicleOwner!.phoneNumber),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
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
                            'กำลังประมวลผลและค้นหาข้อมูล...',
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
                    Text(
                      _vehicleOwner != null 
                        ? 'พบข้อมูลในระบบ' 
                        : 'ไม่พบข้อมูลในระบบ',
                      style: TextStyle(
                        color: _vehicleOwner != null 
                          ? Colors.green[800] 
                          : Colors.orange[800],
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
                      'ระบบจะค้นหาข้อมูลเจ้าของรถจากฐานข้อมูล Firebase',
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