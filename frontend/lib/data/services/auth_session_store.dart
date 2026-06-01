export 'auth_session_store_unsupported.dart'
    if (dart.library.html) 'auth_session_store_web.dart'
    if (dart.library.io) 'auth_session_store_native.dart';
