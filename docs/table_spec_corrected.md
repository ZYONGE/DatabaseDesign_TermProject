# Table 기술서 (정정본) — 시흥시 공공 자전거 대여 서비스

> **생성 기준:** `sql/ddl/DDL.sql` (속성명 전역 유일 적용 버전)  
> **수정 내용:** 이전 보고서 Table 기술서의 컬럼명 불일치, ENUM 기본값 오류, NOT NULL 누락, 비고 오류를 DDL 기준으로 정정.

---

## 1. Region (지역)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `region_id` | INT | ✓ | PK, AUTO_INCREMENT | | 지역 ID |
| 2 | `region_name` | VARCHAR(50) | ✓ | UNIQUE | | 동 이름 |
| 3 | `region_created_at` | DATETIME | ✓ | | NOW() | 등록일시 |

> 비고: 시흥시 내 행정 동(洞) 단위 지역 정보를 저장. 대여소(`Station`)의 소속 지역 기준점이 된다.

---

## 2. BicycleType (자전거 종류)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `bicycleType_id` | INT | ✓ | PK, AUTO_INCREMENT | | 종류 ID |
| 2 | `bicycleType_name` | VARCHAR(50) | ✓ | UNIQUE | | 종류명 (일반 / 어린이 / 2인용) |
| 3 | `max_passenger` | TINYINT | ✓ | | 1 | 최대 탑승 인원 |
| 4 | `inspection_cycle` | INT | ✓ | | 30 | 정기점검 주기(일) |
| 5 | `bicycletype_description` | MEDIUMTEXT | | | NULL | 종류 설명 |

> 비고: 자전거 종류 메타데이터 관리. 어린이 자전거는 만 13세 미만 사용자만 대여 가능(`User.user_birth_date` 실시간 계산). 종류별 `max_passenger` 기본값: 일반 1, 어린이 1, 2인용 2.

---

## 3. Station (대여소)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `station_id` | INT | ✓ | PK, AUTO_INCREMENT | | 대여소 ID |
| 2 | `station_name` | VARCHAR(100) | ✓ | | | 대여소 명칭 |
| 3 | `station_address` | VARCHAR(255) | ✓ | | | 주소 |
| 4 | `station_contactnumber` | VARCHAR(20) | | | NULL | 연락처 |
| 5 | `station_status` | ENUM('운영중','휴관','정비중') | ✓ | | '운영중' | 운영 상태 |
| 6 | `station_created_at` | DATETIME | | | NOW() | 등록일시 |
| 7 | `station_latitude` | DECIMAL(10,7) | | | NULL | GPS 위도 |
| 8 | `station_longitude` | DECIMAL(10,7) | | | NULL | GPS 경도 |
| 9 | `station_totaldocks` | INT | | | 0 | 총 거치대 수 |
| 10 | `station_region_id` | INT | ✓ | FK → Region | | 소속 지역 |

> 비고: 시흥시 내 유인 자전거 대여소. `station_status = '운영중'`인 모든 대여소에는 운영요원이 1명 이상 배정되어야 한다.

---

## 4. Bicycle (자전거)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `bicycle_id` | INT | ✓ | PK, AUTO_INCREMENT | | 자전거 ID |
| 2 | `bicycle_status` | ENUM('정상','대여중','정비중','분실','회수중') | ✓ | | '정상' | 자전거 상태 |
| 3 | `bicycle_registered_at` | DATETIME | | | NOW() | 등록일시 |
| 4 | `bicycle_gps_latitude` | DECIMAL(10,7) | | | NULL | GPS 위도 (대여중일 때만 갱신) |
| 5 | `bicycle_gps_longitude` | DECIMAL(10,7) | | | NULL | GPS 경도 (대여중일 때만 갱신) |
| 6 | `bicycle_gps_updated_at` | DATETIME | | | NULL | GPS 최종 갱신일시 |
| 7 | `bicycleType_id` | INT | ✓ | FK → BicycleType | | 자전거 종류 |
| 8 | `bicycle_station_id` | INT | | FK → Station | NULL | 현재 위치 대여소 (대여중·분실 시 NULL) |

> 비고: 자전거 개체 관리. `bicycle_status` 기본값은 `'정상'`(ENUM: 정상/대여중/정비중/분실/회수중). GPS는 대여 중일 때만 갱신하며, 반납·회수 완료 시 NULL로 초기화한다.

---

## 5. User (사용자)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `user_id` | INT | ✓ | PK, AUTO_INCREMENT | | 사용자 ID |
| 2 | `user_name` | VARCHAR(50) | ✓ | | | 실명 |
| 3 | `user_birth_date` | DATE | ✓ | | | 생년월일 |
| 4 | `user_phone` | VARCHAR(20) | ✓ | UNIQUE | | 연락처 |
| 5 | `user_address` | VARCHAR(255) | | | NULL | 주소 |
| 6 | `user_status` | ENUM('정상','정지') | ✓ | | '정상' | 계정 상태 |
| 7 | `user_created_at` | DATETIME | | | NOW() | 등록일시 |

> 비고: 서비스 이용 회원. `user_status = '정지'`인 경우 대여 불가. 패널티 만료 시 자동으로 `'정상'`으로 복구.

---

## 6. AdminStaff (운영 관리자)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `staff_id` | INT | ✓ | PK, AUTO_INCREMENT | | 관리자 ID |
| 2 | `staff_name` | VARCHAR(50) | ✓ | | | 성명 |
| 3 | `staff_phone` | VARCHAR(20) | ✓ | UNIQUE | | 연락처 |
| 4 | `staff_is_active` | TINYINT(1) | | | 1 | 재직 여부 (1=재직, 0=퇴직) |
| 5 | `staff_created_at` | DATETIME | | | NOW() | 등록일시 |
| 6 | `staff_station_id` | INT | | FK → Station | NULL | 담당 대여소 (관리자 역할은 NULL 가능) |

> 비고: 운영 관리자 및 현장 운영요원 정보 관리. 관리자 역할(`staff_station_id = NULL`)과 대여소 배정 운영요원으로 구분.

---

## 7. Rental (대여 이력)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `rental_id` | INT | ✓ | PK, AUTO_INCREMENT | | 대여 ID |
| 2 | `rental_start_time` | DATETIME | ✓ | | | 대여 시작일시 |
| 3 | `rental_end_time` | DATETIME | | | NULL | 반납일시 |
| 4 | `rental_status` | ENUM('대여중','반납','미반납') | ✓ | | '대여중' | 대여 상태 |
| 5 | `start_station_id` | INT | ✓ | FK → Station | | 시작 대여소 |
| 6 | `return_station_id` | INT | | FK → Station | NULL | 반납 대여소 (대여중 NULL) |
| 7 | `rental_bicycle_id` | INT | ✓ | FK → Bicycle | | 대여 자전거 |
| 8 | `rental_user_id` | INT | ✓ | FK → User | | 이용 사용자 |

> 비고: 대여 이력 핵심 테이블. `rental_status` ENUM: 대여중/반납/미반납. 24시간 이상 미반납 시 배치 작업이 `'미반납'`으로 변경하고 `Penalty`를 생성한다.

---

## 8. IncidentReport (고장/민원 신고)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `incident_id` | INT | ✓ | PK, AUTO_INCREMENT | | 신고 ID |
| 2 | `incident_type` | ENUM('고장','방치','분실','기타') | ✓ | | | 신고 유형 |
| 3 | `incident_description` | TEXT | | | NULL | 신고 내용 |
| 4 | `incident_reported_at` | DATETIME | | | NOW() | 신고일시 |
| 5 | `incident_status` | ENUM('접수','처리중','완료') | ✓ | | '접수' | 처리 상태 |
| 6 | `incident_resolved_at` | DATETIME | | | NULL | 처리 완료일시 |
| 7 | `incident_bicycle_id` | INT | | FK → Bicycle | NULL | 신고 자전거 |
| 8 | `incident_user_id` | INT | | FK → User | NULL | 신고자 (NULL = 관리자 직접 접수) |
| 9 | `incident_staff_id` | INT | ✓ | FK → AdminStaff | | 담당 관리자 |

> 비고: 고장·방치·분실·기타 신고 이력 관리. 신고 유형에 따라 `Maintenance`(수리) 또는 `Retrieve`(회수) 연계 가능.

---

## 9. Maintenance (정비 이력)

> 자전거 정비는 **외부 업체(외주)에 위탁**하여 진행한다. 내부 `AdminStaff`는 정비를 직접 수행하지 않으므로 `staff_id` 컬럼이 없다.

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `maintenance_id` | INT | ✓ | PK, AUTO_INCREMENT | | 정비 ID |
| 2 | `maintenance_type` | ENUM('정기점검','수리','청소') | ✓ | | | 정비 유형 |
| 3 | `maintenance_description` | MEDIUMTEXT | | | NULL | 정비 의뢰 내용 |
| 4 | `maintenance_started_at` | DATETIME | ✓ | | | 정비 의뢰일시 |
| 5 | `maintenance_ended_at` | DATETIME | | | NULL | 정비 완료일시 |
| 6 | `maintenance_status` | ENUM('진행중','완료') | ✓ | | '진행중' | 정비 상태 |
| 7 | `maintenance_bicycle_id` | INT | ✓ | FK → Bicycle | | 정비 자전거 |
| 8 | `maintenance_incident_id` | INT | | FK → IncidentReport | NULL | 연계 신고 (정기점검 의뢰 시 NULL) |

> 비고: 외주 정비 이력 기록. `maintenance_status` ENUM: 진행중/완료, 기본값 `'진행중'`. `staff_id` 컬럼 없음(외주 원칙).

---

## 10. Retrieve (자전거 회수 이력)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `retrieve_id` | INT | ✓ | PK, AUTO_INCREMENT | | 회수 ID |
| 2 | `retrieve_latitude` | DECIMAL(10,7) | | | NULL | 발견 위치 위도 |
| 3 | `retrieve_longitude` | DECIMAL(10,7) | | | NULL | 발견 위치 경도 |
| 4 | `retrieve_location` | VARCHAR(255) | | | NULL | 발견 주소 |
| 5 | `retrieved_at` | DATETIME | | | NOW() | 회수 시작일시 |
| 6 | `retrieve_completed_at` | DATETIME | | | NULL | 반납 완료일시 |
| 7 | `retrieve_reason` | ENUM('방치','미반납','구역이탈','기타') | ✓ | | (없음) | 회수 사유 |
| 8 | `retrieve_status` | ENUM('진행중','완료') | ✓ | | '진행중' | 회수 상태 |
| 9 | `retrieve_bicycle_id` | INT | | FK → Bicycle | NULL | 회수 자전거 |
| 10 | `retrieve_staff_id` | INT | | FK → AdminStaff | NULL | 담당 관리자 (자동 생성 시 NULL) |
| 11 | `retrieve_incident_id` | INT | | FK → IncidentReport | NULL | 연계 신고 (자동 감지 시 NULL) |
| 12 | `retrieve_station_id` | INT | ✓ | FK → Station | | 반납 목표 대여소 |

> 비고: 방치·미반납·구역이탈·기타 사유 자전거 회수 이력. `retrieved_at`은 **회수 시작일시**, `retrieve_completed_at`은 **반납 완료일시**로 분리된 별개 컬럼이다. `retrieve_reason` 기본값 없음(NOT NULL). `found_region_id` 컬럼은 존재하지 않는다.

---

## 11. Penalty (패널티)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `penalty_id` | INT | ✓ | PK, AUTO_INCREMENT | | 패널티 ID |
| 2 | `penalty_days` | INT | ✓ | | | 대여 금지 일수 |
| 3 | `penalty_ban_start` | DATE | ✓ | | | 금지 시작일 |
| 4 | `penalty_ban_end` | DATE | ✓ | | | 금지 종료일 |
| 5 | `penalty_user_id` | INT | ✓ | FK → User | | 대상 사용자 |
| 6 | `penalty_rental_id` | INT | ✓ | FK → Rental, UNIQUE | | 미반납 대여 건 (건당 1개) |

> 비고: 미반납 자전거 대여 금지 패널티. `penalty_days = 경과일수 × 10`. `penalty_rental_id` UNIQUE 제약으로 동일 대여 건에 패널티 중복 생성 방지.

---

## 12. Allocation (자전거 배치 이력)

| No | 속성명 | 데이터 타입 | NN | Key | Default | 설명 |
|----|--------|-------------|:--:|-----|---------|------|
| 1 | `allocation_id` | INT | ✓ | PK, AUTO_INCREMENT | | 배치 ID |
| 2 | `allocated_at` | DATETIME | | | NOW() | 배치일시 |
| 3 | `allocation_note` | MEDIUMTEXT | | | NULL | 비고 |
| 4 | `allocation_station_id` | INT | | FK → Station | NULL | 배치 대여소 |
| 5 | `allocation_staff_id` | INT | | FK → AdminStaff | NULL | 배치 담당자 |
| 6 | `allocation_bicycle_id` | INT | | FK → Bicycle | NULL | 배치 자전거 |

> 비고: 수요 데이터 기반 관리자 자전거 배치 이력 기록. 배치 타임스탬프는 `allocated_at`(단일 컬럼). `from_station_id`/`to_station_id` 분리 컬럼은 존재하지 않으며 배치 목표 대여소는 `allocation_station_id` 단일 컬럼으로 관리한다.
