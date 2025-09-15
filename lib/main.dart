import 'package:flutter/material.dart';
import 'package:learning/services/background_services.dart';
import 'package:learning/services/notification_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  requestLocationPermissions();
  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });
  await initializeService();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: HomePage()),
  );
}

Future<void> requestLocationPermissions() async {
  await Permission.location.request();
  await Permission.locationWhenInUse.request();
  await Permission.locationAlways.request();
}
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Todo App with Drift & Riverpod',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
//       home: const TodoHomePage(),
//     );
//   }
// }

// class TodoHomePage extends ConsumerWidget {
//   const TodoHomePage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final todoListAsync = ref.watch(todoListProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Todo App'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         elevation: 2,
//       ),
//       body: todoListAsync.when(
//         data: (todos) => todos.isEmpty
//             ? const Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.task_alt, size: 64, color: Colors.grey),
//                     SizedBox(height: 16),
//                     Text(
//                       'No todos yet!',
//                       style: TextStyle(fontSize: 18, color: Colors.grey),
//                     ),
//                     Text(
//                       'Tap the + button to add your first todo',
//                       style: TextStyle(fontSize: 14, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               )
//             : ListView.builder(
//                 padding: const EdgeInsets.all(8),
//                 itemCount: todos.length,
//                 itemBuilder: (context, index) {
//                   final todo = todos[index];
//                   return Card(
//                     margin: const EdgeInsets.symmetric(
//                       vertical: 4,
//                       horizontal: 8,
//                     ),
//                     child: ListTile(
//                       leading: Checkbox(
//                         value: todo.isCompleted ?? false,
//                         onChanged: (_) => _toggleTodo(ref, todo),
//                       ),
//                       title: Text(
//                         todo.title,
//                         style: TextStyle(
//                           decoration: (todo.isCompleted ?? false)
//                               ? TextDecoration.lineThrough
//                               : null,
//                           color: (todo.isCompleted ?? false)
//                               ? Colors.grey
//                               : null,
//                         ),
//                       ),
//                       subtitle: todo.description.isNotEmpty
//                           ? Text(
//                               todo.description,
//                               style: TextStyle(
//                                 decoration: (todo.isCompleted ?? false)
//                                     ? TextDecoration.lineThrough
//                                     : null,
//                                 color: (todo.isCompleted ?? false)
//                                     ? Colors.grey
//                                     : null,
//                               ),
//                             )
//                           : null,
//                       trailing: IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => _deleteTodo(ref, todo),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//         loading: () => const Center(child: CircularProgressIndicator()),
//         error: (error, stack) => Center(child: Text('Error: $error')),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _showAddTodoDialog(context, ref),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }

//   void _toggleTodo(WidgetRef ref, TodoItem todo) async {
//     final todoOperations = ref.read(todoOperationsProvider);
//     await todoOperations.toggleTodo(todo);
//     ref.invalidate(todoListProvider);
//   }

//   void _deleteTodo(WidgetRef ref, TodoItem todo) async {
//     final todoOperations = ref.read(todoOperationsProvider);
//     await todoOperations.deleteTodo(todo);
//     ref.invalidate(todoListProvider);
//   }

//   void _showAddTodoDialog(BuildContext context, WidgetRef ref) {
//     showDialog(
//       context: context,
//       builder: (context) => Consumer(
//         builder: (context, ref, child) {
//           final formState = ref.watch(addTodoFormProvider);
//           final formNotifier = ref.read(addTodoFormProvider.notifier);
//           final todoOperations = ref.read(todoOperationsProvider);

//           return AlertDialog(
//             title: const Text('Add New Todo'),
//             content: Form(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     initialValue: formState.title,
//                     decoration: const InputDecoration(
//                       labelText: 'Title',
//                       border: OutlineInputBorder(),
//                     ),
//                     onChanged: formNotifier.updateTitle,
//                     validator: formNotifier.validateTitle,
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     initialValue: formState.description,
//                     decoration: const InputDecoration(
//                       labelText: 'Description',
//                       border: OutlineInputBorder(),
//                     ),
//                     maxLines: 3,
//                     onChanged: formNotifier.updateDescription,
//                   ),
//                 ],
//               ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   formNotifier.reset();
//                   Navigator.of(context).pop();
//                 },
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: formState.isLoading
//                     ? null
//                     : () async {
//                         if (formNotifier.validateTitle(formState.title) ==
//                             null) {
//                           formNotifier.setLoading(true);
//                           try {
//                             await todoOperations.addTodo(
//                               title: formState.title,
//                               description: formState.description,
//                             );
//                             ref.invalidate(todoListProvider);
//                             formNotifier.reset();
//                             Navigator.of(context).pop();
//                           } finally {
//                             formNotifier.setLoading(false);
//                           }
//                         }
//                       },
//                 child: formState.isLoading
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Text('Add'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }
