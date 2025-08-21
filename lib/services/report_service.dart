import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailController = TextEditingController();
  String? _selectedLocation;

  final List<String> _locations = [
    'ที่จอดรถด้านหน้าคณะ (ติดถนน)',
    'ที่จอดรถหลังคณะ (ติดรางรถไฟ)',
    'ด้านหน้าตึกจุฯ1',
    'อื่น ๆ'
  ];

  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLocation == null) {
      _showErrorDialog("กรุณาเลือกสถานที่");
      return;
    }

    final userId = _authService.getCurrentUserId();
    if (userId == null) {
      _showErrorDialog('ไม่พบผู้ใช้งาน กรุณา login ก่อน');
      return;
    }

    try {
      final role = await _authService.getUserRole();

      // บันทึกรายงานลง Firestore
      await _databaseService.addReport(
        userId: userId,
        role: role,
        location: _selectedLocation!,
        description: _detailController.text,
      );

      // ✅ แสดง Snackbar แทน Notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("ส่งรายงานเรียบร้อย"),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // รีเซ็ต form
      setState(() {
        _selectedLocation = null;
        _detailController.clear();
      });
    } catch (e) {
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red[600]),
            const SizedBox(width: 8),
            const Text("ข้อผิดพลาด"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("ตกลง"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("รายงานปัญหา"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: "เลือกสถานที่", border: OutlineInputBorder()),
                value: _selectedLocation,
                items: _locations
                    .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLocation = val),
                validator: (value) =>
                    value == null ? "กรุณาเลือกสถานที่" : null,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _detailController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: "รายละเอียดเพิ่มเติม",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: "ส่ง",
                onPressed: _submitReport,
                color: Colors.green[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
