import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:learning/database/drift.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();

  await database
      .into(database.todoItems)
      .insert(
        TodoItemsCompanion.insert(
          title: 'todo: finish drift setup',
          description: 'We can now write queries and define our own tables.',
          isCompleted: const Value(false),
        ),
      );
  final List<TodoItem> allItems = await database
      .select(database.todoItems)
      .get();

  log('items in database: $allItems');
  runApp(MyApp(allItems: allItems));
}

class MyApp extends StatelessWidget {
  final List<TodoItem> allItems;
  const MyApp({super.key, required this.allItems});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo app with Drift database',
      debugShowCheckedModeBanner: false,
      home: MyHomePage(allItems: allItems),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final List<TodoItem> allItems;
  const MyHomePage({super.key, required this.allItems});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todo app with Drift database')),
      body: ListView.builder(
        itemCount: allItems.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(allItems[index].title),
            subtitle: Text(allItems[index].description),
            trailing: Checkbox(
              value: allItems[index].isCompleted,
              onChanged: (value) {},
            ),
          );
        },
      ),
    );
  }
}
