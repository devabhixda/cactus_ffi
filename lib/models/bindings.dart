import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class CactusModelOpaque extends Opaque {}
typedef CactusModel = Pointer<CactusModelOpaque>;

// Vosk model types
final class VoskModelOpaque extends Opaque {}
typedef VoskModel = Pointer<VoskModelOpaque>;

final class VoskSpkModelOpaque extends Opaque {}
typedef VoskSpkModel = Pointer<VoskSpkModelOpaque>;

final class VoskRecognizerOpaque extends Opaque {}
typedef VoskRecognizer = Pointer<VoskRecognizerOpaque>;

typedef CactusTokenCallbackNative = Void Function(Pointer<Utf8> token, Uint32 tokenId, Pointer<Void> userData);
typedef CactusTokenCallbackDart = void Function(Pointer<Utf8> token, int tokenId, Pointer<Void> userData);

typedef CactusInitNative = CactusModel Function(Pointer<Utf8> modelPath, Size contextSize);
typedef CactusInitDart = CactusModel Function(Pointer<Utf8> modelPath, int contextSize);

typedef CactusCompleteNative = Int32 Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    Size bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<Utf8> toolsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);
typedef CactusCompleteDart = int Function(
    CactusModel model,
    Pointer<Utf8> messagesJson,
    Pointer<Utf8> responseBuffer,
    int bufferSize,
    Pointer<Utf8> optionsJson,
    Pointer<Utf8> toolsJson,
    Pointer<NativeFunction<CactusTokenCallbackNative>> callback,
    Pointer<Void> userData);

typedef CactusDestroyNative = Void Function(CactusModel model);
typedef CactusDestroyDart = void Function(CactusModel model);