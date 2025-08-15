import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../screens/profile_update_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true; // แสดง loading indicator
    });

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        print('Loading user data for UID: ${firebaseUser.uid}'); // Debug log
        final userData = await _databaseService.getUser(firebaseUser.uid);
        print('Loaded user data: ${userData?.toMap()}'); // Debug log
        
        setState(() {
          _currentUser = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e'); // Debug log
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถโหลดข้อมูลได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // เพิ่มฟังก์ชันสำหรับไปหน้าแก้ไขโปรไฟล์
  Future<void> _navigateToProfileUpdate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileUpdateScreen(),
      ),
    );
    
    // ถ้าแก้ไขข้อมูลสำเร็จ ให้โหลดข้อมูลใหม่
    if (result == true) {
      print('Profile updated, reloading user data...'); // Debug log
      await _loadUserData();
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบหรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _authService.signOut();
                // AuthWrapper จะจัดการการนำทางไปหน้า Login อัตโนมัติ
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ไม่สามารถออกจากระบบได้: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ออกจากระบบ',
              style: TextStyle(color: Colors.red),
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
        title: const Text('Vehicle Plate Scanner'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // เพิ่มปุ่มรีเฟรชข้อมูล
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[700]!, Colors.blue[500]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยินดีต้อนรับ!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentUser?.displayName ?? 'ผู้ใช้งาน',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                          ),
                        ),
                        // แก้ไขเงื่อนไขการแสดงป้ายทะเบียน
                        if (_currentUser?.hasLicensePlate == true) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ป้ายทะเบียน: ${_currentUser!.licensePlateNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Menu Title
                  Text(
                    'เมนูหลัก',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Scan Button
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/scanner');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.qr_code_scanner,
                                size: 40,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'สแกนป้ายทะเบียน',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ค้นหาข้อมูลจากป้ายทะเบียนรถ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Profile Card - แก้ไขให้ใช้ฟังก์ชันใหม่
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: _navigateToProfileUpdate, // ใช้ฟังก์ชันใหม่
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 40,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'อัปเดตข้อมูลส่วนตัว',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'จัดการข้อมูลส่วนตัวและการตั้งค่า',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // // History Card (Demo)
                  // Card(
                  //   elevation: 4,
                  //   shape: RoundedRectangleBorder(
                  //     borderRadius: BorderRadius.circular(16),
                  //   ),
                  //   child: Container(
                  //     padding: const EdgeInsets.all(24),
                  //     child: Row(
                  //       children: [
                  //         Container(
                  //           padding: const EdgeInsets.all(12),
                  //           decoration: BoxDecoration(
                  //             color: Colors.orange[50],
                  //             borderRadius: BorderRadius.circular(12),
                  //           ),
                  //           child: Icon(
                  //             Icons.history,
                  //             size: 40,
                  //             color: Colors.orange[700],
                  //           ),
                  //         ),
                  //         const SizedBox(width: 20),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               const Text(
                  //                 'ประวัติการสแกน',
                  //                 style: TextStyle(
                  //                   fontSize: 18,
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 4),
                  //               Text(
                  //                 'ดูประวัติการค้นหาที่ผ่านมา',
                  //                 style: TextStyle(
                  //                   fontSize: 14,
                  //                   color: Colors.grey[600],
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //         Container(
                  //           padding: const EdgeInsets.symmetric(
                  //             horizontal: 12,
                  //             vertical: 6,
                  //           ),
                  //           decoration: BoxDecoration(
                  //             color: Colors.grey[200],
                  //             borderRadius: BorderRadius.circular(20),
                  //           ),
                  //           child: Text(
                  //             'เร็วๆ นี้',
                  //             style: TextStyle(
                  //               fontSize: 12,
                  //               color: Colors.grey[600],
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),

                  const Spacer(),

                  // Footer Info
                  Center(
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ข้อมูลส่วนตัว'),
        content: _currentUser == null
            ? const Text('ไม่สามารถโหลดข้อมูลได้')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แสดงเฉพาะข้อมูลที่มี ไม่แสดงข้อความ "ยังไม่ได้ระบุ"
                  
                  // อีเมล (แสดงเสมอเพราะเป็น required)
                  _buildInfoRow('อีเมล', _currentUser!.email),
                  
                  // โทรศัพท์ (แสดงเฉพาะเมื่อมีข้อมูล)
                  if (_currentUser!.hasPhoneNumber)
                    _buildInfoRow('โทรศัพท์', _currentUser!.phoneNumber!),
                  
                  // ป้ายทะเบียน (แสดงเฉพาะเมื่อมีข้อมูล)
                  if (_currentUser!.hasLicensePlate)
                    _buildInfoRow('ป้ายทะเบียน', _currentUser!.licensePlateNumber!),
                  
                  // ชื่อ (แสดงเฉพาะเมื่อมีข้อมูล)
                  if (_currentUser!.hasName)
                    _buildInfoRow('ชื่อ', _currentUser!.name!),
                  
                  // Facebook (แสดงเฉพาะเมื่อมีข้อมูล)
                  if (_currentUser!.hasFacebook)
                    _buildInfoRow('Facebook', _currentUser!.facebook!),
                  
                  // ข้อมูลเพิ่มเติม (แสดงเฉพาะเมื่อมีข้อมูล)
                  if (_currentUser!.additionalInfo != null &&
                      _currentUser!.additionalInfo!.isNotEmpty)
                    _buildInfoRow('ข้อมูลเพิ่มเติม', _currentUser!.additionalInfo!),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // ปุ่มแก้ไขข้อมูล - แก้ไขให้ใช้ฟังก์ชันใหม่
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context); // ปิด dialog ปัจจุบัน
                        await _navigateToProfileUpdate(); // ใช้ฟังก์ชันใหม่
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('แก้ไขข้อมูล'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
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
}