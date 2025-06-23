// screens/today_reviews_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_item.dart';
import '../services/database_helper.dart';
import '../services/logger_service.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class TodayReviewsTab extends StatefulWidget {
  final List<StudyItem> reviews;
  final VoidCallback onRefresh;

  const TodayReviewsTab({
    Key? key,
    required this.reviews,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<TodayReviewsTab> createState() => _TodayReviewsTabState();
}

class _TodayReviewsTabState extends State<TodayReviewsTab> {
  bool _isProcessing = false;

  Future<void> _markDailyCompleted(StudyItem item, int stageIndex, bool completed) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await DatabaseHelper.instance.markDailyCompleted(item.id!, stageIndex, completed);
      widget.onRefresh();

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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _completeReview(StudyItem item, int stageIndex) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await DatabaseHelper.instance.markStageCompleted(item.id!, stageIndex);
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
      LoggerService.error('Failed to complete review', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '복습 완료 처리 중 오류가 발생했습니다',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (widget.reviews.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      physics: AlwaysScrollableScrollPhysics(), // RefreshIndicator가 작동하도록
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 16),
          _buildReviewsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green[300],
              ),
              SizedBox(height: 16),
              Text(
                '오늘 복습할 내용이 없습니다!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                '새로운 내용을 추가하거나\n내일 복습할 내용을 기다려보세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalReviews = _getTotalReviewsCount();
    final completedReviews = _getCompletedReviewsCount();

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '오늘의 복습 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildProgressCard(
                    '완료된 복습',
                    completedReviews.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildProgressCard(
                    '전체 복습',
                    totalReviews.toString(),
                    Colors.blue,
                    Icons.assignment,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalReviews > 0 ? completedReviews / totalReviews : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 8),
            Text(
              totalReviews > 0 
                  ? '${((completedReviews / totalReviews) * 100).toInt()}% 완료'
                  : '완료!',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    final groupedReviews = _groupReviewsByStage();
    final sortedStages = groupedReviews.keys.toList()..sort();

    return Column(
      children: sortedStages.map((stage) {
        final stageReviews = groupedReviews[stage]!;
        return _buildStageGroup(stage, stageReviews);
      }).toList(),
    );
  }

  Map<int, List<MapEntry<StudyItem, int>>> _groupReviewsByStage() {
    final Map<int, List<MapEntry<StudyItem, int>>> grouped = {};
    
    for (final item in widget.reviews) {
      final todayReviews = item.getReviewsForDate(DateTime.now());
      for (final stage in todayReviews) {
        grouped.putIfAbsent(stage.stageIndex, () => [])
            .add(MapEntry(item, stage.stageIndex));
      }
    }
    
    return grouped;
  }

  Widget _buildStageGroup(int stageIndex, List<MapEntry<StudyItem, int>> stageReviews) {
    final firstItem = stageReviews.first.key;
    final stage = firstItem.reviewStages[stageIndex];
    final stageName = stage?.stageName ?? '스테이지 $stageIndex';
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Column(
        children: [
          // 스테이지 헤더
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    stageName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  '${stageReviews.length}개',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // 리뷰 항목들
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

  Widget _buildReviewItem(StudyItem item, int stageIndex, bool isLast) {
    final stage = item.reviewStages[stageIndex];
    if (stage == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // 체크박스
          Checkbox(
            value: stage.isDailyCompleted,
            onChanged: _isProcessing ? null : (value) => 
                _markDailyCompleted(item, stageIndex, value ?? false),
            activeColor: Colors.green,
          ),
          SizedBox(width: 12),
          // 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.content,
                  style: TextStyle(
                    fontSize: 16,
                    decoration: stage.isDailyCompleted 
                        ? TextDecoration.lineThrough 
                        : TextDecoration.none,
                    color: stage.isDailyCompleted 
                        ? Colors.grey[600] 
                        : Colors.black,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      '생성일: ${DateFormat('MM/dd').format(item.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // 완료 버튼
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : () => _completeReview(item, stageIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isProcessing 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '완료',
                      style: TextStyle(fontSize: 12),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalReviewsCount() {
    int total = 0;
    for (final item in widget.reviews) {
      total += item.getReviewsForDate(DateTime.now()).length;
    }
    return total;
  }

  int _getCompletedReviewsCount() {
    int completed = 0;
    for (final item in widget.reviews) {
      final todayReviews = item.getReviewsForDate(DateTime.now());
      for (final stage in todayReviews) {
        if (stage.isDailyCompleted || stage.isCompleted) {
          completed++;
        }
      }
    }
    return completed;
  }
}