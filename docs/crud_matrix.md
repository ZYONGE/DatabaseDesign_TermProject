# CRUD 매트릭스

## 시흥시 공공 자전거 대여 서비스

설계 기준: `sql/ddl/DDL.sql`

### 범례

| 기호 | 의미 | SQL |
|------|------|-----|
| **C** | Create (생성) | INSERT |
| **R** | Read (조회) | SELECT |
| **U** | Update (수정) | UPDATE |
| **D** | Delete (삭제) | DELETE |

---

## CRUD 매트릭스

> 열 머리글 약어: **Re**=Region, **BT**=BicycleType, **St**=Station, **Bi**=Bicycle, **Us**=User, **AS**=AdminStaff, **Ra**=Rental, **IR**=IncidentReport, **Ma**=Maintenance, **Rv**=Retrieve, **Pe**=Penalty, **Al**=Allocation

| # | 기능 | Re | BT | St | Bi | Us | AS | Ra | IR | Ma | Rv | Pe | Al |
|---|------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| 1 | 회원 가입 | | | | | **C** | | | | | | | |
| 2 | 회원 정보 조회 | | | | | **R** | | **R** | | | | **R** | |
| 3 | 대여 요청 | | **R** | **R** | **R,U** | **R** | | **C** | | | | **R** | |
| 4 | 반납 처리 | | | | **U** | | | **U** | | | | | |
| 5 | 미반납 패널티 생성 (배치) | | | | | **U** | | **R,U** | | | | **C** | |
| 6 | 패널티 만료 해제 (배치) | | | | | **U** | | | | | | **R** | |
| 7 | 신고 접수 | | | | **U** | **R** | | | **C** | | | | |
| 8 | 고장 신고 → 정비 외주 의뢰 | | | | **U** | | **R** | | **U** | **C** | | | |
| 9 | 외주 정비 완료 | | | | **U** | | | | **U** | **U** | | | |
| 10 | 방치 신고 → 회수 연계 | | | **R** | **U** | | **R** | | **U** | | **C** | | |
| 11 | 구역 이탈 회수 생성 (자동) | | | **R** | **U** | | | | | | **C** | | |
| 12 | 회수 완료 | | | | **U** | | | | **U** | | **U** | | |
| 13 | 자전거 배치 | | | **R** | **U** | | **R** | | | | | | **C** |
| 14 | 대여소 등록 | **R** | | **C** | | | | | | | | | |
| 15 | 대여소 현황 수정 | | | **U** | | | | | | | | | |
| 16 | 자전거 등록 | | **R** | | **C** | | | | | | | | |
| 17 | 관리자 등록 | | | **R** | | | **C** | | | | | | |
| 18 | 대여 이력 조회 | **R** | **R** | **R** | **R** | **R** | | **R** | | | | | |
| 19 | 신고 현황 조회 | | | | **R** | **R** | **R** | | **R** | | | | |
| 20 | 정비 현황 조회 | | | | **R** | | **R** | | **R** | **R** | | | |
| 21 | 회수 현황 조회 | | | **R** | **R** | | **R** | | | | **R** | | |
| 22 | 패널티 현황 조회 | | | | | **R** | | **R** | | | | **R** | |
| 23 | 배치 이력 조회 | | | **R** | **R** | | **R** | | | | | | **R** |

---

## 기능별 상세 설명

### 1. 회원 가입
- `User` C: 새 사용자 레코드 INSERT

### 2. 회원 정보 조회
- `User` R: 기본 정보 조회
- `Rental` R: 대여 이력 조회
- `Penalty` R: 활성 패널티 및 이력 조회

### 3. 대여 요청 (design.md 7.1~7.2)
- `BicycleType` R: 어린이 자전거 연령 제한 확인 (`bicycleType_name = '어린이'`, 만 13세 미만 여부)
- `Station` R: 대여소 운영 상태(`운영중`) 확인
- `Bicycle` R,U: `bicycle_status = '정상'` 확인 후 `대여중`으로 변경, `bicycle_station_id → NULL`, GPS 갱신 시작
- `User` R: 계정 상태(`user_status`), 생년월일(`user_birth_date`), 현재 대여 여부 확인
- `Rental` C: 새 대여 레코드 INSERT (`rental_status = '대여중'`)
- `Penalty` R: 활성 패널티 존재 여부 확인 (`penalty_ban_start ≤ CURDATE AND penalty_ban_end ≥ CURDATE`)

### 4. 반납 처리 (design.md 7.3)
- `Bicycle` U: `bicycle_status → '정상'`, `bicycle_station_id → 반납 대여소`, GPS 컬럼 NULL 초기화
- `Rental` U: `return_station_id`, `rental_end_time`, `rental_status → '반납'` 업데이트

### 5. 미반납 패널티 생성 — 매일 자정 배치 (design.md 7.4)
- `Rental` R,U: `대여중` + 24시간 초과 건 조회 후 `rental_status → '미반납'` 업데이트
- `User` U: `user_status → '정지'`
- `Penalty` C: `penalty_days = 경과일수 × 10`, `penalty_ban_start`, `penalty_ban_end` 계산 후 INSERT

### 6. 패널티 만료 해제 — 매일 자정 배치 (design.md 7.4)
- `Penalty` R: `ban_end < CURRENT_DATE`인 활성 패널티 조회
- `User` U: 해당 사용자 `user_status → '정상'` 복구

### 7. 신고 접수 (design.md 7.5)
- `User` R: 신고자 정보 확인 (NULL이면 관리자 직접 접수)
- `Bicycle` U: 신고 유형에 따라 상태 변경 (분실 신고 시 `bicycle_status → '분실'`)
- `IncidentReport` C: 신고 레코드 INSERT

### 8. 고장 신고 → 정비 외주 의뢰 (design.md 7.5)
- `AdminStaff` R: 외주 정비 조율 담당자 조회 및 IncidentReport 배정
- `Bicycle` U: `bicycle_status → '정비중'`, `bicycle_station_id → NULL`
- `IncidentReport` U: `incident_status → '처리중'`, `incident_staff_id` 배정
- `Maintenance` C: 외주 정비 의뢰 레코드 INSERT (`maintenance_incident_id` 포함)

### 9. 외주 정비 완료 (design.md 7.5)
- `Bicycle` U: `bicycle_status → '정상'`
- `IncidentReport` U: `incident_status → '완료'`, `incident_resolved_at = NOW()`
- `Maintenance` U: `maintenance_ended_at = NOW()`, `maintenance_status → '완료'`

### 10. 방치 신고 → 회수 연계 (design.md 7.5)
- `Station` R: 반납 목표 대여소 선정
- `Bicycle` U: `bicycle_status → '회수중'`
- `AdminStaff` R: 회수 요원 조회 및 배정
- `IncidentReport` U: `incident_status → '처리중'`, `incident_staff_id` 배정
- `Retrieve` C: 회수 레코드 INSERT (`retrieve_incident_id`, `retrieve_reason = '방치'`)

### 11. 구역 이탈 회수 생성 — GPS 자동 감지 (design.md 7.6)
- `Station` R: 반납 목표 대여소 선정
- `Bicycle` U: `bicycle_status → '회수중'`
- `Retrieve` C: 회수 레코드 INSERT (`retrieve_staff_id = NULL`, `retrieve_incident_id = NULL`, `retrieve_reason = '구역이탈'`)

### 12. 회수 완료 (design.md 7.6)
- `Bicycle` U: `bicycle_status → '정상'`, `bicycle_station_id → Retrieve.retrieve_station_id`, GPS NULL 초기화
- `IncidentReport` U: `incident_status → '완료'` (연계 신고가 있는 경우)
- `Retrieve` U: `retrieve_completed_at = NOW()`, `retrieve_status → '완료'`

### 13. 자전거 배치 (design.md 7.7)
- `Station` R: 배치 대여소 확인
- `Bicycle` U: `allocation_station_id` 확정 시 `bicycle_station_id → Allocation.allocation_station_id`, `bicycle_status → '정상'`
- `AdminStaff` R: 배치 담당자 확인
- `Allocation` C: 배치 이력 INSERT

### 14. 대여소 등록
- `Region` R: 소속 지역 확인
- `Station` C: 새 대여소 INSERT

### 15. 대여소 현황 수정
- `Station` U: `station_status`, `station_totaldocks` 등 현황 업데이트

### 16. 자전거 등록
- `BicycleType` R: 자전거 종류 확인
- `Bicycle` C: 새 자전거 INSERT

### 17. 관리자 등록
- `Station` R: 담당 대여소 확인
- `AdminStaff` C: 새 관리자 INSERT

---

## 엔터티별 CRUD 빈도 요약

| 엔터티 | C | R | U | D | 합계 | 비고 |
|--------|---|---|---|---|------|------|
| Region | 1 | 5 | 0 | 0 | 6 | 거의 변경 없는 참조 데이터 |
| BicycleType | 0 | 4 | 0 | 0 | 4 | 거의 변경 없는 참조 데이터 |
| Station | 1 | 9 | 1 | 0 | 11 | 등록·현황 수정 발생 |
| Bicycle | 1 | 6 | 9 | 0 | 16 | 상태 변경이 가장 빈번 |
| User | 1 | 7 | 2 | 0 | 10 | 가입·상태 변경 |
| AdminStaff | 1 | 5 | 0 | 0 | 6 | 등록 위주 |
| Rental | 1 | 5 | 3 | 0 | 9 | 핵심 트랜잭션 |
| IncidentReport | 1 | 4 | 5 | 0 | 10 | 상태 전이가 빈번 |
| Maintenance | 1 | 3 | 2 | 0 | 6 | 외주 의뢰·완료 기록 |
| Retrieve | 1 | 4 | 2 | 0 | 7 | 회수 시작·완료 |
| Penalty | 1 | 5 | 0 | 0 | 6 | 생성 후 변경 없음 |
| Allocation | 1 | 3 | 0 | 0 | 4 | 배치 이력 추가 위주 |
