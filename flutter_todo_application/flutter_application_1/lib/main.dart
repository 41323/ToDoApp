import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_application_1/notification_service.dart';

class Todo {
  String title;
  bool isDone;
  DateTime? alarmTime;

  Todo({
    required this.title,
    this.isDone = false,
    this.alarmTime,
  });
}

class TodoProvider with ChangeNotifier {
  final Map<DateTime, List<Todo>> _todos = {};

  List<Todo> getTodosForDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    print('Fetching todos for date: $normalizedDate');
    return _todos[normalizedDate] ?? [];
  }


Future<void> addTodo(DateTime date, String title, {DateTime? alarmTime}) async {
  print('Adding Todo: Title: $title, Date: $date, AlarmTime: $alarmTime');

  final normalizedDate = DateTime(date.year, date.month, date.day);
  _todos.putIfAbsent(normalizedDate, () => []);

  _todos[normalizedDate]!.add(Todo(title: title, alarmTime: alarmTime));
  
  if (alarmTime != null) {
    print('Scheduling notification at $alarmTime for: $title');
    
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch;  // 알림 ID
      await NotificationService.showNotification(
        notificationId,  // 알림 ID
        'Todo Reminder', // 알림 제목
        title,           // 알림 내용
        alarmTime,       // 알림 시간
      );
      print('Notification scheduled successfully.');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  } else {
    print('No alarm set for this todo.');
  }

  await _saveData();
  notifyListeners();
}



  Future<void> toggleTodoStatus(DateTime date, int index) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    _todos[normalizedDate]![index].isDone = !_todos[normalizedDate]![index].isDone;
    print('Toggling status for todo at index: $index, new status: ${_todos[normalizedDate]![index].isDone}');
    await _saveData(); // Save data to SharedPreferences
    notifyListeners();
  }

  Future<void> removeTodo(DateTime date, int index) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    print('Removing todo at index: $index for date: $normalizedDate');
    _todos[normalizedDate]!.removeAt(index);
    await _saveData(); // Save data to SharedPreferences
    notifyListeners();
  }

  Future<void> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todoData = prefs.getString('todos');
    if (todoData != null) {
      print('Loading todos from SharedPreferences');
      final Map<String, dynamic> jsonData = jsonDecode(todoData);
      _todos.clear();
      jsonData.forEach((key, value) {
        final DateTime date = DateTime.parse(key);
        final List<Todo> todoList = (value as List).map((item) {
          return Todo(
            title: item['title'],
            isDone: item['isDone'],
            alarmTime: item['alarmTime'] != null ? DateTime.parse(item['alarmTime']) : null,
          );
        }).toList();
        _todos[date] = todoList;
      });
      print('Todos loaded successfully');
      notifyListeners();
    } else {
      print('No todos found in SharedPreferences');
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonData = {};
    _todos.forEach((key, value) {
      jsonData[key.toIso8601String()] = value
          .map((todo) => {
                'title': todo.title,
                'isDone': todo.isDone,
                'alarmTime': todo.alarmTime?.toIso8601String(),
              })
          .toList();
    });
    await prefs.setString('todos', jsonEncode(jsonData));
    print('Todos saved to SharedPreferences');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NotificationService 초기화 추가
  await NotificationService.initNotification();
  await NotificationService.requestPermissions(); 
  await NotificationService.initNotification(); 
  final todoProvider = TodoProvider();
  await todoProvider.loadTodos();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => todoProvider,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TodoScreen(),
    );
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  _TodoScreenState createState() => _TodoScreenState();
}
class _TodoScreenState extends State<TodoScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  DateTime? _alarmTime;
  bool _isAlarmSet = false;
  File? _imageFile;
  bool _isImageOptionsVisible = false;
  bool _isOpacityControlVisible = false;
  double _opacity = 1.0;

TextEditingController todoController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
      todoController = TextEditingController(); // 초기화
  }
@override
void dispose() {
  todoController.dispose(); // 메모리 누수 방지
  super.dispose();
}
Future<void> _setAlarmTime() async {
  final TimeOfDay? time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (time != null) {
    final now = DateTime.now();
    final DateTime alarmTime = DateTime(
      now.year, now.month, now.day, time.hour, time.minute);

    setState(() {
      _alarmTime = alarmTime;
    });
    print('Alarm time selected: $_alarmTime');

    final String todoText = todoController.text.trim();  // 여기 수정함
    if (todoText.isNotEmpty) {
      final todoProvider = Provider.of<TodoProvider>(context, listen: false);
      await todoProvider.addTodo(
        _selectedDay,
        todoText,
        alarmTime: _alarmTime,
      );
      todoController.clear();
      setState(() {
        _alarmTime = null;
      });
      print('Todo added successfully after alarm set.');
    } else {
      print('Todo title is empty, not adding after alarm set.');
    }
  }
}


  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('TODO'),
      ),
      body: Column(
        children: [
          // Calendar widget
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              print('Selected day: $_selectedDay');
            },
          ),
          // Todo input field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: todoController,
                    decoration: InputDecoration(
                      hintText: 'Enter your task.',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.alarm),
                  onPressed: _setAlarmTime,  // Set alarm time
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () async {
                    final String todoText = todoController.text.trim();  // 제목을 미리 저장
                    print('Attempting to add todo: "$todoText" with alarmTime: $_alarmTime');

                    if (todoText.isNotEmpty) {
                      await todoProvider.addTodo(
                        _selectedDay,
                        todoText,  
                        alarmTime: _alarmTime,  
                      );
                      todoController.clear();
                      setState(() {
                        _alarmTime = null;
                      });
                    } else {
                      print('Todo title is empty, not adding.');
                    }
                  },
                ),
              ],
            ),
          ),
          // Todo list display
          Expanded(
            child: ListView.builder(
              itemCount: todoProvider.getTodosForDate(_selectedDay).length,
              itemBuilder: (context, index) {
                final todo = todoProvider.getTodosForDate(_selectedDay)[index];
                return ListTile(
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  subtitle: todo.alarmTime != null
                      ? Text(
                          'Alarm: ${todo.alarmTime!.hour}:${todo.alarmTime!.minute}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      : null,
                  leading: Checkbox(
                    value: todo.isDone,
                    onChanged: (value) {
                      todoProvider.toggleTodoStatus(_selectedDay, index);
                    },
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      todoProvider.removeTodo(_selectedDay, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
