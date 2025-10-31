// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'package:ffi/ffi.dart';

// C function type for pthread_t pthread_self(void);
typedef PthreadSelfNative = Pointer<Opaque> Function();
typedef PthreadSelfDart = Pointer<Opaque> Function();

// C function type for int pthread_getschedparam(pthread_t, int*, struct sched_param*);
typedef PthreadGetSchedParamNative =
    Int32 Function(
      Pointer<Opaque> thread,
      Pointer<Int32> policy,
      Pointer<SchedParam> param,
    );
typedef PthreadGetSchedParamDart =
    int Function(
      Pointer<Opaque> thread,
      Pointer<Int32> policy,
      Pointer<SchedParam> param,
    );

// Define the SchedParam structure using FFI structs
final class SchedParam extends Struct {
  @Int32()
  external int sched_priority;
}

// Load the dynamic library for the current process
final DynamicLibrary dylib = DynamicLibrary.process();

// Look up the functions
final pthreadSelf = dylib.lookupFunction<PthreadSelfNative, PthreadSelfDart>(
  'pthread_self',
);

final pthreadGetSchedParam = dylib
    .lookupFunction<PthreadGetSchedParamNative, PthreadGetSchedParamDart>(
      'pthread_getschedparam',
    );

void getThreadPriorityDirectly() {
  // Allocate memory for the output parameters
  final policyPtr = calloc<Int32>();
  final paramPtr = calloc<SchedParam>();

  try {
    // 1. Get the current thread handle
    final currentThread = pthreadSelf();

    // 2. Get the scheduling parameters
    final result = pthreadGetSchedParam(currentThread, policyPtr, paramPtr);

    if (result == 0) {
      final priority = paramPtr.ref.sched_priority;
      final policy = policyPtr.value;
      print('Current thread priority (raw): $priority, policy: $policy');
    } else {
      print('Error getting scheduling parameters: $result');
    }
  } finally {
    // Free the allocated memory
    calloc.free(policyPtr);
    calloc.free(paramPtr);
  }
}
