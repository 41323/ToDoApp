import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';  // 알림 서비스 추가

class Todo {
  String title;
  bool isDone;

  Todo({
    required this.title,
    this.isDone = false,
  });
}

class TodoProvider with ChangeNotifier {
  final Map<DateTime, List<Todo>> _todos = {};

  List<Todo> getTodosForDate(DateTime date) {
    // 날짜에 맞는 할일 목록 반환
    return _todos[date] ?? [];
  }

  void addTodo(DateTime date, String title) {
    if (_todos[date] == null) {
      _todos[date] = [];
    }
    _todos[date]!.add(Todo(
      title: title,
    ));
    notifyListeners();  // 할일 추가 후 상태 변경 알리기
  }

  void toggleTodoStatus(DateTime date, int index) {
    _todos[date]![index].isDone = !_todos[date]![index].isDone;
    notifyListeners();
  }

  void removeTodo(DateTime date, int index) {
    _todos[date]!.removeAt(index);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 알림 권한 요청
  await NotificationService.requestPermissions();  // 권한 요청 추가

  // 알림 서비스 초기화
  await NotificationService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => TodoProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODO App with Calendar',
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

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
  }

  // 날짜 선택
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  // 시간 선택
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDay),
    );
    if (picked != null) {
      setState(() {
        _alarmTime = DateTime(
          _selectedDay.year,
          _selectedDay.month,
          _selectedDay.day,
          picked.hour,
          picked.minute,
        );
        _isAlarmSet = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    TextEditingController todoController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('TODO App with Calendar'),
      ),
      body: Column(
        children: [
          // 달력 위젯
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
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          // 할 일 입력
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: todoController,
                    decoration: InputDecoration(
                      hintText: 'Enter your task for ${_selectedDay.toLocal()}',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.alarm),
                  onPressed: () async {
                    // 알람 설정 버튼
                    await _selectDate(context);
                    await _selectTime(context);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () async {
                    if (todoController.text.isNotEmpty) {
                      // 할 일 추가
                      todoProvider.addTodo(_selectedDay, todoController.text);

                      // 알람 설정이 되어 있으면 알림 예약
                      if (_isAlarmSet && _alarmTime != null) {
                        NotificationService.showNotification(
                          0,
                          'Task for ${_alarmTime.toString()}',
                          todoController.text,
                          _alarmTime!,
                        );
                      }

                      todoController.clear();
                      setState(() {
                        _isAlarmSet = false; // 알람 설정 상태 초기화
                        _alarmTime = null;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          // 할 일 목록 표시
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
