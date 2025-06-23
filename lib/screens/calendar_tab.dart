// screens/calendar_tab.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/study_item.dart';
import '../services/database_helper.dart';
import '../services/logger_service.dart';
import '../widgets/common_widgets.dart';

class CalendarTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const CalendarTab({
    Key? key,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<StudyItem>> _reviewEvents = {};
  List<StudyItem> _selectedDayReviews = [];
  List<StudyItem> _selectedDayStudyItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadReviewsForMonth(),
      _loadDataForSelectedDay(),
    ]);
  }

  Future<void> _loadReviewsForMonth() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final reviews = await DatabaseHelper.instance.getReviewsForMonth(_focusedDay);
      
      if (mounted) {
        setState(() {
          _reviewEvents = reviews;
          _isLoading = false;
        });
      }

      LoggerService.info('Calendar reviews loaded for month: ${_focusedDay.month}');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load reviews for month', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _errorMessage = '캘린더 데이터 로드 중 오류가 발생했습니다';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDataForSelectedDay() async {
    try {
      final reviews = await DatabaseHelper.instance.getReviewsForDate(_selectedDay);
      final studyItems = await DatabaseHelper.instance.getStudyItemsCreatedOnDate(_selectedDay);
      
      if (mounted) {
        setState(() {
          _selectedDayReviews = reviews;
          _selectedDayStudyItems = studyItems;
        });
      }

      LoggerService.info('Selected day data loaded: ${reviews.length} reviews, ${studyItems.length} new items');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to load data for selected day', error: e, stackTrace: stackTrace);
    }
  }

  // 선택된 날짜에 새로운 학습 내용 추가
  Future<void> _showAddStudyDialog() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${DateFormat('M월 d일').format(_selectedDay)} 학습 내용 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '선택한 날짜에 공부한 내용을 입력하세요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예시:\n• 영어 단어 20개\n• 수학 미적분 공식\n• 프로그래밍 개념',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final content = controller.text.trim();
              Navigator.pop(dialogContext, content);
            },
            child: Text('추가'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result.isNotEmpty) {
      await _addStudyItemForDate(result);
    }
  }

  Future<void> _addStudyItemForDate(String content) async {
    try {
      // 선택된 날짜에 맞춰 생성일 설정
      final selectedDateTime = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );

      final newItem = StudyItem(
        content: content,
        createdAt: selectedDateTime,
      );

      await DatabaseHelper.instance.insertStudyItem(newItem);
      
      await _loadReviewsForMonth();
      await _loadDataForSelectedDay();
      widget.onRefresh();

      if (mounted) {
        _showSnackBar(
          '${DateFormat('M월 d일').format(_selectedDay)}에 학습 내용이 추가되었습니다!',
          backgroundColor: Colors.green,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to add study item for date', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '학습 내용 추가 중 오류가 발생했습니다',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _markStageCompleted(StudyItem item, int stageIndex) async {
    try {
      await DatabaseHelper.instance.markStageCompleted(item.id!, stageIndex);
      
      await _loadReviewsForMonth();
      await _loadDataForSelectedDay();
      widget.onRefresh();

      if (mounted) {
        final stage = item.reviewStages[stageIndex];
        final stageName = stage?.stageName ?? '스테이지 $stageIndex';
        _showSnackBar(
          '$stageName 복습 완료!',
          backgroundColor: Colors.green,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to complete review stage', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '복습 완료 처리 중 오류가 발생했습니다',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  Future<void> _markDailyCompleted(StudyItem item, int stageIndex, bool completed) async {
    try {
      await DatabaseHelper.instance.markDailyCompleted(item.id!, stageIndex, completed);
      await _loadDataForSelectedDay();

      if (mounted) {
        _showSnackBar(
          completed ? '복습 완료 체크!' : '복습 미완료로 변경',
          backgroundColor: completed ? Colors.green : Colors.orange,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to mark daily completion', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '상태 변경 중 오류가 발생했습니다',
          backgroundColor: Colors.red,
        );
      }
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  List<StudyItem> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _reviewEvents[normalizedDay] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return LoadingWidget(message: '캘린더 데이터를 불러오는 중...');
    }

    if (_errorMessage != null) {
      return ErrorDisplayWidget(
        message: _errorMessage!,
        onRetry: _loadReviewsForMonth,
      );
    }

    return Column(
      children: [
        _buildCalendar(),
        Divider(),
        _buildSelectedDayContent(),
      ],
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: EdgeInsets.all(8),
      child: TableCalendar<StudyItem>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: Theme.of(context).primaryColor,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: Theme.of(context).primaryColor,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red[400]),
          markerDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 5,
          todayDecoration: BoxDecoration(
            color: Colors.orange[400],
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _loadDataForSelectedDay();
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
          _loadReviewsForMonth();
        },
      ),
    );
  }

  Widget _buildSelectedDayContent() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectedDayHeader(),
          Expanded(
            child: _selectedDayReviews.isEmpty && _selectedDayStudyItems.isEmpty
                ? _buildEmptyDayState()
                : SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (_selectedDayStudyItems.isNotEmpty) ...[
                          _buildNewStudySection(),
                          SizedBox(height: 16),
                        ],
                        if (_selectedDayReviews.isNotEmpty)
                          _buildReviewsSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Text(
            DateFormat('yyyy년 M월 d일').format(_selectedDay),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          // 새 학습 내용 추가 버튼
          ElevatedButton.icon(
            onPressed: _showAddStudyDialog,
            icon: Icon(Icons.add, size: 16),
            label: Text(
              '내용 추가',
              style: TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            '이 날에는 일정이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '새로운 학습 내용을 추가해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddStudyDialog,
            icon: Icon(Icons.add),
            label: Text('학습 내용 추가'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewStudySection() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories, color: Colors.green[700]),
                SizedBox(width: 8),
                Text(
                  '이 날 공부한 내용',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedDayStudyItems.length}개',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._selectedDayStudyItems.map((item) => _buildNewStudyItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildNewStudyItem(StudyItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school,
              size: 14,
              color: Colors.green[700],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '생성 시간: ${DateFormat('HH:mm').format(item.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '복습 예정',
              style: TextStyle(
                fontSize: 10,
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final groupedReviews = _groupReviewsByStage();
    final sortedStages = groupedReviews.keys.toList()..sort();

    return Column(
      children: sortedStages.map((stage) {
        final stageReviews = groupedReviews[stage]!;
        return _buildReviewStageCard(stage, stageReviews);
      }).toList(),
    );
  }

  Map<int, List<MapEntry<StudyItem, ReviewStage>>> _groupReviewsByStage() {
    final Map<int, List<MapEntry<StudyItem, ReviewStage>>> grouped = {};
    
    for (final item in _selectedDayReviews) {
      final todayReviews = item.getReviewsForDate(_selectedDay);
      for (final stage in todayReviews) {
        grouped.putIfAbsent(stage.stageIndex, () => [])
            .add(MapEntry(item, stage));
      }
    }
    
    return grouped;
  }

  Widget _buildReviewStageCard(int stageIndex, List<MapEntry<StudyItem, ReviewStage>> stageReviews) {
    final firstItem = stageReviews.first.key;
    final stage = firstItem.reviewStages[stageIndex];
    final stageName = stage?.stageName ?? '스테이지 $stageIndex';
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Colors.blue[50],
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  '$stageName 복습',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${stageReviews.length}개',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...stageReviews.asMap().entries.map((entry) {
            final index = entry.key;
            final reviewEntry = entry.value;
            final isLast = index == stageReviews.length - 1;
            
            return _buildReviewItem(
              reviewEntry.key,
              reviewEntry.value,
              isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItem(StudyItem item, ReviewStage stage, bool isLast) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isLast ? null : Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: stage.isDailyCompleted,
            onChanged: (value) => _markDailyCompleted(item, stage.stageIndex, value ?? false),
            activeColor: Colors.green,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: stage.isDailyCompleted 
                        ? TextDecoration.lineThrough 
                        : TextDecoration.none,
                    color: stage.isDailyCompleted 
                        ? Colors.grey[600] 
                        : Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '생성일: ${DateFormat('MM/dd').format(item.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () => _markStageCompleted(item, stage.stageIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size(50, 32),
              ),
              child: Text(
                '완료',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}