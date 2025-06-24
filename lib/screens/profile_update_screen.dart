import 'package:flutter/material.dart';
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

  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
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
        print('Facebook: ${_facebookController.text.trim()}');
        print('Additional Info: ${_additionalInfoController.text.trim()}');

        await _databaseService.updateUserProfile(
          uid: uid,
          name: _nameController.text.trim(),
          phoneNumber: _phoneController.text.trim(),
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

  // เพิ่มฟังก์ชันนี้เพื่อ wrap async function
  void _handleUpdateProfile() {
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

              // Name Field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อ-นามสกุล',
                  hintText: 'กรอกชื่อ-นามสกุล',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.name,
              ),

              const SizedBox(height: 16),

              // Phone Field
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'หมายเลขโทรศัพท์',
                  hintText: '08X-XXX-XXXX',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),

              const SizedBox(height: 16),

              // Facebook Field
              TextField(
                controller: _facebookController,
                decoration: InputDecoration(
                  labelText: 'Facebook (ไม่บังคับ)',
                  hintText: 'facebook.com/yourname',
                  prefixIcon: const Icon(Icons.facebook),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 16),

              // Additional Info Field
              TextField(
                controller: _additionalInfoController,
                decoration: InputDecoration(
                  labelText: 'ข้อมูลเพิ่มเติม (ไม่บังคับ)',
                  hintText: 'กรอกข้อมูลเพิ่มเติม',
                  prefixIcon: const Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Update Button
              CustomButton(
                text: 'บันทึกข้อมูล',
                onPressed: _handleUpdateProfile, // ใช้ wrapper function
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
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
                        'อีเมล: ${_currentUser?.email ?? 'ไม่ระบุ'}\nป้ายทะเบียน: ${_currentUser?.licensePlateNumber ?? 'ไม่ระบุ'}',
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _facebookController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }
}
