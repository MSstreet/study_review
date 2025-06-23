// screens/main_screen.dart
import 'package:flutter/material.dart';
import '../models/study_item.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/logger_service.dart';
import 'today_reviews_tab.dart';
import 'calendar_tab.dart';
import 'all_study_items_tab.dart';
import 'add_study_item_tab.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  List<StudyItem> _todayReviews = [];
  List<StudyItem> _allItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 앱이 포그라운드로 돌아올 때 데이터 새로고침
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _initializeApp() async {
    try {
      // 알림 권한 요청
      await _requestNotificationPermission();
      
      // 데이터 로드
      await _loadData();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize app', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = '앱 초기화 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!NotificationService.instance.hasPermission) {
      await NotificationService.instance.requestPermission(context);
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final today = await DatabaseHelper.instance.getTodayReviews();
      final all = await DatabaseHelper.instance.getAllStudyItems();
      
      if (mounted) {
        setState(() {
          _todayReviews = today;
          _allItems = all;
          _isLoading = false;
        });
      }
      
      LoggerService.info('Data loaded successfully: ${today.length} today reviews, ${all.length} total items');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load data', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = '데이터 로드 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    try {
      switch (value) {
        case 'test_immediate':
          final success = await NotificationService.instance.showImmediateNotification(
            title: '즉시 알림 테스트',
            body: '알림이 정상적으로 작동합니다! 🎉',
          );
          _showSnackBar(success ? '즉시 알림을 보냈습니다!' : '알림 전송에 실패했습니다');
          break;
          
        case 'test_10sec':
          final success = await NotificationService.instance.scheduleTestNotificationIn10Seconds();
          _showSnackBar(success ? '10초 후 알림이 예약되었습니다!' : '알림 예약에 실패했습니다');
          break;
          
        case 'test_1min':
          final success = await NotificationService.instance.scheduleTestNotificationIn1Minute();
          _showSnackBar(success ? '1분 후 알림이 예약되었습니다!' : '알림 예약에 실패했습니다');
          break;
          
        case 'cancel_all':
          final success = await NotificationService.instance.cancelAllNotifications();
          _showSnackBar(success ? '모든 알림이 취소되었습니다!' : '알림 취소에 실패했습니다');
          break;
          
        case 'show_pending':
          await _showPendingNotifications();
          break;
          
        case 'request_permission':
          await _requestNotificationPermission();
          break;
      }
    } catch (e, stackTrace) {
      LoggerService.error('Error handling menu selection', error: e, stackTrace: stackTrace);
      _showSnackBar('작업 처리 중 오류가 발생했습니다');
    }
  }

  Future<void> _showPendingNotifications() async {
    try {
      final pending = await NotificationService.instance.getPendingNotifications();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('예약된 알림'),
          content: pending.isEmpty
              ? Text('예약된 알림이 없습니다.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: pending.take(10).map((notification) => ListTile(
                    title: Text(notification.title ?? '제목 없음'),
                    subtitle: Text(notification.body ?? '내용 없음'),
                    trailing: Text('ID: ${notification.id}'),
                  )).toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      LoggerService.error('Error showing pending notifications', error: e, stackTrace: stackTrace);
      _showSnackBar('알림 목록을 가져오는데 실패했습니다');
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('복습 도우미'),
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'test_immediate',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active),
                    SizedBox(width: 8),
                    Text('즉시 알림 테스트'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'test_10sec',
                child: Row(
                  children: [
                    Icon(Icons.timer_10),
                    SizedBox(width: 8),
                    Text('10초 후 알림 테스트'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'test_1min',
                child: Row(
                  children: [
                    Icon(Icons.timer),
                    SizedBox(width: 8),
                    Text('1분 후 알림 테스트'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'show_pending',
                child: Row(
                  children: [
                    Icon(Icons.list_alt),
                    SizedBox(width: 8),
                    Text('예약된 알림 보기'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'cancel_all',
                child: Row(
                  children: [
                    Icon(Icons.notifications_off),
                    SizedBox(width: 8),
                    Text('모든 알림 취소'),
                  ],
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'request_permission',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('알림 권한 요청'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: _buildTabIcon(Icons.today, 0),
            label: '오늘 복습',
          ),
          BottomNavigationBarItem(
            icon: _buildTabIcon(Icons.calendar_month, 1),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: _buildTabIcon(Icons.list, 2),
            label: '전체 목록',
          ),
          BottomNavigationBarItem(
            icon: _buildTabIcon(Icons.add, 3),
            label: '추가',
          ),
        ],
      ),
    );
  }

  Widget _buildTabIcon(IconData icon, int tabIndex) {
    return Stack(
      children: [
        Icon(icon),
        if (tabIndex == 0 && _todayReviews.isNotEmpty)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '${_todayReviews.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('데이터를 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      children: [
        TodayReviewsTab(reviews: _todayReviews, onRefresh: _loadData),
        CalendarTab(onRefresh: _loadData),
        AllStudyItemsTab(items: _allItems, onRefresh: _loadData),
        AddStudyItemTab(onRefresh: _loadData),
      ],
    );
  }
}