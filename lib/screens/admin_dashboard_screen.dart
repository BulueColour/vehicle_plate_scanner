import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../screens/profile_update_screen.dart';
import 'package:flutter/services.dart';

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
  bool _soundEnabled = true; // ใช้เปิด-ปิดเสียงแจ้งเตือน

  // สำหรับ stream รายงาน
  Stream<QuerySnapshot>? _reportStream;
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initReportStream();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        final userData = await _databaseService.getUser(firebaseUser.uid);

        setState(() {
          _currentUser = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
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

  void _initReportStream() {
    _reportStream = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
        
    _reportStream!.listen(
      (snapshot) {
        // ตรวจสอบเฉพาะรายงานที่เพิ่มใหม่
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final timestamp = data['createdAt'] as Timestamp?;
              
              if (timestamp != null) {
                final reportTime = timestamp.toDate();
                
                // แจ้งเตือนเฉพาะรายงานที่สร้างหลังจากเปิดแอป
                if (reportTime.isAfter(_appStartTime) && mounted) {
                  _showNewReportNotification(data);
                }
              }
            }
          }
        }
      },
      onError: (error) {
        print('Error listening to reports: $error');
      },
    );
  }

  Future<void> _showNewReportNotification(Map<String, dynamic> data) async {
    if (_soundEnabled) {
      await _playSystemNotificationSound();
    }

    // แจ้งเตือน
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายงานใหม่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'สถานที่: ${data['location'] ?? 'ไม่ระบุสถานที่'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          duration: const Duration(seconds:4),
          backgroundColor: Colors.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'ดูรายงาน',
            textColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
            onPressed: () {
              _showReportDetails(context, data);
            },
          ),
        ),
      );
    }

    // ใส่การสั่นเข้าไปด้วย
    if (_soundEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _playSystemNotificationSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      print('Error playing system sound: $e');
    }
  }

  // test เสียงและการสั่นแจ้งเตือน
  Future<void> _testNotificationSound() async {
    await _playSystemNotificationSound();
    HapticFeedback.mediumImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ทดสอบเสียงและการสั่นแจ้งเตือน'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleSound() {
    setState(() {
      _soundEnabled = !_soundEnabled;
    });

    //เล่นเสียงทดสอบถ้าเปิดเสียง
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _soundEnabled ? 'เปิดเสียงแจ้งเตือนแล้ว' : 'ปิดเสียงแจ้งเตือนแล้ว',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Sound setting ที่ Appbar
  Widget _buildSoundControls() {
    return PopupMenuButton<String>(
      icon: Icon(
        _soundEnabled ? Icons.volume_up : Icons.volume_off,
        color: Colors.white,
      ),
      tooltip: 'ตั้งค่าเสียง',
      onSelected: (value) {
        switch (value) {
          case 'toggle':
            _toggleSound();
            break;
          case 'test':
            _testNotificationSound();
            break;
          case 'haptic_test':
            _testHapticFeedback();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle',
          child: Row(
            children: [
              Icon(
                _soundEnabled ? Icons.volume_off : Icons.volume_up,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(_soundEnabled ? 'ปิดเสียงแจ้งเตือน' : 'เปิดเสียงแจ้งเตือน'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'test',
          child: Row(
            children: [
              Icon(Icons.notifications, size: 20),
              SizedBox(width: 8),
              Text('ทดสอบเสียง'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'haptic_test',
          child: Row(
            children: [
              Icon(Icons.vibration, size: 20),
              SizedBox(width: 8),
              Text('ทดสอบการสั่น'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _testHapticFeedback() async {
    HapticFeedback.lightImpact();

    await Future.delayed(Duration(milliseconds: 200));
    HapticFeedback.mediumImpact();

    await Future.delayed(Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ทดสอบการสั่น: เบา > กลาง > แรง'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _navigateToProfileUpdate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileUpdateScreen(),
      ),
    );

    if (result == true) {
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

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.indigo[700],
        elevation: 0,
        actions: [
          _buildSoundControls(),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo[800]!, Colors.indigo[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ยินดีต้อนรับ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Admin: ${_currentUser?.displayName ?? _currentUser?.name ?? 'Administrator'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'สิทธิ์ผู้ดูแลระบบ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Main Menu Title
                  Row(
                    children: [
                      Icon(
                        Icons.dashboard,
                        color: Colors.indigo[700],
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'เมนูหลัก',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[800],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Scanner Card
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, '/scanner');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.blue[100]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 32,
                                  color: Colors.white,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'ค้นหาข้อมูลจากป้ายทะเบียนรถ',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'พร้อมใช้งาน',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.blue[600],
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Real-time Report List
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('reports')
                        .orderBy('createdAt', descending: true) // ✅ แก้ชื่อ field
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'กำลังโหลดรายการรายงาน...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[600],
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'เกิดข้อผิดพลาดในการโหลดข้อมูล',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'กรุณาลองรีเฟรชหน้าใหม่',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'ยังไม่มีรายงาน',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'รายการรายงานจะแสดงที่นี่เมื่อมีข้อมูล',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final reports = snapshot.data!.docs;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.report_outlined,
                                  color: Colors.deepPurple[700],
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'รายการรายงานล่าสุด',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple[800],
                                      ),
                                    ),
                                    Text(
                                      '${reports.length} รายการ (อัปเดตแบบเรียลไทม์)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.deepPurple[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Stats Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.deepPurple[600]!, Colors.deepPurple[400]!],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '${reports.length}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          // Reports List
                          ...reports.asMap().entries.map((entry) {
                            final index = entry.key;
                            final doc = entry.value;
                            final data = doc.data() as Map<String, dynamic>;
                            
                            // สำหรับการแสดงสถานะใหม่
                            final isNewReport = index < 3; // แสดง 3 รายการแรกเป็น "ใหม่"
                            
                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isNewReport ? Colors.deepPurple[200]! : Colors.grey[200]!,
                                    width: isNewReport ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    // สามารถเพิ่ม navigation ไปหน้าดูรายละเอียดรายงาน
                                    _showReportDetails(context, data);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row
                                        Row(
                                          children: [
                                            // Report Icon
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isNewReport 
                                                    ? Colors.deepPurple[100] 
                                                    : Colors.grey[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.location_on,
                                                color: isNewReport 
                                                    ? Colors.deepPurple[700] 
                                                    : Colors.grey[600],
                                                size: 20,
                                              ),
                                            ),
                                            
                                            SizedBox(width: 12),
                                            
                                            // Location Title
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          data['location'] ?? 'ไม่ระบุสถานที่',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                      // New Badge
                                                      if (isNewReport)
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal: 8, 
                                                            vertical: 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red[500],
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            'ใหม่',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  
                                                  SizedBox(height: 4),
                                                  
                                                  // Timestamp
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.access_time,
                                                        size: 14,
                                                        color: Colors.grey[600],
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        _formatTimestamp(data['createdAt'] as Timestamp?), // ✅ ใช้ชื่อ field ที่ถูกต้อง
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Arrow Icon
                                            Container(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(
                                                Icons.arrow_forward_ios,
                                                color: Colors.grey[400],
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        SizedBox(height: 12),
                                        
                                        // Description
                                        if (data['description'] != null && 
                                            data['description'].toString().isNotEmpty)
                                          Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.description_outlined,
                                                  size: 16,
                                                  color: Colors.grey[600],
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    data['description'].toString(),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                      height: 1.4,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // Additional Info (หากมีข้อมูลเพิ่มเติม)
                                        if (data['reportedBy'] != null)
                                          Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 14,
                                                  color: Colors.deepPurple[600],
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'รายงานโดย: ${data['reportedBy']}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.deepPurple[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),

                          // Show More Button (หากมีรายงานเยอะ)
                          if (reports.length > 5)
                            Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () {
                                    // Navigate to full reports list page
                                    Navigator.pushNamed(context, '/reports_list');
                                  },
                                  icon: Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'ดูรายงานทั้งหมด (${reports.length} รายการ)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.deepPurple[700],
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Vehicle Plate Scanner v1.0.0',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
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

  // เพิ่มฟังก์ชันนี้ใน _AdminDashboardScreenState class

void _showReportDetails(BuildContext context, Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.report_outlined,
                    color: Colors.deepPurple[700],
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'รายละเอียดรายงาน',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[800],
                        ),
                      ),
                      Text(
                        'ข้อมูลเพิ่มเติม',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.deepPurple[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),

            SizedBox(height: 24),

            // Content
            _buildDetailRow(
              icon: Icons.location_on,
              label: 'สถานที่',
              value: data['location'] ?? 'ไม่ระบุ',
              color: Colors.red,
            ),

            SizedBox(height: 16),

            _buildDetailRow(
              icon: Icons.access_time,
              label: 'วันที่และเวลา',
              value: _formatTimestamp(data['createdAt'] as Timestamp?),
              color: Colors.blue,
            ),

            if (data['description'] != null && 
                data['description'].toString().isNotEmpty) ...[
              SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.description,
                label: 'รายละเอียด',
                value: data['description'].toString(),
                color: Colors.green,
                isMultiline: true,
              ),
            ],

            if (data['reportedBy'] != null) ...[
              SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.person,
                label: 'รายงานโดย',
                value: data['reportedBy'].toString(),
                color: Colors.deepPurple,
              ),
            ],

            if (data['licensePlate'] != null) ...[
              SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.directions_car,
                label: 'ป้ายทะเบียน',
                value: data['licensePlate'].toString(),
                color: Colors.orange,
              ),
            ],

            // Additional fields ที่อาจมี
            if (data['status'] != null) ...[
              SizedBox(height: 16),
              _buildDetailRow(
                icon: Icons.info,
                label: 'สถานะ',
                value: data['status'].toString(),
                color: Colors.teal,
              ),
            ],

            SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

// Helper function สำหรับสร้าง detail row
Widget _buildDetailRow({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  bool isMultiline = false,
}) {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.grey,
            size: 20,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  height: isMultiline ? 1.4 : null,
                ),
                maxLines: isMultiline ? null : 1,
                overflow: isMultiline ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ฟังก์ชันจัดการรายงาน (สามารถปรับแต่งได้)
void _handleReport(Map<String, dynamic> data) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('จัดการรายงาน'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คุณต้องการดำเนินการกับรายงานนี้อย่างไร?'),
          SizedBox(height: 16),
          Text(
            'สถานที่: ${data['location'] ?? 'ไม่ระบุ'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple[700],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // เพิ่มฟังก์ชัน mark as resolved
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ทำเครื่องหมายเป็นแก้ไขแล้ว'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: Text('แก้ไขแล้ว'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // เพิ่มฟังก์ชัน investigate
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('กำลังตรวจสอบรายงาน'),
                backgroundColor: Colors.orange,
              ),
            );
          },
          child: Text('ตรวจสอบ'),
        ),
      ],
    ),
  );
}
}
