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
  double ttft = 0;
  final lm = CactusLM();

  Future<void> generateStreamCompletion({bool performanceMode = false}) async {
    try {
      final streamedResult = await lm.generateCompletion(
        modelUrl:
            'https://vlqqczxwyaodtcdmdmlw.supabase.co/storage/v1/object/public/cactus-models/qwen3-0.6.zip',
        prompt: 'Hello, how are you?',
        usePerformanceMode: performanceMode,
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
          ttft = resp.timeToFirstTokenMs;
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Streaming Completion'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  generateStreamCompletion(performanceMode: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Generate (Isolates)'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  generateStreamCompletion(performanceMode: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Generate (Main Thread)'),
              ),

              const SizedBox(height: 20),

              // Output section
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (response != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Response:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              response!,
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'TTFT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  '${ttft.toStringAsFixed(2)} ms',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'TPS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  tps.toStringAsFixed(2),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
