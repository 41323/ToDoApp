import 'dart:convert';  
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

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
    return _todos[normalizedDate] ?? [];
  }

  Future<void> addTodo(DateTime date, String title, {DateTime? alarmTime}) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    if (_todos[normalizedDate] == null) {
      _todos[normalizedDate] = [];
    }
    _todos[normalizedDate]!.add(Todo(title: title, alarmTime: alarmTime));
    await _saveData(); // 데이터 저장
    notifyListeners();
  }

  Future<void> toggleTodoStatus(DateTime date, int index) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    _todos[normalizedDate]![index].isDone = !_todos[normalizedDate]![index].isDone;
    await _saveData(); // 데이터 저장
    notifyListeners();
  }

  Future<void> removeTodo(DateTime date, int index) async {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    _todos[normalizedDate]!.removeAt(index);
    await _saveData(); // 데이터 저장
    notifyListeners();
  }

  // 데이터 로딩
  Future<void> loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? todoData = prefs.getString('todos');
    if (todoData != null) {
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
      notifyListeners();
    }
  }

  // 데이터 저장
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
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final todoProvider = TodoProvider();
  await todoProvider.loadTodos();  // 데이터 로딩
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
  File? _imageFile;  // 이미지 파일
  bool _isImageOptionsVisible = false;  // 이미지 관련 옵션 메뉴의 표시 여부
  bool _isOpacityControlVisible = false;  // 투명도 조절 메뉴의 표시 여부
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _loadImage();
    _loadOpacity();  // 앱 시작 시 저장된 투명도 값을 불러옴
  }

  // 이미지 파일 로드 (앱 실행 시 이미지 경로 불러오기)
  Future<void> _loadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('imagePath');
    if (imagePath != null) {
      setState(() {
        _imageFile = File(imagePath);
      });
    }
  }

  // 이미지 선택
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = pickedFile.name;
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      // 선택한 이미지 경로를 SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('imagePath', savedImage.path);

      setState(() {
        _imageFile = savedImage;
      });
    }
  }

  // 투명도 값 저장
  Future<void> _saveOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('opacity', opacity);
  }

  // 저장된 투명도 값 로드
  Future<void> _loadOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedOpacity = prefs.getDouble('opacity');
    if (savedOpacity != null) {
      setState(() {
        _opacity = savedOpacity;
      });
    }
  }

  // 이미지 투명도 조절
  void _adjustOpacity(double opacity) {
    setState(() {
      _opacity = opacity;
    });
    _saveOpacity(opacity);  // 투명도 값 저장
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    TextEditingController todoController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('TODO'),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: () {
              setState(() {
                _isImageOptionsVisible = !_isImageOptionsVisible;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 이미지 선택 및 투명도 조절 옵션
          if (_isImageOptionsVisible)
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    title: Text('이미지 선택'),
                    onTap: _pickImage,  // 이미지 선택
                  ),
                  ListTile(
                    title: Text('투명도 조절'),
                    onTap: () {
                      setState(() {
                        _isOpacityControlVisible = !_isOpacityControlVisible;
                      });
                    },
                  ),
                ],
              ),
            ),
          // 투명도 조절 슬라이더
          if (_isOpacityControlVisible)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text("투명도: "),
                  Expanded(
                    child: Slider(
                      value: _opacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: _adjustOpacity,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isOpacityControlVisible = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          // 배경 이미지 추가
          Container(
            decoration: BoxDecoration(
              image: _imageFile != null
                  ? DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                      opacity: _opacity,
                    )
                  : null,
            ),
            child: Column(
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
                            hintText: '할일을 입력하세요.',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.alarm),
                        onPressed: () async {
                          // 알람 설정 버튼
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () async {
                          if (todoController.text.isNotEmpty) {
                            await todoProvider.addTodo(
                              _selectedDay,
                              todoController.text,
                              alarmTime: _alarmTime,
                            );
                            todoController.clear();
                          }
                        },
                      ),
                    ],
                  ),
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
