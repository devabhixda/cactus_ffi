import 'package:cactus/service/lm.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {

  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  String? response;
  final lm = CactusLM();

  Future<void> generateStreamCompletion() async {
    
    try {
      final streamedResult = await lm.generateCompletion(
        modelUrl: 'https://example.com/path/to/cactus-model.zip',
        prompt: 'Hello, how are you?'
      );

      await for (final chunk in streamedResult.stream) {
        setState(() {
          response = (response ?? '') + chunk;
        });
      }
      
      final resp = await streamedResult.result;
      if (resp.success) {
        setState(() {
          response = resp.response;
        });
      } 
    } catch (e) {
      debugPrint('Error generating stream response: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Cactus LM Stream Completion Example'),
              ElevatedButton(onPressed: generateStreamCompletion, child: const Text('Generate')),
              if (response != null) ...[
                const SizedBox(height: 20),
                Text(response ?? ''),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
