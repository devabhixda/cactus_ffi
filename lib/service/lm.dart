import 'dart:async';

import 'package:cactus/service/context.dart';
import 'package:cactus/models/types.dart';
import 'package:cactus/service/downloader.dart';
import 'package:path_provider/path_provider.dart';


class CactusLM {
  int? _handle;

  Future<CactusStreamedCompletionResult> generateCompletion({
    required String prompt,
    required String modelUrl,
    String? cactusToken,
    bool? usePerformanceMode,
  }) async {
    final actualFilename = modelUrl.split('/').last;
    final modelFolder = modelUrl.split('/').last.replaceAll('.zip', '');
    final success = await downloadAndExtractModel(modelUrl, actualFilename, modelFolder);

    if(!success) {
      throw Exception('Failed to download and extract model from $modelUrl');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDocDir.path}/$modelFolder';

    _handle = await CactusContext.initContext(modelPath, 2048);

    if(_handle == null) {
      throw Exception('Cactus model is not loaded. Please load the model before generating completions.');
    }    
    return CactusContext.completionStream(
      _handle!, 
      [ChatMessage(content: '/no_think $prompt', role: 'user')],
      performanceMode: usePerformanceMode ?? false,
    );
  }

  void unload() {
    final currentHandle = _handle;
    if (currentHandle != null) {
      CactusContext.freeContext(currentHandle);
      _handle = null;
    }
  }

  bool isLoaded() => _handle != null;
}