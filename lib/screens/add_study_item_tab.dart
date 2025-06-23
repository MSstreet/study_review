import 'package:flutter/material.dart';
import '../models/study_item.dart';
import '../services/database_helper.dart';
import '../services/logger_service.dart';

class AddStudyItemTab extends StatefulWidget {
  final VoidCallback onRefresh;

  const AddStudyItemTab({
    Key? key,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<AddStudyItemTab> createState() => _AddStudyItemTabState();
}

class _AddStudyItemTabState extends State<AddStudyItemTab> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isAdding = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _addStudyItem() async {
    if (!_formKey.currentState!.validate() || _isAdding) {
      return;
    }

    setState(() {
      _isAdding = true;
    });

    try {
      final content = _contentController.text.trim();
      final now = DateTime.now();

      final newItem = StudyItem(
        content: content,
        createdAt: now,
      );

      await DatabaseHelper.instance.insertStudyItem(newItem);
      
      _contentController.clear();
      widget.onRefresh();

      if (mounted) {
        _showSnackBar(
          '학습 내용이 추가되었습니다! 복습 일정이 설정되었습니다.',
          backgroundColor: Colors.green,
        );
        
        // 키보드 숨기기
        FocusScope.of(context).unfocus();
      }

      LoggerService.info('Study item added successfully: $content');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to add study item', error: e, stackTrace: stackTrace);
      if (mounted) {
        _showSnackBar(
          '학습 내용 추가 중 오류가 발생했습니다',
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
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
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24),
            _buildInputSection(),
            SizedBox(height: 24),
            _buildAddButton(),
            SizedBox(height: 16),
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '새로운 학습 내용 추가',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '오늘 공부한 내용을 입력하면 자동으로 복습 일정이 생성됩니다',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습 내용',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: TextFormField(
                  controller: _contentController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '자유롭게 입력하세요...\n\n예시:\n• 영어 단어 20개 암기\n• 수학 미적분 공식 정리\n• 역사 조선시대 주요 사건\n• 프로그래밍 함수형 개념',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '학습 내용을 입력해주세요';
                    }
                    if (value.trim().length < 3) {
                      return '3글자 이상 입력해주세요';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _addStudyItem(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isAdding ? null : _addStudyItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isAdding
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '추가 중...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              )
            : Text(
                '학습 내용 추가하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  '복습 일정 안내',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildScheduleItem('1일차', '내일', Colors.orange),
            _buildScheduleItem('3일차', '3일 후', Colors.green),
            _buildScheduleItem('7일차', '1주일 후', Colors.blue),
            _buildScheduleItem('15일차', '2주일 후', Colors.purple),
            _buildScheduleItem('30일차', '1개월 후', Colors.red),
            SizedBox(height: 8),
            Text(
              '각 단계마다 오전 9시에 알림을 받게 됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(String stage, String timing, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
          Text(
            '$stage 복습',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Spacer(),
          Text(
            timing,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
