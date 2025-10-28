import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:cactus/models/bindings.dart';

String _getLibraryPath(String libName) {
  if (Platform.isIOS || Platform.isMacOS) {
    return '$libName.framework/$libName';
  }
  if (Platform.isAndroid) {
    return 'lib$libName.so';
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final DynamicLibrary cactusLib = DynamicLibrary.open(_getLibraryPath('cactus'));

final cactusInit = cactusLib
    .lookup<NativeFunction<CactusInitNative>>('cactus_init')
    .asFunction<CactusInitDart>();

final cactusComplete = cactusLib
    .lookup<NativeFunction<CactusCompleteNative>>('cactus_complete')
    .asFunction<CactusCompleteDart>();

final cactusDestroy = cactusLib
    .lookup<NativeFunction<CactusDestroyNative>>('cactus_destroy')
    .asFunction<CactusDestroyDart>();