// เอาใหม่ นี่เป็น checkpoint ก่อนลุย backend

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

  // เพิ่มตัวแปรเพื่อ track ฟิลด์ที่ถูกลบจะได้เก็บไปใช้ได้ (ไม่รวมป้ายทะเบียน)
  Set<String> _deletedFields = {};

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

  // ฟังก์ชันลบข้อมูลในแต่ละ field (ไม่รวมป้ายทะเบียน)
  void _clearField(TextEditingController controller, String fieldName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบข้อมูล'),
        content: Text(
            'คุณต้องการลบข้อมูล$fieldNameหรือไม่?\n\nข้อมูลจะถูกลบออกจากฐานข้อมูลเมื่อกดบันทึก'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                controller.clear();

                // เพิ่มฟิลด์ที่ถูกลบเข้าใน Set (ไม่รวมป้ายทะเบียน)
                switch (fieldName) {
                  case 'ชื่อ-นามสกุล':
                    _deletedFields.add('name');
                    break;
                  case 'หมายเลขโทรศัพท์':
                    _deletedFields.add('phoneNumber');
                    break;
                  case 'Facebook':
                    _deletedFields.add('facebook');
                    break;
                  case 'ข้อมูลเพิ่มเติม':
                    _deletedFields.add('additionalInfo');
                    break;
                  // ไม่มี case สำหรับป้ายทะเบียน
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'ลบข้อมูล$fieldNameแล้ว (จะถูกลบจากฐานข้อมูลเมื่อบันทึก)'),
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

  // ฟังก์ชันประมวลผลภาพ (ยังเป็นชุดข้อมูลตัวอย่างอยู่)
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
      final randomPlate =
          demoPlates[DateTime.now().millisecond % demoPlates.length];

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

  // ฟังก์ชันที่ใช้สร้าง TextField ของปุ่มที่เปลี่ยนข้อมูลได้ (ชื่อนามสกุล เบอร์ facebook ข้อมูลเพิ่มเติม) 
  // แก้ได้ตรงนี้ (สร้างไว้แล้วเรียกใช้ตอนจะสร้างฟิลด์ใดๆ)
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
    bool hasData = controller.text.isNotEmpty;
    bool isEmpty = controller.text.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            // กำหนดสีขอบตามสถานะ: ว่าง = สีดำ, มีข้อมูล = สีเทา
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isEmpty ? const Color.fromARGB(255, 117, 117, 117) : Colors.grey[300]!,
                width: isEmpty ? 1.7 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isEmpty ? const Color.fromARGB(255, 117, 117, 117) : Colors.blue[400]!,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 1.0,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 2.0,
              ),
            ),
            filled: true,
            fillColor: hasData // ไฮไล้ทภายใน TextField
                ? const Color.fromARGB(255, 215, 236, 255)  // สีฟ้าอ่อนเมื่อมีข้อมูล
                : isEmpty 
                    ? const Color.fromARGB(255, 255, 255, 255)  // สีเหลืองอ่อนเมื่อว่าง (ไฮไลท์)
                    : Colors.white,  // สีขาวปกติ
          ),
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: (value) {
            setState(() {
              // ถ้าผู้ใช้พิมพ์ข้อมูลใหม่ ให้ลบออกจาก deletedFields
              if (value.isNotEmpty) {
                switch (fieldName) {
                  case 'ชื่อ-นามสกุล':
                    _deletedFields.remove('name');
                    break;
                  case 'หมายเลขโทรศัพท์':
                    _deletedFields.remove('phoneNumber');
                    break;
                  case 'Facebook':
                    _deletedFields.remove('facebook');
                    break;
                  case 'ข้อมูลเพิ่มเติม':
                    _deletedFields.remove('additionalInfo');
                    break;
                  // ไม่มี case สำหรับป้ายทะเบียน
                }
              }
            });
          },
        ),
      ],
    );
  }

  // ลบแค่ข้อมูลใน field ไม่ใช่ทั้ง field
  Future<void> _updateProfile() async {

    // ตรวจสอบหมายเลขโทรศัพท์ (ถ้าเปลี่ยน)
    if (_phoneController.text.trim().isNotEmpty) {
      final phoneNumber = _phoneController.text.trim();
      if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
        _showErrorSnackBar('หมายเลขโทรศัพท์ต้องเป็นตัวเลข 10 หลัก');
        return;
      }
    }

    // ตรวจสอบป้ายทะเบียน (ถ้าเปลี่ยน)
    if (_licensePlateController.text.trim().isNotEmpty) {
      final licensePlate = _licensePlateController.text.trim();
      if (licensePlate.length < 2 || licensePlate.length > 8) {
        _showErrorSnackBar('ป้ายทะเบียนต้องมีความยาว 2-8 ตัวอักษร');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? uid = _authService.getCurrentUserId();
      print('Current UID: $uid');

      if (uid != null) {
        // เตรียมข้อมูลที่จะอัปเดต
        final Map<String, dynamic> updateData = {};

        // เพิ่มข้อมูลที่มีการกรอก
        if (_nameController.text.trim().isNotEmpty) {
          updateData['name'] = _nameController.text.trim();
          _deletedFields
              .remove('name'); // ลบออกจาก deleted fields ถ้ามีข้อมูลใหม่
        }

        if (_phoneController.text.trim().isNotEmpty) {
          updateData['phoneNumber'] = _phoneController.text.trim();
          _deletedFields.remove('phoneNumber');
        }

        // ป้ายทะเบียนจะอัปเดตเฉพาะตอนมีการสแกน
        if (_licensePlateController.text.trim().isNotEmpty) {
          updateData['licensePlateNumber'] =
              _licensePlateController.text.trim();
        }

        if (_facebookController.text.trim().isNotEmpty) {
          updateData['facebook'] = _facebookController.text.trim();
          _deletedFields.remove('facebook');
        }

        if (_additionalInfoController.text.trim().isNotEmpty) {
          updateData['additionalInfo'] = _additionalInfoController.text.trim();
          _deletedFields.remove('additionalInfo');
        }

        // เพิ่มฟิลด์ที่ถูกลบเป็น empty string (ไม่รวมป้ายทะเบียน)
        for (String deletedField in _deletedFields) {
          updateData[deletedField] = ''; // ส่ง empty string ไปที่ database
        }

        print('Updating profile with data: $updateData');
        print('Deleted fields: $_deletedFields');


        await _databaseService.updateUserProfileFlexible(
          uid: uid,
          updateData: updateData,
        );

        print('Profile updated successfully');

        if (mounted) {
          // นับจำนวนฟิลด์ที่มีการเปลี่ยนแปลง
          final changedFields =
              updateData.keys.where((key) => updateData[key] != '').length;
          final deletedCount = _deletedFields.length;

          String successMessage = 'อัปเดตข้อมูลสำเร็จ';
          if (changedFields > 0 || deletedCount > 0) {
            List<String> parts = [];
            if (changedFields > 0) parts.add('แก้ไข $changedFields รายการ');
            if (deletedCount > 0) parts.add('ลบ $deletedCount รายการ');
            successMessage += ' (${parts.join(', ')})';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
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
                'กรอกเฉพาะข้อมูลที่ต้องการแก้ไข',
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
                      color: Color.fromARGB(255, 215, 236, 255),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: const Color.fromARGB(255, 73, 73, 73),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'อีเมล (ไม่สามารถแก้ไขได้)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color.fromARGB(221, 71, 71, 71),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentUser?.email ?? 'ไม่ระบุ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color.fromARGB(221, 33, 33, 33),
                                ),
                              ),
                            ],
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _licensePlateController.text.isNotEmpty
                          ? const Color.fromARGB(255, 215, 236, 255)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label ด้านบน
                        Text(
                          'หมายเลขป้ายทะเบียน',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            // ไอคอนรถ
                            Icon(
                              Icons.directions_car,
                              color: const Color.fromARGB(255, 79, 78, 78),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            
                            // ป้ายทะเบียนชิดซ้าย
                            Expanded(
                              child: Text(
                                _licensePlateController.text.isEmpty
                                    ? 'ยังไม่ได้ระบุป้ายทะเบียน'
                                    : _licensePlateController.text,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _licensePlateController.text.isEmpty
                                      ? Colors.grey[500]
                                      : Colors.black87,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // ปุ่มสแกนทางขวา
                            SizedBox(
                              width: 180,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _isScanning ? null : _showScanOptions,
                                icon: _isScanning
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Icon(
                                        Icons.qr_code_scanner,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  _isScanning ? 'กำลังสแกน...' : 'สแกนป้ายทะเบียน',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isScanning ? Colors.grey[400] : Colors.orange[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: _isScanning ? 0 : 3,
                                  shadowColor: Colors.orange[200],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Scanner Note
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[200]!, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'หมายเหตุ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ป้ายทะเบียนสามารถเปลี่ยนได้เฉพาะการสแกนเท่านั้น ไม่สามารถลบได้',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              height: 1.3,
                            ),
                          ),
                        ],
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
                  onPressed:
                      (_isLoading || _isScanning) ? null : _onUpdatePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_outlined,
                          size: 20,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'วิธีการใช้งาน',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• ช่องที่มีข้อมูลจะไฮไลท์เป็นสีฟ้าอ่อน\n'
                      '• กรอกเฉพาะข้อมูลที่ต้องการเปลี่ยนแปลง\n'
                      '• ใช้ปุ่ม ❌ เพื่อลบข้อมูลออกจากฐานข้อมูล (ยกเว้นป้ายทะเบียน)\n'
                      '• กดปุ่ม "สแกน" ข้างป้ายทะเบียนเพื่อเปลี่ยนหมายเลข\n'
                      '• ไม่จำเป็นต้องกรอกทุกช่อง สามารถบันทึกได้ทันที\n'
                      '• กดปุ่ม "บันทึกข้อมูล" เพื่อยืนยันการเปลี่ยนแปลง',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
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