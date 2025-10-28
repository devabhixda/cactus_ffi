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
  double tps = 0;
  int tokens = 0;
  final lm = CactusLM();

  Future<void> generateStreamCompletion() async {
    
    try {
      final streamedResult = await lm.generateCompletion(
        modelUrl: 'https://vlqqczxwyaodtcdmdmlw.supabase.co/storage/v1/object/public/cactus-models/qwen3-0.6.zip',
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
          tps = resp.tokensPerSecond;
          tokens = resp.totalTokens;
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
          child: Padding(
            padding: EdgeInsetsGeometry.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Cactus LM'),
                SizedBox(height: 20),
                ElevatedButton(onPressed: generateStreamCompletion, child: const Text('Generate')),
                if (response != null) ...[
                  Text(response ?? ''),
                ],
                if (tokens > 0) ...[
                  const SizedBox(height: 10),
                  Text('Total Tokens: $tokens, Tokens per Second: ${tps.toStringAsFixed(2)}'),
                ],
              ],
            )
          )
        ),
      ),
    );
  }
}
