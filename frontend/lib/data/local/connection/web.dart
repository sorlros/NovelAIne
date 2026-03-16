import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openConnection() {
  // 사용자가 web/ 폴더에 넣은 sqlite3.wasm 및 drift_worker.js 파일을 사용하여
  // 고성능 WASM 데이터베이스를 엽니다. 이제 sql.js 에러가 발생하지 않습니다.
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'novelaine_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
