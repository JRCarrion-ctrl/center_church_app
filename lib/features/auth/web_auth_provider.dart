// file: lib/features/auth/web_auth_provider.dart

// 1. Export the stub by default (for Mobile/Desktop)
export 'web_auth_stub.dart' 
  // 2. If the compiler sees JS Interop (Web), swap it for the real deal
  if (dart.library.js_interop) 'web_auth_web.dart';