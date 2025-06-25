import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';

class ProfileUpdateScreen extends StatefulWidget {
  const ProfileUpdateScreen({Key? key}) : super(key: key);

  @override
  State<ProfileUpdateScreen> createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facebookController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _licensePlateController = TextEditingController();

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isScanning = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? uid = _authService.getCurrentUserId();
      if (uid != null) {
        UserModel? user = await _databaseService.getUserById(uid);
        if (user != null) {
          setState(() {
            _currentUser = user;
            _nameController.text = user.name ?? '';
            _phoneController.text = user.phoneNumber ?? '';
            _facebookController.text = user.facebook ?? '';
            _additionalInfoController.text = user.additionalInfo ?? '';
            _licensePlateController.text = user.licensePlateNumber ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ฟังก์ชันลบข้อมูลในแต่ละ field
  void _clearField(TextEditingController controller, String fieldName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบข้อมูล'),
        content: Text('คุณต้องการลบข้อมูล$fieldNameหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                controller.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบข้อมูล$fieldNameแล้ว'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              'ลบ',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสแกนจากกล้อง
  Future<void> _scanFromCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    
    if (image != null) {
      _processImage();
    }
  }

  // ฟังก์ชันสแกนจากคลังภาพ
  Future<void> _scanFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      _processImage();
    }
  }

  // ฟังก์ชันประมวลผลภาพ (จำลอง)
  void _processImage() async {
    setState(() {
      _isScanning = true;
    });
    
    try {
      // จำลองการประมวลผล OCR
      await Future.delayed(const Duration(seconds: 2));
      
      // สุ่มผลลัพธ์ป้ายทะเบียน
      final List<String> demoPlates = [
        'ขค 5678', 
        'คง 9999', 
        '2กข1234', 
        'บข 4567',
        'นม 8901',
        'สท 2345'
      ];
      final randomPlate = demoPlates[DateTime.now().millisecond % demoPlates.length];
      
      setState(() {
        _licensePlateController.text = randomPlate;
        _isScanning = false;
      });

      // แสดงข้อความสำเร็จ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('สแกนสำเร็จ: $randomPlate'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการสแกน: $e');
      }
    }
  }

  // แสดง Dialog เลือกวิธีการสแกน
  void _showScanOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกวิธีการสแกน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายภาพใหม่'),
              onTap: () {
                Navigator.pop(context);
                _scanFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () {
                Navigator.pop(context);
                _scanFromGallery();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  // ฟังก์ชันสร้าง TextField พร้อมปุ่มลบ
  Widget _buildTextFieldWithDelete({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    required String fieldName,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    String? currentValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // TextField พร้อมปุ่มลบ
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: Icon(prefixIcon),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.red[400]),
                    onPressed: () => _clearField(controller, fieldName),
                    tooltip: 'ลบข้อมูล$fieldName',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: (value) {
            setState(() {}); // อัปเดต UI เพื่อแสดง/ซ่อนปุ่มลบ
          },
        ),
      ],
    );
  }

  Future<void> _updateProfile() async {
    // ตรวจสอบข้อมูลที่กรอก
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('กรุณากรอกชื่อ-นามสกุล');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('กรุณากรอกหมายเลขโทรศัพท์');
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      _showErrorSnackBar('หมายเลขโทรศัพท์ต้องมี 10 หลัก');
      return;
    }

    if (_licensePlateController.text.trim().isEmpty) {
      _showErrorSnackBar('กรุณากรอกหมายเลขป้ายทะเบียน');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uid = _authService.getCurrentUserId();
      print('Current UID: $uid');

      if (uid != null) {
        print('Updating profile with data:');
        print('Name: ${_nameController.text.trim()}');
        print('Phone: ${_phoneController.text.trim()}');
        print('License Plate: ${_licensePlateController.text.trim()}');
        print('Facebook: ${_facebookController.text.trim()}');
        print('Additional Info: ${_additionalInfoController.text.trim()}');

        await _databaseService.updateUserProfile(
          uid: uid,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
          licensePlateNumber: _licensePlateController.text.trim(),
          facebook: _facebookController.text.trim().isEmpty
              ? null
              : _facebookController.text.trim(),
          additionalInfo: _additionalInfoController.text.trim().isEmpty
              ? null
              : _additionalInfoController.text.trim(),
        );

        print('Profile updated successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปเดตข้อมูลสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, true);
        }
      } else {
        _showErrorSnackBar('ไม่พบข้อมูลผู้ใช้');
      }
    } catch (e) {
      print('Error updating profile: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUpdatePressed() {
    _updateProfile();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Form Title
              Text(
                'แก้ไขข้อมูลส่วนตัว',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกข้อมูลเพื่อแก้ไขข้อมูล',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 32),

              // Email Field (Read-only)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'อีเมล (ไม่สามารถแก้ไขได้)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser?.email ?? 'ไม่ระบุ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Name Field
              _buildTextFieldWithDelete(
                controller: _nameController,
                labelText: 'ชื่อ-นามสกุล',
                hintText: 'กรอกชื่อ-นามสกุล',
                prefixIcon: Icons.person_outlined,
                fieldName: 'ชื่อ-นามสกุล',
                keyboardType: TextInputType.name,
                currentValue: _currentUser?.name,
              ),

              const SizedBox(height: 16),

              // Phone Field
              _buildTextFieldWithDelete(
                controller: _phoneController,
                labelText: 'หมายเลขโทรศัพท์',
                hintText: '08X-XXX-XXXX',
                prefixIcon: Icons.phone_outlined,
                fieldName: 'หมายเลขโทรศัพท์',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                currentValue: _currentUser?.phoneNumber,
              ),

              const SizedBox(height: 16),

              // Facebook Field
              _buildTextFieldWithDelete(
                controller: _facebookController,
                labelText: 'Facebook (ไม่บังคับ)',
                hintText: 'facebook.com/yourname',
                prefixIcon: Icons.facebook,
                fieldName: 'Facebook',
                keyboardType: TextInputType.url,
                currentValue: _currentUser?.facebook,
              ),

              const SizedBox(height: 16),

              // Additional Info Field
              _buildTextFieldWithDelete(
                controller: _additionalInfoController,
                labelText: 'ข้อมูลเพิ่มเติม (ไม่บังคับ)',
                hintText: 'กรอกข้อมูลเพิ่มเติม',
                prefixIcon: Icons.info_outline,
                fieldName: 'ข้อมูลเพิ่มเติม',
                maxLines: 3,
                currentValue: _currentUser?.additionalInfo,
              ),

              const SizedBox(height: 24),

              // License Plate Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // License Plate Display
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'หมายเลขป้ายทะเบียน',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_licensePlateController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear, color: Colors.red[400], size: 20),
                                onPressed: () => _clearField(_licensePlateController, 'ป้ายทะเบียน'),
                                tooltip: 'ลบป้ายทะเบียน',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _licensePlateController.text.isEmpty 
                            ? 'ยังไม่ได้ระบุป้ายทะเบียนใหม่' 
                            : _licensePlateController.text,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _licensePlateController.text.isEmpty 
                              ? Colors.grey[500] 
                              : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // License Plate Scanner Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _showScanOptions,
                  icon: _isScanning 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                  label: Text(
                    _isScanning 
                      ? 'กำลังสแกน...' 
                      : 'สแกนป้ายทะเบียน',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isScanning ? Colors.grey[400] : Colors.orange[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _isScanning ? 0 : 2,
                  ),
                ),
              ),

              // Scanner Note
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'การเปลี่ยนป้ายทะเบียนทำได้เฉพาะการสแกนเท่านั้น',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isScanning) ? null : _onUpdatePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'บันทึกข้อมูล',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'สรุปการเปลี่ยนแปลง',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• แก้ไขข้อมูลในช่องที่ต้องการเปลี่ยน\n'
                      '• ใช้ปุ่ม ❌ เพื่อลบข้อมูลในแต่ละช่อง\n'
                      '• กดปุ่ม "บันทึกข้อมูล" เพื่อยืนยันการเปลี่ยนแปลง',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _facebookController.dispose();
    _additionalInfoController.dispose();
    _licensePlateController.dispose();
    super.dispose();
  }
}