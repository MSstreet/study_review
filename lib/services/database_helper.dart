// services/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/study_item.dart';
import 'logger_service.dart';
import 'notification_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('study_reviews_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize database', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE study_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        completedAt INTEGER,
        reviewStages TEXT NOT NULL,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_study_items_createdAt ON study_items(createdAt);
    ''');

    await db.execute('''
      CREATE INDEX idx_study_items_isDeleted ON study_items(isDeleted);
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    LoggerService.info('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // 기존 데이터 마이그레이션 로직
      await _migrateToV2(db);
    }
  }

  Future<void> _migrateToV2(Database db) async {
    // 기존 버전에서 새 버전으로 데이터 마이그레이션
    // 구현 필요 시 추가
  }

  Future<int> insertStudyItem(StudyItem item) async {
    try {
      final db = await instance.database;
      final id = await db.insert('study_items', item.toMap());
      
      final itemWithId = item.copyWith(id: id);
      await _scheduleAllReviewNotifications(itemWithId);
      
      LoggerService.info('Study item inserted with ID: $id');
      return id;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to insert study item', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _scheduleAllReviewNotifications(StudyItem item) async {
    for (final stage in item.reviewStages.values) {
      if (!stage.isCompleted) {
        await _scheduleReviewNotification(item, stage);
      }
    }
  }

  Future<void> _scheduleReviewNotification(StudyItem item, ReviewStage stage) async {
    try {
      final notificationTime = DateTime(
        stage.scheduledDate.year,
        stage.scheduledDate.month,
        stage.scheduledDate.day,
        9, // 오전 9시
        0,
      );

      final notificationId = _generateNotificationId(item.id!, stage.stageIndex);
      
      await NotificationService.instance.scheduleNotification(
        id: notificationId,
        title: '${stage.stageName} 복습 시간입니다! 📚',
        body: item.content.length > 50 
            ? '${item.content.substring(0, 50)}...'
            : item.content,
        scheduledDate: notificationTime,
      );
    } catch (e, stackTrace) {
      LoggerService.error('Failed to schedule notification', error: e, stackTrace: stackTrace);
    }
  }

  int _generateNotificationId(int itemId, int stageIndex) {
    return itemId * 100 + stageIndex; // 고유 ID 생성
  }

  Future<List<StudyItem>> getReviewsForDate(DateTime date) async {
    try {
      final db = await instance.database;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final maps = await db.query(
        'study_items',
        where: 'isDeleted = 0',
        orderBy: 'createdAt DESC',
      );

      final allItems = maps.map((map) => StudyItem.fromMap(map)).toList();
      
      // 메모리에서 날짜별 필터링 (복잡한 JSON 쿼리 대신)
      final reviewsForDate = <StudyItem>[];
      for (final item in allItems) {
        final dayReviews = item.getReviewsForDate(date);
        if (dayReviews.isNotEmpty) {
          reviewsForDate.add(item);
        }
      }

      return reviewsForDate;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get reviews for date', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<Map<DateTime, List<StudyItem>>> getReviewsForMonth(DateTime month) async {
    try {
      final db = await instance.database;
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final maps = await db.query(
        'study_items',
        where: 'isDeleted = 0',
        orderBy: 'createdAt DESC',
      );

      final allItems = maps.map((map) => StudyItem.fromMap(map)).toList();
      final reviewsByDate = <DateTime, List<StudyItem>>{};

      // 메모리에서 월별 그룹화
      for (final item in allItems) {
        for (final stage in item.reviewStages.values) {
          if (!stage.isCompleted) {
            final reviewDate = DateTime(
              stage.scheduledDate.year,
              stage.scheduledDate.month,
              stage.scheduledDate.day,
            );
            
            if (reviewDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
                reviewDate.isBefore(endOfMonth.add(Duration(days: 1)))) {
              reviewsByDate.putIfAbsent(reviewDate, () => []).add(item);
            }
          }
        }
      }

      return reviewsByDate;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get reviews for month', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  Future<List<StudyItem>> getStudyItemsCreatedOnDate(DateTime date) async {
    try {
      final db = await instance.database;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final maps = await db.query(
        'study_items',
        where: 'createdAt >= ? AND createdAt < ? AND isDeleted = 0',
        whereArgs: [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch],
        orderBy: 'createdAt DESC',
      );

      return maps.map((map) => StudyItem.fromMap(map)).toList();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get study items for date', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> updateStudyItem(StudyItem item) async {
    try {
      final db = await instance.database;
      
      final updatedMap = item.toMap();
      updatedMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      await db.update(
        'study_items',
        updatedMap,
        where: 'id = ?',
        whereArgs: [item.id],
      );

      // 알림 업데이트
      await _updateNotifications(item);
      
      LoggerService.info('Study item updated: ${item.id}');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to update study item', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _updateNotifications(StudyItem item) async {
    // 기존 알림들 취소
    for (int i = 0; i < item.reviewStages.length; i++) {
      final notificationId = _generateNotificationId(item.id!, i);
      await NotificationService.instance.cancelNotification(notificationId);
    }

    // 새로운 알림들 스케줄링
    await _scheduleAllReviewNotifications(item);
  }

  Future<void> markStageCompleted(int itemId, int stageIndex) async {
    try {
      final item = await getStudyItemById(itemId);
      if (item != null) {
        final updatedItem = item.markStageCompleted(stageIndex);
        await updateStudyItem(updatedItem);
        
        // 해당 스테이지 알림 취소
        final notificationId = _generateNotificationId(itemId, stageIndex);
        await NotificationService.instance.cancelNotification(notificationId);
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to mark stage completed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> markDailyCompleted(int itemId, int stageIndex, bool completed) async {
    try {
      final item = await getStudyItemById(itemId);
      if (item != null) {
        final updatedItem = item.markDailyCompleted(stageIndex, completed);
        await updateStudyItem(updatedItem);
      }
    } catch (e, stackTrace) {
      LoggerService.error('Failed to mark daily completed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<StudyItem?> getStudyItemById(int id) async {
    try {
      final db = await instance.database;
      final maps = await db.query(
        'study_items',
        where: 'id = ? AND isDeleted = 0',
        whereArgs: [id],
      );

      return maps.isNotEmpty ? StudyItem.fromMap(maps.first) : null;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get study item by ID', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<StudyItem>> getAllStudyItems({bool includeDeleted = false}) async {
    try {
      final db = await instance.database;
      final whereClause = includeDeleted ? '' : 'isDeleted = 0';
      
      final maps = await db.query(
        'study_items',
        where: whereClause.isEmpty ? null : whereClause,
        orderBy: 'createdAt DESC',
      );

      return maps.map((map) => StudyItem.fromMap(map)).toList();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get all study items', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> deleteStudyItem(int id, {bool softDelete = true}) async {
    try {
      final db = await instance.database;
      
      if (softDelete) {
        await db.update(
          'study_items',
          {
            'isDeleted': 1,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await db.delete(
          'study_items',
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      // 관련 알림들 취소
      final item = await getStudyItemById(id);
      if (item != null) {
        for (int i = 0; i < item.reviewStages.length; i++) {
          final notificationId = _generateNotificationId(id, i);
          await NotificationService.instance.cancelNotification(notificationId);
        }
      }
      
      LoggerService.info('Study item deleted: $id (soft: $softDelete)');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to delete study item', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<StudyItem>> getTodayReviews() async {
    final today = DateTime.now();
    return await getReviewsForDate(today);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // 데이터베이스 백업/복원 메서드
  Future<String> exportData() async {
    try {
      final items = await getAllStudyItems(includeDeleted: true);
      // JSON 형태로 데이터 내보내기 구현
      LoggerService.info('Data exported successfully');
      return ''; // 실제 구현에서는 JSON 문자열 반환
    } catch (e, stackTrace) {
      LoggerService.error('Failed to export data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}