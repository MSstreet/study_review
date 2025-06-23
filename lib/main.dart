// main.dart
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'services/notification_service.dart';
import 'screens/main_screen.dart';
import 'services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    tz.initializeTimeZones();
    await NotificationService.instance.initialize();
    LoggerService.info('App initialized successfully');
  } catch (e, stackTrace) {
    LoggerService.error('Failed to initialize app', error: e, stackTrace: stackTrace);
  }
  
  runApp(ReviewHelperApp());
}

class ReviewHelperApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '복습 도우미',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: MainScreen(),
    );
  }
}