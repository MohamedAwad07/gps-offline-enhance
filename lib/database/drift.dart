import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'drift.g.dart';

class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 6, max: 32)();
  TextColumn get description => text()();
  BoolColumn get isCompleted => boolean().nullable()();
}

@DriftDatabase(tables: [TodoItems])
class AppDatabase extends _$AppDatabase {
   AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());


  @override 
  int get schemaVersion => 1;
  
  static QueryExecutor _openConnection() {
     return driftDatabase(
      name: 'todo_db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  
}
