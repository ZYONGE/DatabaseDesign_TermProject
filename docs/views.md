# 시흥시 공공 자전거 대여 서비스 — VIEW 명세서

> **DBMS:** MySQL 8.0 / InnoDB / utf8mb4

---

## 2. VIEW 목록 요약

| # | VIEW 이름 | 한글명 | 참조 테이블 | 사용 주체(공개 대상) | 핵심 목적 |
|---|-----------|--------|-------------|----------------------|-----------|
| 1 | `vw_station_bicycle_summary` | 대여소별 자전거 현황 | Station, Region, Bicycle | 관제 담당자 | 대여소별 상태별 자전거 수 집계 → 재배치 판단 |
| 2 | `vw_active_rentals` | 현재 대여중인 자전거 현황 | Rental, User, Bicycle, BicycleType, Station | 관제 담당자 | 실시간 대여 감시, 미반납 위험 조기 경보 |
| 3 | `vw_active_penalties` | 미반납 패널티 대상자 현황 | Penalty, User, Rental | 회원 제재 담당자 | 현재 정지 중 사용자 및 잔여 정지일 조회 |
| 4 | `vw_bicycle_type_summary` | 자전거 종류별 가동 현황 | BicycleType, Bicycle | 정책·예산 담당자 | 종류별 보유 대수 및 가동률(%) 파악 |
| 5 | `vw_pending_incidents` | 미처리 신고 현황 | IncidentReport, User, Bicycle, BicycleType, AdminStaff | 운영자(대시보드) | 미처리 신고 작업 대기열 관리 |
| 6 | `vw_active_retrievals` | 진행중인 회수 현황 | Retrieve, Bicycle, BicycleType, AdminStaff, Station | 현장 회수 요원 | GPS 기반 회수 출동·동선 관리 |
| 7 | `vw_bicycle_maintenance` | 자전거별 정비 이력 | Bicycle, BicycleType, Maintenance | 자산 관리 담당자 | 자전거 생애주기·폐기 교체 판단 |
| 8 | `vw_user_rental_summary` | 사용자 대여 이력 요약 | User, Rental | 회원 관리 담당자 | 사용자별 누적 이용 패턴·상습 미반납 식별 |

> 8개 VIEW는 **모두 운영자·관리자 내부용**

---

## 3. 운영 업무 흐름으로 본 3계층 구조

8개 VIEW는 운영 업무 전체를 세 층위로 덮는다.

```
현황 파악         실시간 감시              이력 분석
(1, 4)     →    (2, 3, 5, 6)      →     (7, 8)
대여소·종류별      대여·패널티·신고·회수     정비·사용자 누적
보유 현황          진행 중 모니터링          행동 분석
```

 **현행 유인 운영(인터뷰 기반)** 과 **전 시 무인 확장(향후 요구)** 반영. 

---

## 4. VIEW 상세 설명

### VIEW 1 — `vw_station_bicycle_summary` (대여소별 자전거 현황)

- **참조 테이블:** Station, Region, Bicycle
- **주요 항목:** 지역명, 대여소명, 대여소 상태, 총 거치대 수, 전체 자전거 수, 상태별 대수(정상/대여중/정비중/회수중/분실)
- **실무 활용:** 관제 담당 주무관이 출근 후 가장 먼저 보는 화면. "정왕역에 정상 자전거가 2대뿐"이라는 재고 부족을 즉시 포착하고, 이 결과가 **재배치(Allocation) 의사결정의 입력값**이 된다.
- **설계 포인트:** `LEFT JOIN Bicycle`을 사용해 자전거가 0대인 신설·일시 공백 대여소도 결과에서 누락되지 않게 한다.

### VIEW 2 — `vw_active_rentals` (현재 대여중인 자전거 현황)

- **참조 테이블:** Rental, User, Bicycle, BicycleType, Station
- **주요 항목:** 대여 ID, 사용자명·전화번호, 자전거 정보, 시작 대여소, 경과 시간(분), 대여 경고 단계
- **실무 활용:** 지금 거리에 나가 있는 모든 자전거를 보여준다. 경과 시간에 따라 **정상 → 장기 이용(12시간) → 미반납 위험(24시간)** 으로 자동 분류하여, '미반납 위험' 건의 사용자에게 **선제적으로 연락**해 분실로 굳어지기 전 회수를 유도한다.
- **설계 포인트:** `WHERE rental_status = '대여중'` 으로 진행 중 건만 필터, `TIMESTAMPDIFF` + `CASE` 로 경고 단계 산출.

### VIEW 3 — `vw_active_penalties` (미반납 패널티 대상자 현황)

- **참조 테이블:** Penalty, User, Rental
- **주요 항목:** 사용자 정보, 패널티 일수, 정지 시작·종료일, 잔여 정지일수, 관련 대여 건
- **실무 활용:** 대여 요청 시 **자격 검증**(지금 빌릴 수 있는가)과 **민원 응대**(정지 사유·해제일 안내)에 사용한다.
- **설계 포인트:** `ban_start <= CURDATE() AND (ban_end IS NULL OR ban_end >= CURDATE())` 로 현재 활성 패널티만 노출. 이미 해제된 사용자는 자동으로 목록에서 빠진다.

### VIEW 4 — `vw_bicycle_type_summary` (자전거 종류별 가동 현황)

- **참조 테이블:** BicycleType, Bicycle
- **주요 항목:** 종류명, 최대 탑승 인원, 점검 주기, 전체 대수, 상태별 대수, 가동률(%)
- **실무 활용:** 일선 운영보다 한 단계 위인 **정책·예산 의사결정용**. 2인용 가동률이 꾸준히 90%를 넘으면 추가 구매 근거가 되고, 어린이형이 20%대면 배치 축소·이전을 검토한다.
- **설계 포인트:** `ROUND(대여중 수 / NULLIF(전체 수, 0) * 100, 1)` — `NULLIF` 로 0으로 나누기 오류를 방지해, 신규 종류 도입 직후 데이터가 비어도 화면이 깨지지 않는다.

### VIEW 5 — `vw_pending_incidents` (미처리 신고 현황)

- **참조 테이블:** IncidentReport, User, Bicycle, BicycleType, AdminStaff
- **주요 항목:** 신고 ID·유형·상태, 신고자, 자전거 정보, 신고 내용, 신고 일시, 경과 시간, 담당자
- **실무 활용:** 미처리(접수·처리중) 신고만 보여주는 **운영팀의 To-Do 리스트**. 경과 시간으로 오래된 신고를 우선 처리하도록 우선순위를 잡는다.
- **설계 포인트:** `COALESCE(user_name, '관리자 직접 접수')` 로 신고자 없는 경우 처리, `LEFT JOIN AdminStaff` 로 담당자 미배정 건도 포함해 "아직 아무도 안 맡은 신고"를 식별한다.

### VIEW 6 — `vw_active_retrievals` (진행중인 회수 현황)

- **참조 테이블:** Retrieve, Bicycle, BicycleType, AdminStaff, Station
- **주요 항목:** 회수 ID·사유·상태, 자전거 정보, 회수 위치(위경도), 회수 일시, 경과 시간, 담당자, 목표 대여소
- **실무 활용:** 현장 회수 요원의 **출동·동선 관리용**. 위경도 좌표를 지도에 찍어 출동하고, 미배정 건을 식별해 배정한다. 전 시 확장 시 늘어날 회수 물량을 대비한, 보고서의 '무인 확장' 기준선을 직접 구현한 VIEW.
- **설계 포인트:** `WHERE retrieve_status = '진행중'` 필터, `COALESCE(staff_name, '미배정')` 로 미배정 건 표시.

### VIEW 7 — `vw_bicycle_maintenance` (자전거별 정비 이력)

- **참조 테이블:** Bicycle, BicycleType, Maintenance
- **주요 항목:** 자전거 ID·종류·상태, 총 정비 횟수, 유형별 횟수(수리/정기점검/청소), 최근 정비 일시
- **실무 활용:** 자전거 한 대의 **건강 기록부**. 수리 횟수가 비정상적으로 많으면 폐차 후보로 분류하고, BicycleType의 점검 주기와 최근 정비일을 비교해 점검 시기가 지난 차량을 가려낸다.
- **설계 포인트:** `LEFT JOIN Maintenance` 로 정비 이력이 없는 자전거도 포함, `MAX(started_at)` 로 최근 정비일 추출.

### VIEW 8 — `vw_user_rental_summary` (사용자 대여 이력 요약)

- **참조 테이블:** User, Rental
- **주요 항목:** 사용자 정보·상태, 총 대여 횟수, 상태별 건수(반납/미반납/대여중), 최근 대여 일시
- **실무 활용:** 사용자를 단위로 **누적 행동 패턴**을 본다. 미반납 누적이 잦으면 상습 미반납자로 분류해 추가 제재 대상으로 삼고, 오래 이용하지 않은 휴면 회원도 식별한다.
- **설계 포인트:** `LEFT JOIN Rental` 로 대여 이력이 없는 사용자도 포함.

---

## 5. 실무 시나리오


| 직무 | 부여 VIEW | 접근 불가 정보 |
|------|-----------|----------------|
| 현장 회수 요원 | `vw_active_retrievals` | 사용자 개인정보, 패널티 이력, 정비 비용 등 |
| 회원 제재 담당자 | `vw_active_penalties`, `vw_user_rental_summary` | 회수 위치, 정비 원본 데이터 등 |
| 관제 담당자 | `vw_station_bicycle_summary`, `vw_active_rentals` | 사용자 누적 이력 전체 등 |
| 자산 관리 담당자 | `vw_bicycle_maintenance` | 사용자 개인정보 등 |
| 정책·예산 담당자 | `vw_bicycle_type_summary` | 개별 사용자·자전거 식별 정보 등 |

**누구에게도 원본 테이블에 대한 직접 접근 권한을 주지 않는다**

---


