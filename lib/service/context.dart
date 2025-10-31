import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cactus/models/types.dart';
import 'package:cactus/models/bindings.dart';
import 'package:cactus/service/pthread_priority.dart';
import 'package:cactus/service/thread_priority.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'bindings.dart' as bindings;

// Global callback storage for streaming completions
CactusTokenCallback? _activeTokenCallback;

// Static callback function that can be used with Pointer.fromFunction
@pragma('vm:entry-point')
void _staticTokenCallbackDispatcher(
  Pointer<Utf8> tokenC,
  int tokenId,
  Pointer<Void> userData,
) {
  try {
    final callback = _activeTokenCallback;
    if (callback != null) {
      final tokenString = tokenC.toDartString();
      callback(tokenString);
    }
  } catch (e) {
    debugPrint('Token callback error: $e');
  }
}

Future<int?> _initContextInIsolate(Map<String, dynamic> params) async {
  Timeline.startSync('isolate_init_context');
  try {
    final modelPath = params['modelPath'] as String;
    final contextSize = params['contextSize'] as int;

    try {
      debugPrint(
        'Initializing context with model: $modelPath, contextSize: $contextSize',
      );
      final modelPathC = modelPath.toNativeUtf8(allocator: calloc);
      try {
        Timeline.startSync('ffi_cactusInit');
        final handle = bindings.cactusInit(modelPathC, contextSize);
        Timeline.finishSync();

        if (handle != nullptr) {
          return handle.address;
        } else {
          return null;
        }
      } finally {
        calloc.free(modelPathC);
      }
    } catch (e) {
      return null;
    }
  } finally {
    Timeline.finishSync(); // isolate_init_context
  }
}

Future<CactusCompletionResult> _completionInIsolate(
  Map<String, dynamic> params,
) async {
  Timeline.startSync('isolate_completion');
  try {
    final handle = params['handle'] as int;
    final messagesJson = params['messagesJson'] as String;
    final bufferSize = params['bufferSize'] as int;
    final hasCallback = params['hasCallback'] as bool;
    final SendPort? replyPort = params['replyPort'] as SendPort?;

    final responseBuffer = calloc<Uint8>(bufferSize);
    final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);

    Pointer<NativeFunction<CactusTokenCallbackNative>>? callbackPointer;

    try {
      if (hasCallback && replyPort != null) {
        // Set up token callback to send tokens back through isolate
        _activeTokenCallback = (token) {
          replyPort.send({'type': 'token', 'data': token});
          return true; // Always continue in isolate mode
        };

        callbackPointer = Pointer.fromFunction<CactusTokenCallbackNative>(
          _staticTokenCallbackDispatcher,
        );
      }

      Timeline.startSync('ffi_cactusComplete');
      final result = bindings.cactusComplete(
        Pointer.fromAddress(handle),
        messagesJsonC,
        responseBuffer.cast<Utf8>(),
        bufferSize,
        nullptr,
        nullptr,
        callbackPointer ?? nullptr,
        nullptr,
      );
      getThreadPriorityDirectly();
      getThreadPriorityObjC();
      Timeline.finishSync();

      return CactusContext._parseCompletionResponse(responseBuffer, result);
    } finally {
      _activeTokenCallback = null;
      calloc.free(responseBuffer);
      calloc.free(messagesJsonC);
    }
  } finally {
    Timeline.finishSync(); // isolate_completion
  }
}

class CactusContext {
  static String _escapeJsonString(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  static CactusCompletionResult _parseCompletionResponse(
    Pointer<Uint8> responseBuffer,
    int resultCode,
  ) {
    debugPrint('Received completion result code: $resultCode');

    if (resultCode > 0) {
      final responseText = utf8
          .decode(responseBuffer.asTypedList(resultCode), allowMalformed: true)
          .trim();

      try {
        final jsonResponse = jsonDecode(responseText) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? true;
        final response = jsonResponse['response'] as String? ?? responseText;
        final timeToFirstTokenMs =
            (jsonResponse['time_to_first_token_ms'] as num?)?.toDouble() ?? 0.0;
        final totalTimeMs =
            (jsonResponse['total_time_ms'] as num?)?.toDouble() ?? 0.0;
        final tokensPerSecond =
            (jsonResponse['tokens_per_second'] as num?)?.toDouble() ?? 0.0;
        final prefillTokens = jsonResponse['prefill_tokens'] as int? ?? 0;
        final decodeTokens = jsonResponse['decode_tokens'] as int? ?? 0;
        final totalTokens = jsonResponse['total_tokens'] as int? ?? 0;

        return CactusCompletionResult(
          success: success,
          response: response,
          timeToFirstTokenMs: timeToFirstTokenMs,
          totalTimeMs: totalTimeMs,
          tokensPerSecond: tokensPerSecond,
          prefillTokens: prefillTokens,
          decodeTokens: decodeTokens,
          totalTokens: totalTokens,
        );
      } catch (e) {
        debugPrint('Unable to parse the response json: $e');
        return CactusCompletionResult(
          success: false,
          response: 'Error: Unable to parse the response',
        );
      }
    } else {
      return CactusCompletionResult(
        success: false,
        response: 'Error: completion failed with code $resultCode',
      );
    }
  }

  static Map<String, String?> _prepareCompletionJson(
    List<ChatMessage> messages,
  ) {
    // Prepare messages JSON
    final messagesJsonBuffer = StringBuffer('[');
    for (int i = 0; i < messages.length; i++) {
      if (i > 0) messagesJsonBuffer.write(',');
      messagesJsonBuffer.write('{');
      messagesJsonBuffer.write('"role":"${messages[i].role}",');
      messagesJsonBuffer.write(
        '"content":"${_escapeJsonString(messages[i].content)}"',
      );
      messagesJsonBuffer.write('}');
    }
    messagesJsonBuffer.write(']');
    final messagesJson = messagesJsonBuffer.toString();

    return {'messagesJson': messagesJson};
  }

  static Future<int?> initContext(String modelPath, int contextSize) async {
    // Run the heavy initialization in an isolate using compute
    final isolateParams = {'modelPath': modelPath, 'contextSize': contextSize};

    return await compute(_initContextInIsolate, isolateParams);
  }

  static void freeContext(int handle) {
    try {
      bindings.cactusDestroy(Pointer.fromAddress(handle));
      debugPrint('Context destroyed');
    } catch (e) {
      debugPrint('Error destroying context: $e');
    }
  }

  static CactusStreamedCompletionResult completionStream(
    int handle,
    List<ChatMessage> messages, {
    bool performanceMode = false,
  }) {
    if (performanceMode) {
      return _completionStreamDirect(handle, messages);
    } else {
      return _completionStreamIsolate(handle, messages);
    }
  }

  static CactusStreamedCompletionResult _completionStreamDirect(
    int handle,
    List<ChatMessage> messages,
  ) {
    final jsonData = _prepareCompletionJson(messages);
    final controller = StreamController<String>();
    final resultCompleter = Completer<CactusCompletionResult>();

    // Run completion directly on the main thread
    Future(() async {
      try {
        final messagesJson = jsonData['messagesJson']!;
        const bufferSize = 4096;
        final responseBuffer = calloc<Uint8>(bufferSize);
        final messagesJsonC = messagesJson.toNativeUtf8(allocator: calloc);

        Pointer<NativeFunction<CactusTokenCallbackNative>>? callbackPointer;

        try {
          // Set up token callback to stream tokens
          _activeTokenCallback = (token) {
            controller.add(token);
            return true;
          };

          callbackPointer = Pointer.fromFunction<CactusTokenCallbackNative>(
            _staticTokenCallbackDispatcher,
          );

          Timeline.startSync('ffi_cactusComplete_direct');
          final result = bindings.cactusComplete(
            Pointer.fromAddress(handle),
            messagesJsonC,
            responseBuffer.cast<Utf8>(),
            bufferSize,
            nullptr,
            nullptr,
            callbackPointer,
            nullptr,
          );
          getThreadPriorityDirectly();
          getThreadPriorityObjC();
          Timeline.finishSync();

          final completionResult = CactusContext._parseCompletionResponse(
            responseBuffer,
            result,
          );
          resultCompleter.complete(completionResult);
          controller.close();
        } finally {
          _activeTokenCallback = null;
          calloc.free(responseBuffer);
          calloc.free(messagesJsonC);
        }
      } catch (e) {
        debugPrint('Error in direct completion: $e');
        final errorResult = CactusCompletionResult(
          success: false,
          response: 'Error: $e',
        );
        resultCompleter.complete(errorResult);
        controller.addError(e);
        controller.close();
      }
    });

    return CactusStreamedCompletionResult(
      stream: controller.stream,
      result: resultCompleter.future,
    );
  }

  static CactusStreamedCompletionResult _completionStreamIsolate(
    int handle,
    List<ChatMessage> messages,
  ) {
    final jsonData = _prepareCompletionJson(messages);

    final controller = StreamController<String>();
    final resultCompleter = Completer<CactusCompletionResult>();
    final replyPort = ReceivePort();

    late StreamSubscription subscription;
    subscription = replyPort.listen((message) {
      if (message is Map) {
        final type = message['type'] as String;
        if (type == 'token') {
          final token = message['data'] as String;
          controller.add(token);
        } else if (type == 'result') {
          final result = message['data'] as CactusCompletionResult;
          resultCompleter.complete(result);
          controller.close();
          subscription.cancel();
          replyPort.close();
        } else if (type == 'error') {
          final error = message['data'];
          if (error is CactusCompletionResult) {
            resultCompleter.complete(error);
          } else {
            resultCompleter.completeError(error.toString());
          }
          controller.addError(error);
          controller.close();
          subscription.cancel();
          replyPort.close();
        }
      }
    });

    Isolate.spawn(_isolateCompletionEntry, {
      'handle': handle,
      'messagesJson': jsonData['messagesJson']!,
      'bufferSize': 4096,
      'hasCallback': true,
      'replyPort': replyPort.sendPort,
    });

    return CactusStreamedCompletionResult(
      stream: controller.stream,
      result: resultCompleter.future,
    );
  }

  static Future<void> _isolateCompletionEntry(
    Map<String, dynamic> params,
  ) async {
    final replyPort = params['replyPort'] as SendPort;
    try {
      final result = await _completionInIsolate(params);
      if (result.success) {
        replyPort.send({'type': 'result', 'data': result});
      } else {
        replyPort.send({'type': 'error', 'data': result});
      }
    } catch (e) {
      replyPort.send({'type': 'error', 'data': e.toString()});
    }
  }
}
