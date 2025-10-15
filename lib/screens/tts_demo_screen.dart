import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSDemoScreen extends StatefulWidget {
  const TTSDemoScreen({super.key});

  @override
  State<TTSDemoScreen> createState() => _TTSDemoScreenState();
}

class _TTSDemoScreenState extends State<TTSDemoScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final TextEditingController _controller = TextEditingController();

  Future<void> _speak() async {
    String text = _controller.text.trim();
    if (text.isEmpty) return;

    await flutterTts.setLanguage("th-TH"); // ตั้งภาษาเป็นไทย
    await flutterTts.setPitch(1.0);        // ระดับเสียง
    await flutterTts.setSpeechRate(0.5);   // ความเร็วในการพูด
    await flutterTts.speak(text);          // ให้พูดข้อความ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("สาธิตระบบ Text-to-Speech (TTS)"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "พิมพ์ข้อความภาษาไทยที่ต้องการให้พูด",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _speak,
              icon: const Icon(Icons.volume_up),
              label: const Text("พูดข้อความ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
