// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:image_picker/image_picker.dart';
// import '../services/plate_recognition_service.dart';

// class TestAssetsScreen extends StatefulWidget {
//   const TestAssetsScreen({super.key});

//   @override
//   State<TestAssetsScreen> createState() => _TestAssetsScreenState();
// }

// class _TestAssetsScreenState extends State<TestAssetsScreen> {
//   final List<Map<String, String>> _testImages = [
//     {
//       'path': 'assets/test_plates/3603.jpg',
//       'name': 'ภาพทดสอบ 1',
//       'description': 'ป้ายทะเบียนรถยนต์',
//     },
//     {
//       'path': 'assets/test_plates/4992.jpg',
//       'name': 'ภาพทดสอบ 2',
//       'description': 'ป้ายทะเบียนรถจักรยานยนต์',
//     },
//     {
//       'path': 'assets/test_plates/6557.jpg',
//       'name': 'ภาพทดสอบ 3',
//       'description': 'ป้ายทะเบียนพิเศษ',
//     },
//   ];
  
//   late PlateRecognitionService _recognitionService;
//   bool _isProcessing = false;
//   String? _result;
  
//   @override
//   void initState() {
//     super.initState();
//     _recognitionService = PlateRecognitionService();
//   }
  
//   @override
//   void dispose() {
//     _recognitionService.dispose();
//     super.dispose();
//   }
  
//   Future<void> _processAssetImage(String assetPath) async {
//     setState(() {
//       _isProcessing = true;
//       _result = null;
//     });
    
//     try {
//       // แปลง asset เป็น File
//       final byteData = await rootBundle.load(assetPath);
//       final buffer = byteData.buffer;
      
//       final tempDir = await getTemporaryDirectory();
//       final tempPath = '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
//       final file = File(tempPath);
//       await file.writeAsBytes(
//         buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes)
//       );
      
//       final xFile = XFile(file.path);
      
//       // ประมวลผลภาพ
//       final result = await _recognitionService.processImage(xFile);
      
//       setState(() {
//         _result = result ?? 'ไม่พบป้ายทะเบียน';
//         _isProcessing = false;
//       });
      
//       // แสดงผลลัพธ์
//       _showResultDialog(result);
      
//     } catch (e) {
//       setState(() {
//         _result = 'Error: $e';
//         _isProcessing = false;
//       });
//     }
//   }
  
//   void _showResultDialog(String? result) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('ผลการประมวลผล'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(
//               result != null ? Icons.check_circle : Icons.error,
//               size: 48,
//               color: result != null ? Colors.green : Colors.red,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               result ?? 'ไม่พบป้ายทะเบียน',
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('ตกลง'),
//           ),
//         ],
//       ),
//     );
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('ภาพทดสอบ'),
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           if (_isProcessing)
//             const LinearProgressIndicator(),
          
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: _testImages.length,
//               itemBuilder: (context, index) {
//                 final image = _testImages[index];
                
//                 return Card(
//                   margin: const EdgeInsets.only(bottom: 16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // แสดงภาพ
//                       Container(
//                         height: 200,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           borderRadius: const BorderRadius.vertical(
//                             top: Radius.circular(12),
//                           ),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: const BorderRadius.vertical(
//                             top: Radius.circular(12),
//                           ),
//                           child: Image.asset(
//                             image['path']!,
//                             fit: BoxFit.cover,
//                             errorBuilder: (context, error, stackTrace) {
//                               return Container(
//                                 color: Colors.grey[300],
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     const Icon(
//                                       Icons.error,
//                                       size: 48,
//                                       color: Colors.red,
//                                     ),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       'ไม่พบภาพ',
//                                       style: TextStyle(color: Colors.grey[600]),
//                                     ),
//                                   ],
//                                 ),
//                               );
//                             },
//                           ),
//                         ),
//                       ),
                      
//                       // ข้อมูลภาพ
//                       Padding(
//                         padding: const EdgeInsets.all(16),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               image['name']!,
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               image['description']!,
//                               style: TextStyle(
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             SizedBox(
//                               width: double.infinity,
//                               child: ElevatedButton.icon(
//                                 onPressed: _isProcessing 
//                                   ? null 
//                                   : () => _processAssetImage(image['path']!),
//                                 icon: const Icon(Icons.play_arrow),
//                                 label: const Text('ประมวลผลภาพนี้'),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.blue[700],
//                                   foregroundColor: Colors.white,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ),
          
//           if (_result != null)
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(16),
//               color: Colors.blue[50],
//               child: Column(
//                 children: [
//                   const Text(
//                     'ผลลัพธ์ล่าสุด:',
//                     style: TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     _result!,
//                     style: const TextStyle(fontSize: 16),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }