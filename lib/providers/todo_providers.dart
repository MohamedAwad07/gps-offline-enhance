import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../database/drift.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final todoListProvider = FutureProvider<List<TodoItem>>((ref) async {
  final database = ref.watch(databaseProvider);
  return await database.select(database.todoItems).get();
});

final todoOperationsProvider = Provider<TodoOperations>((ref) {
  final database = ref.watch(databaseProvider);
  return TodoOperations(database);
});

class TodoOperations {
  final AppDatabase _database;

  TodoOperations(this._database);

  Future<void> addTodo({
    required String title,
    required String description,
  }) async {
    final todo = TodoItemsCompanion.insert(
      title: title,
      description: description,
      isCompleted: const Value(false),
    );
    await _database.into(_database.todoItems).insert(todo);
  }

  Future<void> toggleTodo(TodoItem todo) async {
    await _database
        .update(_database.todoItems)
        .replace(
          TodoItemsCompanion(
            id: Value(todo.id),
            title: Value(todo.title),
            description: Value(todo.description),
            isCompleted: Value(!(todo.isCompleted ?? false)),
          ),
        );
  }

  Future<void> deleteTodo(TodoItem todo) async {
    await (_database.delete(
      _database.todoItems,
    )..where((t) => t.id.equals(todo.id))).go();
  }
}

final addTodoFormProvider =
    StateNotifierProvider<AddTodoFormNotifier, AddTodoFormState>((ref) {
      return AddTodoFormNotifier();
    });

class AddTodoFormState {
  final String title;
  final String description;
  final bool isLoading;

  AddTodoFormState({
    this.title = '',
    this.description = '',
    this.isLoading = false,
  });

  AddTodoFormState copyWith({
    String? title,
    String? description,
    bool? isLoading,
  }) {
    return AddTodoFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AddTodoFormNotifier extends StateNotifier<AddTodoFormState> {
  AddTodoFormNotifier() : super(AddTodoFormState());

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void reset() {
    state = AddTodoFormState();
  }

  String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a title';
    }
    if (value.length < 6) {
      return 'Title must be at least 6 characters';
    }
    if (value.length > 32) {
      return 'Title must be less than 32 characters';
    }
    return null;
  }
}
