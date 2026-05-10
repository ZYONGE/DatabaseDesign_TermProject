# 시흥시 공공 자전거 대여 서비스 — DB 설계 (수정본)

## 1. 프로젝트 개요

1. 경기도 시흥시의 열악한 교통환경을 개선하기 위해 시민 대상 공공 자전거 대여 서비스를 기획한다.
2. 서비스 운영에 필요한 엔터티를 **14개** 정의하고, MySQL 8.0 기반 관계형 데이터베이스를 설계한다.
3. 시흥시 전역(동 단위)으로 서비스 확장을 가정하여 지역별 수요, 대여소, 거치소, 운영 인력을 통합 관리한다.

---

## 2. 설계 목표

- 지역(동)별 인구 밀집도와 이용 수요를 반영한 자전거 배치 전략 지원
- 사용자 가입부터 대여, 반납, 결제, 마일리지, 리뷰까지 전 과정 데이터 추적
- 유지보수와 고장 신고를 포함한 운영 관제 데이터 축적
- 확장 가능한 스키마 구조(정규화 기반) 확보

---

## 3. 핵심 기능 범위

- **회원 관리**: 가입, 상태 관리, 이용 제한 처리
- **자전거/거치소 관리**: 재고, 상태, 배치 현황
- **대여/반납 처리**: 시작 대여소, 반납 대여소, 이용 시간/거리 계산
- **결제/마일리지**: 이용요금 결제 및 포인트 적립/사용/이력 관리
- **요금 정책 관리**: 기본요금, 추가 분당 요금, 정책 이력 관리
- **운영 관리**: 정비 이력, 신고 이력, 관리자 처리 기록
- **사용자 경험 관리**: 이용 리뷰 및 평점
- **자전거 회수**: 지정 구역 이탈 자전거 회수 이력 관리

---

## 4. 엔터티 목록 (14개)

> 번호 순서는 테이블 생성 시 FK 의존성 순서와 일치한다.

| # | 엔터티명 | 설명 |
|---|----------|------|
| 1 | `Region` | 지역(동 단위) |
| 2 | `Station` | 대여소(거치소 묶음 단위) |
| 3 | `Dock` | 개별 거치 슬롯 |
| 4 | `Bicycle` | 자전거 개체 |
| 5 | `FarePolicy` | 요금 정책 |
| 6 | `User` | 서비스 이용자 |
| 7 | `Rental` | 대여 이력 |
| 8 | `Payment` | 결제 이력 |
| 9 | `MileageHistory` | 마일리지 적립/사용 이력 |
| 10 | `Review` | 이용 리뷰 |
| 11 | `AdminStaff` | 운영 관리자 |
| 12 | `IncidentReport` | 고장/민원 신고 |
| 13 | `Maintenance` | 정비 이력 |
| 14 | `Retrieve` | 자전거 회수 이력 |

---

## 5. 엔터티별 속성 완전 정의

### 5.1 Region (지역)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `region_id` | INT | PK, AUTO_INCREMENT | 지역 ID |
| `region_name` | VARCHAR(50) | NOT NULL, UNIQUE | 동 이름 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

### 5.2 Station (대여소)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `station_id` | INT | PK, AUTO_INCREMENT | 대여소 ID |
| `region_id` | INT | NOT NULL, FK→Region | 소속 지역 |
| `station_name` | VARCHAR(100) | NOT NULL | 대여소 명칭 |
| `address` | VARCHAR(255) | NOT NULL | 주소 |
| `latitude` | DECIMAL(9,6) | NOT NULL | 위도 |
| `longitude` | DECIMAL(9,6) | NOT NULL | 경도 |
| `total_dock_count` | INT | NOT NULL, DEFAULT 0, CHECK(≥0) | 총 거치 슬롯 수 |
| `station_status` | ENUM | NOT NULL | ACTIVE / INACTIVE / MAINTENANCE |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

### 5.3 Dock (거치 슬롯)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `dock_id` | INT | PK, AUTO_INCREMENT | 슬롯 ID |
| `station_id` | INT | NOT NULL, FK→Station | 소속 대여소 |
| `dock_no` | VARCHAR(10) | NOT NULL | 대여소 내 슬롯 번호 |
| `dock_status` | ENUM | NOT NULL | EMPTY / OCCUPIED / BROKEN |
| UNIQUE | — | (station_id, dock_no) | 대여소 내 슬롯 번호 중복 방지 |

---

### 5.4 Bicycle (자전거)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `bicycle_id` | BIGINT | PK, AUTO_INCREMENT | 자전거 ID |
| `serial_no` | VARCHAR(100) | NOT NULL, UNIQUE | 일련번호 |
| `bike_type` | ENUM | NOT NULL | NORMAL / ELECTRIC |
| `bike_status` | ENUM | NOT NULL | AVAILABLE / IN_USE / MAINTENANCE / LOST / RETRIEVED |
| `current_station_id` | INT | FK→Station, NULL 가능 | 현재 위치 대여소 (대여 중엔 NULL) |
| `current_dock_id` | INT | FK→Dock, NULL 가능 | 현재 거치 슬롯 (대여 중엔 NULL) |
| `manufacture_date` | DATE | | 제조일 |
| `registered_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

### 5.5 FarePolicy (요금 정책)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `policy_id` | INT | PK, AUTO_INCREMENT | 정책 ID |
| `policy_name` | VARCHAR(100) | NOT NULL | 정책 명칭 (예: 기본요금제) |
| `base_minutes` | INT | NOT NULL | 기본 무료 이용 시간(분) |
| `base_fare` | INT | NOT NULL, DEFAULT 0, CHECK(≥0) | 기본요금(원) |
| `per_minute_fare` | INT | NOT NULL, CHECK(≥0) | 초과 분당 추가요금(원) |
| `mileage_rate` | DECIMAL(4,2) | NOT NULL, DEFAULT 0.05, CHECK(0~1) | 요금 대비 마일리지 적립 비율 |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE | 현재 적용 여부 |
| `effective_from` | DATE | NOT NULL | 적용 시작일 |
| `effective_to` | DATE | NULL 가능 | 적용 종료일 (NULL이면 현재 유효) |

---

### 5.6 User (사용자)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `user_id` | BIGINT | PK, AUTO_INCREMENT | 사용자 ID |
| `login_id` | VARCHAR(50) | NOT NULL, UNIQUE | 로그인 ID |
| `password_hash` | VARCHAR(255) | NOT NULL | 해시된 비밀번호 |
| `name` | VARCHAR(50) | NOT NULL | 실명 |
| `phone` | VARCHAR(20) | NOT NULL, UNIQUE | 연락처 |
| `email` | VARCHAR(100) | UNIQUE | 이메일 |
| `user_status` | ENUM | NOT NULL | ACTIVE / SUSPENDED / WITHDRAWN |
| `mileage_balance` | INT | NOT NULL, DEFAULT 0, CHECK(≥0) | 현재 마일리지 잔액 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 가입일시 |
| `updated_at` | DATETIME | NOT NULL, DEFAULT NOW() ON UPDATE NOW() | 최종 수정일시 |

---

### 5.7 Rental (대여 이력)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `rental_id` | BIGINT | PK, AUTO_INCREMENT | 대여 ID |
| `user_id` | BIGINT | NOT NULL, FK→User | 이용 사용자 |
| `bicycle_id` | BIGINT | NOT NULL, FK→Bicycle | 대여 자전거 |
| `policy_id` | INT | NOT NULL, FK→FarePolicy | 적용 요금 정책 (대여 시점 고정) |
| `start_station_id` | INT | NOT NULL, FK→Station | 대여 시작 대여소 |
| `start_dock_id` | INT | NOT NULL, FK→Dock | 대여 시작 슬롯 |
| `end_station_id` | INT | FK→Station, NULL 가능 | 반납 대여소 (반납 후 입력) |
| `end_dock_id` | INT | FK→Dock, NULL 가능 | 반납 슬롯 (반납 후 입력) |
| `start_time` | DATETIME | NOT NULL | 대여 시작 일시 |
| `end_time` | DATETIME | NULL 가능 | 반납 완료 일시 |
| `distance_km` | DECIMAL(6,2) | NULL 가능 | 이용 거리(km) |
| `used_mileage` | INT | NOT NULL, DEFAULT 0, CHECK(≥0) | 사용 마일리지(원 차감) |
| `final_fare` | INT | NULL 가능, CHECK(≥0 or NULL) | 최종 확정 요금(원) (반납 후 입력) |
| `rental_status` | ENUM | NOT NULL | RENTED / RETURNED / OVERDUE / CANCELLED |

---

### 5.8 Payment (결제 이력)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `payment_id` | BIGINT | PK, AUTO_INCREMENT | 결제 ID |
| `rental_id` | BIGINT | NOT NULL, FK→Rental | 대상 대여 건 |
| `user_id` | BIGINT | NOT NULL, FK→User | 결제 사용자 |
| `amount` | INT | NOT NULL, CHECK(≥0) | 결제 금액(원) |
| `payment_method` | ENUM | NOT NULL | CARD / MILEAGE / MIXED |
| `payment_time` | DATETIME | NOT NULL | 결제 일시 |
| `payment_status` | ENUM | NOT NULL | SUCCESS / FAIL / CANCEL / REFUND |
| `pg_transaction_id` | VARCHAR(100) | UNIQUE, NULL 가능 | PG사 거래 ID (마일리지 단독 결제 시 NULL) |

---

### 5.9 MileageHistory (마일리지 이력)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `mileage_id` | BIGINT | PK, AUTO_INCREMENT | 이력 ID |
| `user_id` | BIGINT | NOT NULL, FK→User | 대상 사용자 |
| `rental_id` | BIGINT | FK→Rental, NULL 가능 | 연관 대여 건 (관리자 조정 시 NULL) |
| `change_type` | ENUM | NOT NULL | EARN / USE / EXPIRE / ADMIN_ADJUST |
| `change_amount` | INT | NOT NULL | 변동량 (적립: 양수, 차감: 음수) |
| `balance_after` | INT | NOT NULL | 변동 후 잔액 |
| `description` | VARCHAR(255) | | 사유 (예: "대여 적립", "만료 처리") |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 발생 일시 |

---

### 5.10 Review (리뷰)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `review_id` | BIGINT | PK, AUTO_INCREMENT | 리뷰 ID |
| `rental_id` | BIGINT | NOT NULL, FK→Rental, UNIQUE | 대상 대여 건 (1건 1리뷰) |
| `user_id` | BIGINT | NOT NULL, FK→User | 작성자 |
| `rating` | TINYINT | NOT NULL, CHECK(1~5) | 평점 |
| `comment` | TEXT | | 내용 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 작성 일시 |

---

### 5.11 AdminStaff (운영 관리자)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `staff_id` | INT | PK, AUTO_INCREMENT | 관리자 ID |
| `login_id` | VARCHAR(50) | NOT NULL, UNIQUE | 로그인 ID |
| `password_hash` | VARCHAR(255) | NOT NULL | 해시된 비밀번호 |
| `staff_name` | VARCHAR(50) | NOT NULL | 성명 |
| `phone` | VARCHAR(20) | UNIQUE | 연락처 |
| `role` | ENUM | NOT NULL | OPERATOR / ENGINEER / ADMIN |
| `region_id` | INT | FK→Region, NULL 가능 | 담당 지역 (NULL = 전체 담당) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT TRUE | 재직 여부 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

### 5.12 IncidentReport (고장/민원 신고)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `incident_id` | BIGINT | PK, AUTO_INCREMENT | 신고 ID |
| `reporter_user_id` | BIGINT | NOT NULL, FK→User | 신고 사용자 |
| `bicycle_id` | BIGINT | FK→Bicycle, NULL 가능 | 신고 대상 자전거 |
| `station_id` | INT | FK→Station, NULL 가능 | 신고 관련 대여소 |
| `incident_type` | ENUM | NOT NULL | BROKEN / SAFETY / LOST / THEFT / ETC |
| `description` | TEXT | | 신고 내용 |
| `reported_at` | DATETIME | NOT NULL, DEFAULT NOW() | 신고 일시 |
| `incident_status` | ENUM | NOT NULL | OPEN / IN_PROGRESS / RESOLVED / CLOSED |
| `assigned_staff_id` | INT | FK→AdminStaff, NULL 가능 | 담당 관리자 |
| `resolved_at` | DATETIME | NULL 가능 | 처리 완료 일시 |

---

### 5.13 Maintenance (정비 이력)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `maintenance_id` | BIGINT | PK, AUTO_INCREMENT | 정비 ID |
| `bicycle_id` | BIGINT | NOT NULL, FK→Bicycle | 정비 자전거 |
| `staff_id` | INT | NOT NULL, FK→AdminStaff | 담당 정비사 |
| `incident_id` | BIGINT | FK→IncidentReport, NULL 가능 | 연계 신고 건 (자체 정기점검 시 NULL) |
| `maintenance_type` | ENUM | NOT NULL | ROUTINE / REPAIR / INSPECTION |
| `description` | TEXT | | 정비 내용 |
| `started_at` | DATETIME | NOT NULL | 정비 시작 일시 |
| `ended_at` | DATETIME | NULL 가능 | 정비 완료 일시 |
| `maintenance_status` | ENUM | NOT NULL | IN_PROGRESS / COMPLETED |

---

### 5.14 Retrieve (회수 이력)
| 컬럼명 | 타입 | 제약 | 설명 |
|--------|------|------|------|
| `retrieve_id` | BIGINT | PK, AUTO_INCREMENT | 회수 ID |
| `bicycle_id` | BIGINT | NOT NULL, FK→Bicycle | 회수 자전거 |
| `staff_id` | INT | NOT NULL, FK→AdminStaff | 담당 관리자 |
| `incident_id` | BIGINT | FK→IncidentReport, NULL 가능 | 연계 신고 건 |
| `retrieve_location` | VARCHAR(255) | NOT NULL | 자전거 발견 주소 |
| `retrieve_lat` | DECIMAL(9,6) | | 발견 위도 |
| `retrieve_lng` | DECIMAL(9,6) | | 발견 경도 |
| `target_station_id` | INT | NOT NULL, FK→Station | 반납 목표 대여소 |
| `retrieved_at` | DATETIME | NOT NULL | 회수 시작 일시 |
| `completed_at` | DATETIME | NULL 가능 | 반납 완료 일시 |
| `retrieve_reason` | ENUM | NOT NULL | OUT_OF_AREA / ABANDONED / REPORTED / ETC |
| `retrieve_status` | ENUM | NOT NULL | IN_PROGRESS / COMPLETED |

---

## 6. 관계 설계 (ERD 기준)

```
Region ──(1:N)── Station ──(1:N)── Dock
                    │
                    └──(1:N)── Bicycle ──(1:N)── Rental ──(1:1)── Review
                                   │                │
                              Maintenance        Payment
                                   │                │
                              IncidentReport   MileageHistory
                                   │
                               Retrieve
                               
User ──(1:N)── Rental
User ──(1:N)── Payment
User ──(1:N)── MileageHistory
User ──(1:N)── Review
User ──(1:N)── IncidentReport

FarePolicy ──(1:N)── Rental

AdminStaff ──(1:N)── Maintenance
AdminStaff ──(1:N)── Retrieve
AdminStaff ──(1:N)── IncidentReport (assigned)
AdminStaff ──(N:1)── Region
```

### 6.1 주요 관계 상세

| 관계 | 카디널리티 | FK 컬럼 | 비고 |
|------|-----------|---------|------|
| Region → Station | 1:N | Station.region_id | 동 단위 대여소 그룹 |
| Station → Dock | 1:N | Dock.station_id | 슬롯 단위 관리 |
| Station → Bicycle | 1:N | Bicycle.current_station_id | NULL 가능 (대여 중·회수 중) |
| Dock → Bicycle | 1:1 | Bicycle.current_dock_id | 정확한 거치 위치 |
| User → Rental | 1:N | Rental.user_id | |
| Bicycle → Rental | 1:N | Rental.bicycle_id | |
| FarePolicy → Rental | 1:N | Rental.policy_id | 대여 시점 정책 고정 |
| Station → Rental | 1:N (×2) | start_station_id, end_station_id | 출발/반납 대여소 |
| Dock → Rental | 1:N (×2) | start_dock_id, end_dock_id | 출발/반납 슬롯 |
| Rental → Payment | 1:N | Payment.rental_id | DB UNIQUE 없음; 비즈니스상 1:1로 운영 (환불·재결제 등 예외 케이스 허용) |
| Rental → MileageHistory | 1:N | MileageHistory.rental_id | 적립+사용 각 1건 발생 가능 |
| Rental → Review | 1:1 | Review.rental_id UNIQUE | |
| Bicycle → IncidentReport | 1:N | IncidentReport.bicycle_id | |
| Bicycle → Maintenance | 1:N | Maintenance.bicycle_id | |
| IncidentReport → Maintenance | 1:N | Maintenance.incident_id | NULL 가능 (정기점검); 하나의 신고에 여러 정비 연결 가능 |
| AdminStaff → Maintenance | 1:N | Maintenance.staff_id | |
| AdminStaff → Retrieve | 1:N | Retrieve.staff_id | |
| AdminStaff → IncidentReport | 1:N | IncidentReport.assigned_staff_id | |

---

## 7. 비즈니스 규칙

1. **대여 가능 조건**: `bike_status = AVAILABLE` AND `dock_status = OCCUPIED` AND `user_status = ACTIVE`
2. **동시 대여 제한**: 사용자당 `rental_status = RENTED` 건이 1건 초과 불가. MySQL은 조건부(Partial) UNIQUE INDEX를 지원하지 않으므로 DB 인덱스만으로는 완전 보장이 어렵고, 애플리케이션 레이어에서 `SELECT FOR UPDATE`로 병행 검증 필요
3. **반납 처리**: `end_time`, `end_station_id`, `end_dock_id`, `final_fare` 기록 후 `rental_status = RETURNED`로 변경
4. **마일리지 처리**: 결제 완료(`payment_status = SUCCESS`) 시 `mileage_rate`에 따라 자동 적립, `User.mileage_balance` 업데이트 + `MileageHistory` INSERT (트리거 `trg_payment_earn_mileage`가 자동 처리)
5. **리뷰 작성 조건**: `rental_status = RETURNED`이고 해당 `rental_id`로 `Review`가 존재하지 않을 때만 작성 가능
6. **신고-정비 연계**: `Maintenance` 생성 시 연계된 `IncidentReport.incident_status`를 `IN_PROGRESS`로 자동 변경 (트리거 `trg_maintenance_update_incident`)
7. **요금 계산**: `final_fare = MAX(0, base_fare + (이용분 - base_minutes) × per_minute_fare) - used_mileage`
8. **정책 적용 기준**: 대여 시작 시점(`start_time`)에 `is_active = TRUE`인 정책 적용, 대여 중 정책 변경 불가
9. **구역 이탈 판단**: GPS 기준 시흥시 경계 이탈 시 `Retrieve` 이력 생성
10. **슬롯 상태 동기화**: 대여 시 `Dock.dock_status = EMPTY`, 반납 시 `OCCUPIED`, 고장 신고 시 `BROKEN`으로 자동 변경

---

## 8. 정규화 요약

| 정규형 | 적용 내용 |
|--------|----------|
| **1NF** | 모든 속성 원자값 유지, 반복 그룹 없음 |
| **2NF** | 단일 PK 사용으로 부분 종속 없음 |
| **3NF** | 지역 정보 → `Region` 분리 / 요금제 정보 → `FarePolicy` 분리 / 마일리지 변동 → `MileageHistory` 분리 / 슬롯 상태 → `Dock` 분리 |

---

## 9. 인덱스 및 제약조건 설계

### UNIQUE 인덱스

| 대상 | 목적 |
|------|------|
| `User.login_id` | 로그인 ID 중복 방지 |
| `User.phone` | 전화번호 중복 방지 |
| `Bicycle.serial_no` | 자전거 일련번호 중복 방지 |
| `Review.rental_id` | 대여 1건당 리뷰 1개 보장 |
| `Dock.(station_id, dock_no)` | 대여소 내 슬롯 번호 유일성 |
| `Payment.pg_transaction_id` | PG사 거래 ID 중복 방지 |
| `AdminStaff.login_id` | 관리자 로그인 ID 중복 방지 |
| `Rental.(user_id, rental_status)` | 사용자당 동일 상태 대여 중복 방지 (조건부 UNIQUE 한계로 앱 레이어 병행 처리 필요) |

### 복합 검색 인덱스

| 인덱스명 | 대상 컬럼 | 목적 |
|---------|----------|------|
| `idx_rental_user_time` | `Rental(user_id, start_time)` | 사용자별 대여 이력 조회 (마이페이지) |
| `idx_rental_bicycle_time` | `Rental(bicycle_id, start_time)` | 자전거별 이용 이력 조회 |
| `idx_rental_status_time` | `Rental(rental_status, start_time)` | 미반납·연체 자전거 실시간 모니터링 |
| `idx_payment_user_time` | `Payment(user_id, payment_time)` | 사용자별 결제 내역 조회 |
| `idx_payment_rental` | `Payment(rental_id)` | 대여-결제 조인 최적화 |
| `idx_incident_status_time` | `IncidentReport(incident_status, reported_at)` | 미처리(OPEN) 신고 목록 모니터링 |
| `idx_incident_bicycle` | `IncidentReport(bicycle_id)` | 자전거별 신고 이력 조회 |
| `idx_maintenance_bicycle_time` | `Maintenance(bicycle_id, started_at)` | 자전거별 정비 이력 조회 |
| `idx_mileage_user_time` | `MileageHistory(user_id, created_at)` | 사용자별 마일리지 변동 이력 조회 |
| `idx_retrieve_bicycle` | `Retrieve(bicycle_id)` | 자전거별 회수 이력 조회 |
| `idx_retrieve_status` | `Retrieve(retrieve_status)` | 진행 중인 회수 작업 목록 모니터링 |

### CHECK 제약 조건

| 테이블.컬럼 | 조건 | 목적 |
|------------|------|------|
| `Review.rating` | BETWEEN 1 AND 5 | 유효하지 않은 평점 입력 차단 |
| `Payment.amount` | ≥ 0 | 결제 금액 음수 불가 |
| `Rental.used_mileage` | ≥ 0 | 마일리지 사용량 음수 불가 |
| `Rental.final_fare` | IS NULL OR ≥ 0 | 최종 요금 음수 불가 |
| `FarePolicy.base_fare` | ≥ 0 | 기본요금 음수 불가 |
| `FarePolicy.per_minute_fare` | ≥ 0 | 분당 추가요금 음수 불가 |
| `FarePolicy.mileage_rate` | BETWEEN 0 AND 1 | 마일리지 적립률 0~100% 이내 |
| `Station.total_dock_count` | ≥ 0 | 슬롯 수 음수 불가 |
| `User.mileage_balance` | ≥ 0 | 마일리지 잔액 음수 불가 |

---

## 10. 트리거 설계

DB 레벨에서 연관 테이블 간 상태를 자동 동기화하여 애플리케이션 코드 누락으로 인한 데이터 불일치를 방지한다.

| 트리거명 | 이벤트 | 대상 테이블 | 동작 |
|---------|--------|------------|------|
| `trg_maintenance_update_incident` | AFTER INSERT | Maintenance | 연계된 IncidentReport가 OPEN이면 IN_PROGRESS로 자동 전환 |
| `trg_maintenance_complete_bicycle` | AFTER UPDATE | Maintenance | 정비 상태가 COMPLETED로 변경되면 해당 자전거를 AVAILABLE로 복구 |
| `trg_payment_earn_mileage` | AFTER INSERT | Payment | 결제 SUCCESS 시 mileage_rate 기준으로 마일리지 적립 및 MileageHistory 기록 |

### 트리거 상세 동작 흐름

**trg_maintenance_update_incident**
```
Maintenance INSERT
  → incident_id IS NOT NULL?
    → IncidentReport.incident_status = 'OPEN'?
      → incident_status = 'IN_PROGRESS' 로 자동 갱신
```

**trg_maintenance_complete_bicycle**
```
Maintenance UPDATE
  → maintenance_status: IN_PROGRESS → COMPLETED?
    → Bicycle.bike_status = 'AVAILABLE' 로 자동 복구
```

**trg_payment_earn_mileage**
```
Payment INSERT
  → payment_status = 'SUCCESS'?
    → Rental → FarePolicy.mileage_rate 조회
    → 적립 포인트 = FLOOR(amount × mileage_rate)
    → User.mileage_balance += 적립 포인트
    → MileageHistory INSERT (change_type='EARN')
```

---

## 11. 핵심 운영 쿼리 예시

관리자 대시보드 및 운영 모니터링에 자주 사용되는 쿼리 패턴을 정리한다.

| # | 쿼리 목적 | 활용 시나리오 |
|---|----------|-------------|
| 1 | 대여소별 현재 이용 가능 자전거 수 | 대시보드 실시간 재고 현황 |
| 2 | 미처리(OPEN) 신고 목록 (최신순) | 운영자 우선처리 대상 확인 |
| 3 | 현재 연체 중인 대여 목록 (오래된 순) | 연체 이용자 알림 발송 |
| 4 | 자전거별 누적 수익 상위 10대 | 정비 우선순위 산정 및 수익 분석 |
| 5 | 동별 월간 대여 건수 통계 | 지역별 수요 분석 및 자전거 배치 최적화 |

---

## 12. 데이터 흐름 요약

사용자의 한 번 대여 사이클에서 발생하는 레코드 흐름:

```
[대여 시작]
  Rental INSERT (rental_status = RENTED)
  Bicycle UPDATE (bike_status = IN_USE)
  Dock UPDATE (dock_status = EMPTY)

[반납 완료]
  Rental UPDATE (rental_status = RETURNED, end_time/end_dock_id/final_fare 입력)
  Bicycle UPDATE (bike_status = AVAILABLE, current_station_id/current_dock_id 갱신)
  Dock UPDATE (dock_status = OCCUPIED)

[결제 처리]
  Payment INSERT (payment_status = SUCCESS)
  → 트리거: User.mileage_balance += 적립 포인트
  → 트리거: MileageHistory INSERT (change_type = EARN)

[리뷰 작성 (선택)]
  Review INSERT
```

---

## 13. 정보 공개 정책

### 사용자 접근 범위
- 본인 계정 정보, 대여/반납 이력, 결제 이력, 마일리지 이력만 조회 가능
- 타 사용자 개인정보 및 운영 내부 데이터 비공개
- 리뷰 표시 시 닉네임 기반 최소 정보만 노출

### 관리자 접근 범위 (권한별 분리)

| 역할 | 열람 가능 | 수정 가능 |
|------|----------|----------|
| OPERATOR | 대여소/자전거 현황, 신고 목록 | 자전거 상태, 신고 배정 |
| ENGINEER | 정비/신고 이력 | 정비 이력 등록·수정 |
| ADMIN | 전체 데이터 | 전체 + 사용자 정지/해제, 정책 변경 |

---

## 14. 기대 효과

- 시민 이동 편의 향상 및 단거리 이동 교통 분산
- 데이터 기반 자전거 배치·정비 의사결정 가능
- 운영 효율화 및 사용자 만족도 개선
- 마일리지·리뷰 연계로 재이용 유도
