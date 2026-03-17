// 이 파일은 플랫폼별 구현체를 연결하는 스텁(Stub) 역할을 합니다.
export 'unsupported.dart'
    if (dart.library.js_interop) 'web.dart'
    if (dart.library.io) 'native.dart';
