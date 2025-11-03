import 'package:cactus/src/thread_bindings.dart';

void getThreadPriorityObjC() {
  final currentThread = NSThread.getCurrentThread();
  final priority = currentThread.threadPriority$1;
  print('NSThread.getCurrentThread().threadPriority: $priority');
}
