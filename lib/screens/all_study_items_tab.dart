// screens/all_study_items_tab.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_item.dart';
import '../services/database_helper.dart';
import '../services/logger_service.dart';
import '../widgets/common_widgets.dart';

class AllStudyItemsTab extends StatefulWidget {
  final List<StudyItem> items;
  final VoidCallback onRefresh;

  const AllStudyItemsTab({
    Key? key,
    required this.items,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<AllStudyItemsTab> createState() => _AllStudyItemsTabState();
}

class _AllStudyItemsTabState extends State<AllStudyItemsTab> {
  Set<String> _expandedDates = {};
  String _searchQuery = '';
  bool _showCompletedOnly = false;
  bool _isProcessing = false;

  List<StudyItem> get _filteredItems {
    var items = widget.items.where((item) {
      // 검색 필터
      if (_searchQuery.isNotEmpty && 
          !item.content.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      
      // 완료 상태 필터
      if (_showCompletedOnly && !item.isFullyCompleted) {
        return false;
      }
      
      return true;
    }).toList();

    return items;
  }

  Future<void> _showEditDialog(StudyItem item) async {
    final controller = TextEditingController(text: item.content);
    
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('내용 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '모든 관련 복습 단계의 내용이 함께 수정됩니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '수정할 내용을 입력하세요',
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
              final newContent = controller.text.trim();
              Navigator.pop(dialogContext, newContent);
            },
            child: Text('수정'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result.isNotEmpty && result != item.content) {
      await _updateStudyItem(item, result);
    }
  }

  Future<void> _updateStudyItem(StudyItem item, String newContent) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final updatedItem = item.copyWith(content: newContent);
      await DatabaseHelper.instance.updateStudyItem(updatedItem);
      widget.onRefresh();
      
      if (mounted) {
        _showSnackBar(
          '모든 관련 복습 단계의 내용이 수정되었습니다',
          backgroundColor: Colors.blue,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to update study item', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '수정 중 오류가 발생했습니다',
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

  Future<void> _showDeleteDialog(StudyItem item, {bool singleStage = false}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(singleStage ? '단계 삭제 확인' : '전체 삭제 확인'),
        content: Text(
          singleStage 
              ? '이 복습 단계만 삭제하시겠습니까?\n(다른 복습 단계는 그대로 유지됩니다)'
              : '이 학습 내용을 완전히 삭제하시겠습니까?\n모든 복습 단계가 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              '삭제',
              style: TextStyle(
                color: singleStage ? Colors.orange : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteStudyItem(item);
    }
  }

  Future<void> _deleteStudyItem(StudyItem item) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await DatabaseHelper.instance.deleteStudyItem(item.id!);
      widget.onRefresh();
      
      if (mounted) {
        _showSnackBar(
          '학습 내용이 삭제되었습니다',
          backgroundColor: Colors.red,
        );
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to delete study item', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '삭제 중 오류가 발생했습니다',
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
    return Column(
      children: [
        _buildHeader(),
        _buildSearchAndFilter(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final totalItems = widget.items.length;
    final completedItems = widget.items.where((item) => item.isFullyCompleted).length;
    final inProgressItems = totalItems - completedItems;

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '전체 학습 현황',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체',
                    totalItems.toString(),
                    Colors.blue,
                    Icons.library_books,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '진행중',
                    inProgressItems.toString(),
                    Colors.orange,
                    Icons.schedule,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '완료',
                    completedItems.toString(),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
              ],
            ),
            if (totalItems > 0) ...[
              SizedBox(height: 12),
              LinearProgressIndicator(
                value: completedItems / totalItems,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 8),
              Text(
                '전체 완료율: ${((completedItems / totalItems) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
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
              fontSize: 18,
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

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 검색바
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: '학습 내용 검색...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          SizedBox(height: 8),
          // 필터 옵션
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: Text(
                    '완료된 항목만 보기',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: _showCompletedOnly,
                  onChanged: (value) {
                    setState(() {
                      _showCompletedOnly = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Text(
                '${_filteredItems.length}개 항목',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.items.isEmpty) {
      return EmptyStateWidget(
        title: '아직 공부한 내용이 없습니다',
        subtitle: '새로운 학습 내용을 추가해보세요',
        icon: Icons.library_books,
        actionButton: ElevatedButton.icon(
          onPressed: () {
            // 추가 탭으로 이동하는 로직 (상위 위젯에서 처리)
          },
          icon: Icon(Icons.add),
          label: Text('내용 추가하기'),
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return EmptyStateWidget(
        title: '검색 결과가 없습니다',
        subtitle: '다른 검색어를 시도해보세요',
        icon: Icons.search_off,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _buildGroupedStudyList(),
      ),
    );
  }

  Widget _buildGroupedStudyList() {
    // 생성일 기준으로 그룹화
    final Map<String, List<StudyItem>> groupedByDate = {};
    
    for (final item in _filteredItems) {
      final dateKey = DateFormat('yyyy-MM-dd').format(item.createdAt);
      groupedByDate.putIfAbsent(dateKey, () => []).add(item);
    }

    // 날짜별로 정렬 (최신순)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: sortedDates.map((dateKey) {
        final dateItems = groupedByDate[dateKey]!;
        final date = DateTime.parse(dateKey);
        final isExpanded = _expandedDates.contains(dateKey);
        
        return _buildDateGroup(dateKey, date, dateItems, isExpanded);
      }).toList(),
    );
  }

  Widget _buildDateGroup(String dateKey, DateTime date, List<StudyItem> dateItems, bool isExpanded) {
    final completedCount = dateItems.where((item) => item.isFullyCompleted).length;
    final totalCount = dateItems.length;
    final progressPercent = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // 날짜 헤더 (클릭해서 접기/펼치기)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(dateKey);
                } else {
                  _expandedDates.add(dateKey);
                }
              });
            },
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // 날짜 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDateDisplayText(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${dateItems.length}개 항목 • ${completedCount}개 완료',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 진행률 표시
                  Container(
                    width: 60,
                    child: Column(
                      children: [
                        Text(
                          '${(progressPercent * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: progressPercent == 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressPercent == 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // 펼치기/접기 아이콘
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          // 학습 항목들 (펼쳐졌을 때만 표시)
          if (isExpanded) ...[
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: dateItems.map((item) => _buildStudyItem(item)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyItem(StudyItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isFullyCompleted ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.isFullyCompleted ? Colors.green[200]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // 상태 아이콘
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.isFullyCompleted ? Colors.green[100] : Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isFullyCompleted ? Icons.check_circle : Icons.schedule,
              size: 18,
              color: item.isFullyCompleted ? Colors.green[700] : Colors.blue[700],
            ),
          ),
          SizedBox(width: 12),
          // 내용
          Expanded(
            child: GestureDetector(
              onTap: () => _showEditDialog(item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: item.isFullyCompleted 
                          ? TextDecoration.lineThrough 
                          : TextDecoration.none,
                      color: item.isFullyCompleted 
                          ? Colors.grey[600] 
                          : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timeline, size: 12, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text(
                        '진행률: ${item.completedStagesCount}/${item.totalStagesCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isFullyCompleted ? Colors.green[100] : Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.isFullyCompleted ? '완료' : '진행중',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.isFullyCompleted ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 메뉴 버튼
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, item),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 16),
                    SizedBox(width: 8),
                    Text('수정'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: Icon(Icons.more_vert, size: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(String action, StudyItem item) async {
    switch (action) {
      case 'edit':
        await _showEditDialog(item);
        break;
      case 'delete':
        await _showDeleteDialog(item);
        break;
    }
  }

  String _getDateDisplayText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(itemDate).inDays;
    
    if (difference == 0) {
      return '오늘 (${DateFormat('M월 d일').format(date)})';
    } else if (difference == 1) {
      return '어제 (${DateFormat('M월 d일').format(date)})';
    } else if (difference < 7) {
      return '${difference}일 전 (${DateFormat('M월 d일').format(date)})';
    } else {
      return DateFormat('yyyy년 M월 d일').format(date);
    }
  }
}