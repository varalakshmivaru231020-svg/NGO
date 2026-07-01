// Generic key/value local store — web uses localStorage, other platforms use
// an in-memory map (good enough for the demo build).
export 'kv_store_stub.dart' if (dart.library.html) 'kv_store_web.dart';
