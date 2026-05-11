# 개체·속성 정의서

## 시흥시 공공 자전거 대여 서비스

설계 기준: `docs/design.md`  
정규화 기준: **제3정규형(3NF)**  
엔터티 수: **12개**

---

## 1. Region (지역)

**설명**: 시흥시 내 행정 구역(동 단위)을 관리하는 최상위 참조 테이블. 대여소(Station)와 배치 이력(Allocation)이 지역 단위로 참조한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `region_id` | INT | PK, AUTO_INCREMENT | 지역 ID |
| `region_name` | VARCHAR(50) | NOT NULL, UNIQUE | 동 이름 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

## 2. BicycleType (자전거 종류)

**설명**: 자전거 종류(일반 / 어린이 / 2인용)를 정의하는 테이블. 종류별 최대 탑승 인원과 정기점검 주기를 관리한다. 어린이 자전거는 만 13세 미만 사용자만 대여 가능하며, 연령 판정은 대여 시점에 `User.birth_date`를 기준으로 실시간 계산한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `type_id` | INT | PK, AUTO_INCREMENT | 종류 ID |
| `type_name` | VARCHAR(50) | NOT NULL, UNIQUE | 종류명 (일반/어린이/2인용) |
| `max_passenger` | TINYINT | NOT NULL, DEFAULT 1 | 최대 탑승 인원 (일반·어린이=1, 2인용=2) |
| `inspection_cycle` | INT | NOT NULL, DEFAULT 30 | 정기점검 주기(일) |
| `description` | TEXT | NULL 허용 | 종류 설명 |

> **3NF 분리 근거**: `type_name`, `max_passenger`, `inspection_cycle` 등 종류 속성이 `Bicycle` 내에 직접 저장되면 `bicycle_id → type_id → {type_name, max_passenger, ...}` 이행 종속이 발생하므로 별도 엔터티로 분리하였다.

---

## 3. Station (대여소)

**설명**: 자전거를 대여하고 반납하는 물리적 거점 정보. 반납은 시흥시 내 `station_status = '운영중'`인 모든 대여소에서 가능하다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `station_id` | INT | PK, AUTO_INCREMENT | 대여소 ID |
| `region_id` | INT | FK → Region, NOT NULL | 소속 지역 |
| `station_name` | VARCHAR(100) | NOT NULL | 대여소 명칭 |
| `address` | VARCHAR(255) | NOT NULL | 주소 |
| `contact` | VARCHAR(20) | NULL 허용 | 연락처 |
| `latitude` | DECIMAL(10,7) | NULL 허용 | GPS 위도 |
| `longitude` | DECIMAL(10,7) | NULL 허용 | GPS 경도 |
| `total_docks` | INT | NOT NULL, DEFAULT 0 | 총 거치대 수 |
| `station_status` | ENUM | NOT NULL, DEFAULT '운영중' | 운영중 / 휴관 / 정비중 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

## 4. Bicycle (자전거)

**설명**: 서비스에 등록된 개별 자전거. GPS 좌표를 주기적으로 갱신하며, 시흥시 경계 이탈 시 자동 회수 프로세스가 시작된다. `current_station_id`는 대여중·정비중·분실·회수중 상태일 때 NULL이다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `bicycle_id` | INT | PK, AUTO_INCREMENT | 자전거 ID |
| `type_id` | INT | FK → BicycleType, NOT NULL | 자전거 종류 |
| `bike_status` | ENUM | NOT NULL, DEFAULT '정상' | 정상 / 대여중 / 정비중 / 분실 / 회수중 |
| `current_station_id` | INT | FK → Station, NULL 허용 | 현재 위치 대여소 (대여중·정비중·분실·회수중 시 NULL) |
| `gps_latitude` | DECIMAL(10,7) | NULL 허용 | 실시간 GPS 위도 (대여중일 때만 갱신, 반납·회수 완료 시 NULL) |
| `gps_longitude` | DECIMAL(10,7) | NULL 허용 | 실시간 GPS 경도 (대여중일 때만 갱신, 반납·회수 완료 시 NULL) |
| `gps_updated_at` | DATETIME | NULL 허용 | GPS 최종 갱신 일시 |
| `registered_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

## 5. User (사용자)

**설명**: 서비스를 이용하는 일반 시민 회원. `birth_date`를 기준으로 대여 시점에 연령을 실시간 계산하여 어린이 자전거 이용 자격을 검증한다. `is_minor` 파생 컬럼은 `user_id → birth_date → is_minor` 이행 종속(3NF 위반)에 해당하므로 제거하였다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `user_id` | INT | PK, AUTO_INCREMENT | 사용자 ID |
| `name` | VARCHAR(50) | NOT NULL | 실명 |
| `birth_date` | DATE | NOT NULL | 생년월일 (어린이 자전거 이용 자격 검증용) |
| `phone` | VARCHAR(20) | NOT NULL, UNIQUE | 연락처 |
| `address` | VARCHAR(255) | NULL 허용 | 주소 |
| `user_status` | ENUM | NOT NULL, DEFAULT '정상' | 정상 / 정지 |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

---

## 6. AdminStaff (운영 관리자)

**설명**: 서비스를 운영·관리하는 내부 직원. `station_id = NULL`은 전사 관리 역할(관리자), `station_id`가 지정된 경우 해당 대여소 상주 직원(정비사·운영요원)을 의미한다. 역할 구분은 애플리케이션 레이어에서 처리한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `staff_id` | INT | PK, AUTO_INCREMENT | 관리자 ID |
| `staff_name` | VARCHAR(50) | NOT NULL | 성명 |
| `phone` | VARCHAR(20) | NOT NULL, UNIQUE | 연락처 |
| `station_id` | INT | FK → Station, NULL 허용 | 담당 대여소 (전사 관리자는 NULL 허용) |
| `is_active` | TINYINT(1) | NOT NULL, DEFAULT 1 | 재직 여부 (1=재직, 0=퇴직) |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

> **역할 정의 (애플리케이션 레이어)**
> | 역할 | station_id | 허용 업무 |
> |------|-----------|----------|
> | 관리자 | NULL | 신고 배정, 회수 요원 배정, 외주 정비 조율, 시스템 전반 관리, 배치 승인 |
> | 운영요원 | 지정 | Retrieve 처리, Allocation 실행, 외주 정비 의뢰(Maintenance INSERT) |
>
> ※ 자전거 정비는 외부 업체(외주)에 위탁하므로 내부 `정비사` 역할이 없다. `AdminStaff`는 정비를 직접 수행하지 않으며, `Maintenance` 테이블에 `staff_id` 컬럼이 없다.

---

## 7. Rental (대여 이력)

**설명**: 사용자가 자전거를 대여하고 반납하는 전 과정을 기록하는 핵심 트랜잭션 테이블. `end_station_id`는 반납 완료 후 채워지며, 대여중에는 NULL이다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `rental_id` | INT | PK, AUTO_INCREMENT | 대여 ID |
| `user_id` | INT | FK → User, NOT NULL | 이용 사용자 |
| `bicycle_id` | INT | FK → Bicycle, NOT NULL | 대여 자전거 |
| `start_station_id` | INT | FK → Station, NOT NULL | 대여 시작 대여소 |
| `end_station_id` | INT | FK → Station, NULL 허용 | 반납 대여소 (대여중 NULL) |
| `rental_date` | DATE | NOT NULL | 대여 날짜 (날짜 기반 집계 쿼리 인덱스 최적화용) |
| `start_time` | DATETIME | NOT NULL | 대여 시작 일시 |
| `end_time` | DATETIME | NULL 허용 | 반납 일시 |
| `duration_min` | INT | NULL 허용 | 이용 시간(분) |
| `distance_km` | DECIMAL(7,3) | NULL 허용 | 이용 거리(km) |
| `rental_status` | ENUM | NOT NULL, DEFAULT '대여중' | 대여중 / 반납 / 미반납 |

> **의도적 비정규화**: `rental_date`는 `start_time`에서 도출 가능하나, 날짜 기반 집계 쿼리(`GROUP BY rental_date`) 성능을 위해 분리 저장한다.

---

## 8. IncidentReport (고장/민원 신고)

**설명**: 자전거 고장, 방치, 분실, 기타 민원 신고를 관리한다. `user_id = NULL`은 관리자가 직접 접수한 신고를 의미한다. 신고 유형에 따라 Maintenance 또는 Retrieve로 연계된다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `incident_id` | INT | PK, AUTO_INCREMENT | 신고 ID |
| `user_id` | INT | FK → User, NULL 허용 | 신고자 (NULL = 관리자 직접 접수) |
| `bicycle_id` | INT | FK → Bicycle, NOT NULL | 신고 대상 자전거 |
| `incident_type` | ENUM | NOT NULL | 고장 / 방치 / 분실 / 기타 |
| `description` | TEXT | NULL 허용 | 신고 내용 |
| `reported_at` | DATETIME | NOT NULL, DEFAULT NOW() | 신고 일시 |
| `incident_status` | ENUM | NOT NULL, DEFAULT '접수' | 접수 / 처리중 / 완료 |
| `assigned_staff_id` | INT | FK → AdminStaff, NULL 허용 | 담당 관리자 (미배정 시 NULL) |
| `resolved_at` | DATETIME | NULL 허용 | 처리 완료 일시 |

---

## 9. Maintenance (정비 외주 의뢰 이력)

**설명**: 자전거 정비를 외부 업체(외주)에 위탁한 사실과 결과를 기록하는 테이블. 외주 업체의 작업자나 정비 방법은 관리하지 않으므로 내부 관리자(AdminStaff) 참조가 없다. `incident_id = NULL`은 신고 없이 정기적으로 의뢰하는 점검을 의미한다. 정비 완료(자전거 반납) 시 트리거(`trg_maintenance_complete`)가 자전거 상태 및 위치를 자동 복구한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `maintenance_id` | INT | PK, AUTO_INCREMENT | 정비 ID |
| `bicycle_id` | INT | FK → Bicycle, NOT NULL | 정비 자전거 |
| `incident_id` | INT | FK → IncidentReport, NULL 허용 | 연계 신고 (정기점검 의뢰 시 NULL) |
| `maintenance_type` | ENUM | NOT NULL | 정기점검 / 수리 / 청소 |
| `description` | TEXT | NULL 허용 | 정비 의뢰 내용 |
| `return_station_id` | INT | FK → Station, NULL 허용 | 외주 정비 완료 후 자전거 반납 대여소 (의뢰 시 지정, 완료 시 확정) |
| `started_at` | DATETIME | NOT NULL | 정비 의뢰 일시 |
| `ended_at` | DATETIME | NULL 허용 | 정비 완료(자전거 반납) 일시 |
| `maintenance_status` | ENUM | NOT NULL, DEFAULT '진행중' | 진행중 / 완료 |

> **외주 정비 원칙**: 정비 수행 주체는 외부 업체이므로 `staff_id` 컬럼이 없다. 외주 의뢰 처리를 담당하는 내부 직원 정보가 필요한 경우 연계 `IncidentReport.assigned_staff_id`를 통해 추적할 수 있다.
>
> **3NF 분리 근거**: 신고(IncidentReport) 내에 정비 정보를 포함하면 신고 없는 정기점검을 표현할 수 없고 이행 종속이 발생하므로 독립 엔터티로 분리하였다.

---

## 10. Retrieve (자전거 회수 이력)

**설명**: 구역 이탈, 방치, 미반납 등으로 발생한 자전거 회수 작업 기록. `staff_id = NULL`은 GPS 자동 감지로 생성된 회수 건(이후 관리자가 배정)을 의미한다. 회수 완료 시 트리거(`trg_retrieve_complete`)가 자전거 상태 및 위치를 자동 복구한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `retrieve_id` | INT | PK, AUTO_INCREMENT | 회수 ID |
| `bicycle_id` | INT | FK → Bicycle, NOT NULL | 회수 자전거 |
| `staff_id` | INT | FK → AdminStaff, NULL 허용 | 담당 회수 요원 (자동 생성 시 NULL, 이후 배정) |
| `incident_id` | INT | FK → IncidentReport, NULL 허용 | 연계 신고 (자동 감지 시 NULL) |
| `retrieve_latitude` | DECIMAL(10,7) | NULL 허용 | 발견 위치 위도 |
| `retrieve_longitude` | DECIMAL(10,7) | NULL 허용 | 발견 위치 경도 |
| `retrieve_location` | VARCHAR(255) | NOT NULL | 발견 주소 |
| `target_station_id` | INT | FK → Station, NOT NULL | 반납 목표 대여소 |
| `retrieved_at` | DATETIME | NOT NULL, DEFAULT NOW() | 회수 시작 일시 |
| `completed_at` | DATETIME | NULL 허용 | 반납 완료 일시 |
| `retrieve_reason` | ENUM | NOT NULL | 방치 / 미반납 / 구역이탈 / 기타 |
| `retrieve_status` | ENUM | NOT NULL, DEFAULT '진행중' | 진행중 / 완료 |

---

## 11. Penalty (패널티)

**설명**: 자전거 미반납 시 발생하는 대여 금지 패널티 이력. `rental_id`에 UNIQUE 제약을 적용하여 미반납 1건당 패널티 1건만 생성된다. 패널티 만료(`ban_end < CURRENT_DATE`) 시 `User.user_status → '정상'`으로 자동 복구(배치 처리)된다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `penalty_id` | INT | PK, AUTO_INCREMENT | 패널티 ID |
| `user_id` | INT | FK → User, NOT NULL | 대상 사용자 |
| `rental_id` | INT | FK → Rental, NOT NULL, UNIQUE | 미반납 대여 건 (건당 1개) |
| `penalty_days` | INT | NOT NULL | 대여 금지 일수 (경과일수 × 10) |
| `ban_start` | DATE | NOT NULL | 금지 시작일 |
| `ban_end` | DATE | NULL 허용 | 금지 종료일 (NULL = 영구 금지) |
| `created_at` | DATETIME | NOT NULL, DEFAULT NOW() | 등록일시 |

> **패널티 계산 규칙**: `n = DATEDIFF(감지일, rental_date)`, `penalty_days = n × 10`, `ban_end = ban_start + penalty_days일`  
> 동일 사용자에게 복수의 활성 패널티가 존재하는 경우, 가장 늦은 `ban_end`를 기준으로 이용 제한을 적용한다.

> **3NF 분리 근거**: `Rental` 또는 `User` 내에 패널티 정보를 포함하면 이행 종속이 발생하고 패널티 이력 관리가 불가능하므로 독립 엔터티로 분리하였다.

---

## 12. Allocation (자전거 배치 이력)

**설명**: 관리자의 자전거 배치 의사결정 이력. `station_id = NULL`은 대여소 미확정 상태에서 지역만 지정한 배치를 의미하며, 이후 대여소가 확정되면 `station_id`를 업데이트한다.

| 속성명 | 데이터 타입 | 제약 조건 | 설명 |
|--------|------------|----------|------|
| `allocation_id` | INT | PK, AUTO_INCREMENT | 배치 ID |
| `bicycle_id` | INT | FK → Bicycle, NOT NULL | 배치 자전거 |
| `region_id` | INT | FK → Region, NOT NULL | 배치 지역 |
| `station_id` | INT | FK → Station, NULL 허용 | 배치 대여소 (미정 시 NULL, 확정 시 업데이트) |
| `allocated_by` | INT | FK → AdminStaff, NOT NULL | 배치 담당자 |
| `allocated_at` | DATETIME | NOT NULL, DEFAULT NOW() | 배치 일시 |
| `note` | TEXT | NULL 허용 | 비고 |

> **의도적 비정규화**: `region_id`는 `Station.region_id`에서 도출 가능하나, `station_id = NULL`(지역만 지정) 케이스를 지원하기 위해 별도로 저장한다.

---

## 정규화 요약

| 정규형 | 적용 내용 |
|--------|----------|
| **1NF** | 모든 속성 원자값 유지, 반복 그룹 없음 |
| **2NF** | 모든 테이블이 단일 AUTO_INCREMENT PK 사용 → 부분 함수 종속 없음 |
| **3NF** | 이행적 함수 종속 제거 (Region, BicycleType, Penalty, Maintenance 분리, `User.is_minor` 제거) |

### 의도적 비정규화 (성능 최적화)

| 컬럼 | 위치 | 도출 가능 출처 | 비정규화 이유 |
|------|------|--------------|-------------|
| `Rental.rental_date` | Rental | `start_time` | 날짜 기반 집계 쿼리 인덱스 최적화 |
| `Allocation.region_id` | Allocation | `Station.region_id` | `station_id = NULL`(지역만 지정) 케이스 지원 |
