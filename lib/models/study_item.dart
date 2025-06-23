// models/study_item.dart
import 'dart:convert';

class ReviewSettings {
  static List<int> reviewIntervals = [1, 3, 7, 15, 30]; // 사용자 커스터마이징 가능
  static List<String> stageNames = ['1일차', '3일차', '7일차', '15일차', '30일차'];
}

class StudyItem {
  final int? id;
  final String content;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<int, ReviewStage> reviewStages; // 단계별 복습 상태
  final bool isDeleted;

  StudyItem({
    this.id,
    required this.content,
    required this.createdAt,
    this.completedAt,
    Map<int, ReviewStage>? reviewStages,
    this.isDeleted = false,
  }) : reviewStages = reviewStages ?? _initializeReviewStages(createdAt);

  static Map<int, ReviewStage> _initializeReviewStages(DateTime createdAt) {
    Map<int, ReviewStage> stages = {};
    for (int i = 0; i < ReviewSettings.reviewIntervals.length; i++) {
      final reviewDate = createdAt.add(Duration(days: ReviewSettings.reviewIntervals[i]));
      stages[i] = ReviewStage(
        stageIndex: i,
        scheduledDate: reviewDate,
        isCompleted: false,
        isDailyCompleted: false,
      );
    }
    return stages;
  }

  bool get isFullyCompleted => reviewStages.values.every((stage) => stage.isCompleted);
  
  int get completedStagesCount => reviewStages.values.where((stage) => stage.isCompleted).length;
  
  int get totalStagesCount => reviewStages.length;
  
  double get progressPercent => totalStagesCount > 0 ? (completedStagesCount / totalStagesCount) : 0.0;

  List<ReviewStage> getReviewsForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return reviewStages.values.where((stage) {
      final stageDate = DateTime(
        stage.scheduledDate.year,
        stage.scheduledDate.month,
        stage.scheduledDate.day,
      );
      return stageDate.isAtSameMomentAs(targetDate) && !stage.isCompleted;
    }).toList();
  }

  StudyItem copyWith({
    int? id,
    String? content,
    DateTime? createdAt,
    DateTime? completedAt,
    Map<int, ReviewStage>? reviewStages,
    bool? isDeleted,
  }) {
    return StudyItem(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      reviewStages: reviewStages ?? Map.from(this.reviewStages),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  StudyItem markStageCompleted(int stageIndex) {
    final updatedStages = Map<int, ReviewStage>.from(reviewStages);
    if (updatedStages.containsKey(stageIndex)) {
      updatedStages[stageIndex] = updatedStages[stageIndex]!.copyWith(isCompleted: true);
    }
    
    final isFullyComplete = updatedStages.values.every((stage) => stage.isCompleted);
    
    return copyWith(
      reviewStages: updatedStages,
      completedAt: isFullyComplete ? DateTime.now() : completedAt,
    );
  }

  StudyItem markDailyCompleted(int stageIndex, bool completed) {
    final updatedStages = Map<int, ReviewStage>.from(reviewStages);
    if (updatedStages.containsKey(stageIndex)) {
      updatedStages[stageIndex] = updatedStages[stageIndex]!.copyWith(isDailyCompleted: completed);
    }
    return copyWith(reviewStages: updatedStages);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'reviewStages': jsonEncode(reviewStages.map((key, value) => MapEntry(key.toString(), value.toMap()))),
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory StudyItem.fromMap(Map<String, dynamic> map) {
    Map<int, ReviewStage> stages = {};
    
    if (map['reviewStages'] != null) {
      final stagesJson = jsonDecode(map['reviewStages'] as String) as Map<String, dynamic>;
      stages = stagesJson.map((key, value) => 
        MapEntry(int.parse(key), ReviewStage.fromMap(value as Map<String, dynamic>))
      );
    }

    return StudyItem(
      id: map['id'] as int?,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      completedAt: map['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      reviewStages: stages,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }
}

class ReviewStage {
  final int stageIndex;
  final DateTime scheduledDate;
  final bool isCompleted;
  final bool isDailyCompleted;
  final DateTime? completedAt;

  ReviewStage({
    required this.stageIndex,
    required this.scheduledDate,
    required this.isCompleted,
    required this.isDailyCompleted,
    this.completedAt,
  });

  String get stageName => ReviewSettings.stageNames[stageIndex];

  ReviewStage copyWith({
    int? stageIndex,
    DateTime? scheduledDate,
    bool? isCompleted,
    bool? isDailyCompleted,
    DateTime? completedAt,
  }) {
    return ReviewStage(
      stageIndex: stageIndex ?? this.stageIndex,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isCompleted: isCompleted ?? this.isCompleted,
      isDailyCompleted: isDailyCompleted ?? this.isDailyCompleted,
      completedAt: completedAt ?? (isCompleted == true ? DateTime.now() : this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stageIndex': stageIndex,
      'scheduledDate': scheduledDate.millisecondsSinceEpoch,
      'isCompleted': isCompleted,
      'isDailyCompleted': isDailyCompleted,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }

  factory ReviewStage.fromMap(Map<String, dynamic> map) {
    return ReviewStage(
      stageIndex: map['stageIndex'] as int,
      scheduledDate: DateTime.fromMillisecondsSinceEpoch(map['scheduledDate'] as int),
      isCompleted: map['isCompleted'] as bool,
      isDailyCompleted: map['isDailyCompleted'] as bool,
      completedAt: map['completedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
    );
  }
}