# Study Review Helper (복습 도우미)

효과적인 학습을 위한 복습 스케줄링 앱입니다. 간격 반복 학습법을 기반으로 하여 학습 내용을 체계적으로 복습할 수 있도록 도와줍니다.

## 주요 기능

### 📚 학습 관리
- 새로운 학습 내용 추가
- 학습 내용 수정 및 삭제
- 전체 학습 목록 조회

### 🔄 복습 스케줄링
- 간격 반복 학습법 적용 (1일차, 3일차, 7일차, 15일차, 30일차)
- 자동 복습 일정 생성
- 복습 완료 체크 및 관리

### 📅 캘린더 뷰
- 월별 복습 일정 확인
- 날짜별 학습 내용 및 복습 항목 조회
- 캘린더에서 직접 학습 내용 추가

### 🔔 알림 시스템
- 복습 예정일 알림
- 즉시 알림 테스트
- 알림 권한 관리

### 📊 오늘의 복습
- 오늘 복습해야 할 항목들 그룹화
- 스테이지별 복습 진행 상황 확인
- 복습 완료 처리

## 기술 스택

- **Framework**: Flutter
- **Language**: Dart
- **Database**: SQLite (sqflite)
- **Local Notifications**: flutter_local_notifications
- **Calendar**: table_calendar
- **Date/Time**: intl, timezone

## 설치 및 실행

### 필수 요구사항
- Flutter SDK (3.0.0 이상)
- Dart SDK
- Android Studio / VS Code

### 설치 방법

1. 저장소 클론
```bash
git clone https://github.com/your-username/study_review.git
cd study_review
```

2. 의존성 설치
```bash
flutter pub get
```

3. 앱 실행
```bash
flutter run
```

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── models/
│   └── study_item.dart      # 학습 항목 모델
├── screens/
│   ├── main_screen.dart     # 메인 화면
│   ├── today_reviews_tab.dart    # 오늘 복습 탭
│   ├── calendar_tab.dart    # 캘린더 탭
│   ├── all_study_items_tab.dart  # 전체 목록 탭
│   └── add_study_item_tab.dart   # 추가 탭
├── services/
│   ├── database_helper.dart # 데이터베이스 관리
│   ├── notification_service.dart # 알림 서비스
│   └── logger_service.dart  # 로깅 서비스
└── widgets/
    ├── common_widgets.dart  # 공통 위젯
    ├── loading_widget.dart  # 로딩 위젯
    └── error_widget.dart    # 오류 위젯
```

## 사용법

### 1. 학습 내용 추가
- "추가" 탭에서 새로운 학습 내용을 입력
- 자동으로 복습 스케줄이 생성됩니다

### 2. 복습 관리
- "오늘 복습" 탭에서 오늘 복습할 항목들을 확인
- 체크박스로 일일 복습 완료 체크
- "완료" 버튼으로 스테이지 복습 완료 처리

### 3. 캘린더 확인
- "캘린더" 탭에서 월별 복습 일정 확인
- 날짜를 선택하여 해당 날짜의 학습/복습 내용 조회
- 캘린더에서 직접 새로운 학습 내용 추가 가능

### 4. 알림 설정
- 앱 상단 메뉴에서 알림 테스트 및 관리
- 복습 예정일 알림 자동 수신

## 복습 스케줄

앱은 간격 반복 학습법을 기반으로 다음과 같은 복습 스케줄을 자동 생성합니다:

- **1일차**: 학습 후 1일 후
- **3일차**: 학습 후 3일 후  
- **7일차**: 학습 후 7일 후
- **15일차**: 학습 후 15일 후
- **30일차**: 학습 후 30일 후

## 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 연락처

프로젝트 링크: [https://github.com/your-username/study_review](https://github.com/your-username/study_review)

---

⭐ 이 프로젝트가 도움이 되었다면 스타를 눌러주세요!
