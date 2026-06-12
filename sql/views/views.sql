-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 VIEW (속성명 전역 유일 적용)
-- DBMS : MySQL 8.0 / InnoDB / utf8mb4
-- 뷰 명명 규칙 : 테이블과 동일하게 PascalCase, 역할이 드러나는 이름 사용
-- ==============================================

USE siheung_bicycle1;

-- -----------------------------------------------
-- [VIEW 1] StationBicycleStatus (대여소별 자전거 현황)
-- 대여소마다 소속 지역, 거치대 수, 상태별 자전거 보유 대수를 집계
-- -----------------------------------------------
CREATE OR REPLACE VIEW StationBicycleStatus AS
SELECT
    rg.region_name,
    s.station_id,
    s.station_name,
    s.station_status,
    s.station_totaldocks,
    COUNT(b.bicycle_id)                                                        AS total_bicycles,
    SUM(CASE WHEN b.bicycle_status = '정상'   THEN 1 ELSE 0 END)              AS available,
    SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)              AS in_use,
    SUM(CASE WHEN b.bicycle_status = '정비중' THEN 1 ELSE 0 END)              AS in_maintenance,
    SUM(CASE WHEN b.bicycle_status = '회수중' THEN 1 ELSE 0 END)              AS retrieving,
    SUM(CASE WHEN b.bicycle_status = '분실'   THEN 1 ELSE 0 END)              AS lost
FROM Station s
JOIN Region rg ON s.station_region_id = rg.region_id
LEFT JOIN Bicycle b ON b.bicycle_station_id = s.station_id
GROUP BY rg.region_name, s.station_id, s.station_name, s.station_status, s.station_totaldocks;


-- -----------------------------------------------
-- [VIEW 2] CurrentRentalStatus (현재 대여중 현황)
-- 대여중인 건의 사용자·자전거·시작 대여소와 경과 시간, 미반납 위험 경고 표시
-- -----------------------------------------------
CREATE OR REPLACE VIEW CurrentRentalStatus AS
SELECT
    r.rental_id,
    u.user_id,
    u.user_name,
    u.user_phone,
    b.bicycle_id,
    bt.bicycleType_name                                         AS bike_type,
    ss.station_name                                             AS start_station,
    r.rental_start_time,
    TIMESTAMPDIFF(MINUTE, r.rental_start_time, NOW())          AS elapsed_minutes,
    CASE
        WHEN TIMESTAMPDIFF(HOUR, r.rental_start_time, NOW()) >= 24 THEN '미반납 위험'
        WHEN TIMESTAMPDIFF(HOUR, r.rental_start_time, NOW()) >= 12 THEN '장기 이용'
        ELSE '정상'
    END                                                         AS rental_warning
FROM Rental r
JOIN User        u  ON r.rental_user_id    = u.user_id
JOIN Bicycle     b  ON r.rental_bicycle_id = b.bicycle_id
JOIN BicycleType bt ON b.bicycleType_id    = bt.bicycleType_id
JOIN Station     ss ON r.start_station_id  = ss.station_id
WHERE r.rental_status = '대여중';


-- -----------------------------------------------
-- [VIEW 3] ActivePenaltyUser (패널티 적용중 사용자)
-- 현재 대여 금지 기간 중인 사용자와 남은 금지 일수, 원인 대여 건 조회
-- -----------------------------------------------
CREATE OR REPLACE VIEW ActivePenaltyUser AS
SELECT
    u.user_id,
    u.user_name,
    u.user_phone,
    u.user_status,
    p.penalty_id,
    p.penalty_days,
    p.penalty_ban_start,
    p.penalty_ban_end,
    DATEDIFF(p.penalty_ban_end, CURDATE())                     AS days_remaining,
    r.rental_id                                                AS related_rental
FROM Penalty p
JOIN User   u ON p.penalty_user_id   = u.user_id
JOIN Rental r ON p.penalty_rental_id = r.rental_id
WHERE p.penalty_ban_start <= CURDATE()
  AND (p.penalty_ban_end IS NULL OR p.penalty_ban_end >= CURDATE());


-- -----------------------------------------------
-- [VIEW 4] BicycleTypeUtilization (자전거 종류별 가동 현황)
-- 종류별 전체 대수, 상태별 대수, 가동률(%) 집계
-- -----------------------------------------------
CREATE OR REPLACE VIEW BicycleTypeUtilization AS
SELECT
    bt.bicycleType_id,
    bt.bicycleType_name,
    bt.max_passenger,
    bt.inspection_cycle,
    COUNT(b.bicycle_id)                                                        AS total_count,
    SUM(CASE WHEN b.bicycle_status = '정상'   THEN 1 ELSE 0 END)              AS available,
    SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)              AS in_use,
    SUM(CASE WHEN b.bicycle_status = '정비중' THEN 1 ELSE 0 END)              AS in_maintenance,
    SUM(CASE WHEN b.bicycle_status = '회수중' THEN 1 ELSE 0 END)              AS retrieving,
    SUM(CASE WHEN b.bicycle_status = '분실'   THEN 1 ELSE 0 END)              AS lost,
    ROUND(
        SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(b.bicycle_id), 0) * 100, 1
    )                                                                           AS utilization_pct
FROM BicycleType bt
LEFT JOIN Bicycle b ON bt.bicycleType_id = b.bicycleType_id
GROUP BY bt.bicycleType_id, bt.bicycleType_name, bt.max_passenger, bt.inspection_cycle;


-- -----------------------------------------------
-- [VIEW 5] UnresolvedIncident (미처리 신고 현황)
-- 접수·처리중 상태인 고장/민원 신고와 경과 시간, 담당 관리자 조회
-- -----------------------------------------------
CREATE OR REPLACE VIEW UnresolvedIncident AS
SELECT
    i.incident_id,
    i.incident_type,
    i.incident_status,
    COALESCE(u.user_name, '관리자 직접 접수')                  AS reporter,
    b.bicycle_id,
    bt.bicycleType_name                                         AS bike_type,
    i.incident_description,
    i.incident_reported_at,
    TIMESTAMPDIFF(HOUR, i.incident_reported_at, NOW())         AS hours_pending,
    a.staff_name                                                AS assigned_staff
FROM IncidentReport i
LEFT JOIN User        u  ON i.incident_user_id    = u.user_id
JOIN      Bicycle     b  ON i.incident_bicycle_id = b.bicycle_id
JOIN      BicycleType bt ON b.bicycleType_id      = bt.bicycleType_id
LEFT JOIN AdminStaff  a  ON i.incident_staff_id   = a.staff_id
WHERE i.incident_status IN ('접수', '처리중');


-- -----------------------------------------------
-- [VIEW 6] OngoingRetrieve (진행중인 회수 현황)
-- 회수 진행중인 자전거의 발견 위치(GPS·주소), 담당 요원, 목표 대여소 조회
-- -----------------------------------------------
CREATE OR REPLACE VIEW OngoingRetrieve AS
SELECT
    rv.retrieve_id,
    rv.retrieve_reason,
    rv.retrieve_status,
    b.bicycle_id,
    bt.bicycleType_name                                         AS bike_type,
    rv.retrieve_location,
    rv.retrieve_latitude,
    rv.retrieve_longitude,
    rv.retrieved_at,
    TIMESTAMPDIFF(HOUR, rv.retrieved_at, NOW())                AS hours_elapsed,
    COALESCE(a.staff_name, '미배정')                           AS assigned_staff,
    ts.station_name                                             AS target_station
FROM Retrieve rv
JOIN  Bicycle      b  ON rv.retrieve_bicycle_id = b.bicycle_id
JOIN  BicycleType  bt ON b.bicycleType_id       = bt.bicycleType_id
LEFT JOIN AdminStaff a ON rv.retrieve_staff_id  = a.staff_id
JOIN  Station      ts ON rv.retrieve_station_id = ts.station_id
WHERE rv.retrieve_status = '진행중';


-- -----------------------------------------------
-- [VIEW 7] BicycleMaintenanceHistory (자전거별 정비 이력 요약)
-- 자전거마다 정비 횟수를 유형별로 집계하고 최근 정비일 표시
-- -----------------------------------------------
CREATE OR REPLACE VIEW BicycleMaintenanceHistory AS
SELECT
    b.bicycle_id,
    bt.bicycleType_name,
    b.bicycle_status,
    COUNT(m.maintenance_id)                                     AS total_maintenance_count,
    SUM(CASE WHEN m.maintenance_type = '수리'     THEN 1 ELSE 0 END) AS repair_count,
    SUM(CASE WHEN m.maintenance_type = '정기점검' THEN 1 ELSE 0 END) AS inspection_count,
    SUM(CASE WHEN m.maintenance_type = '청소'     THEN 1 ELSE 0 END) AS clean_count,
    MAX(m.maintenance_started_at)                               AS last_maintenance_at
FROM Bicycle b
JOIN BicycleType bt ON b.bicycleType_id = bt.bicycleType_id
LEFT JOIN Maintenance m ON b.bicycle_id = m.maintenance_bicycle_id
GROUP BY b.bicycle_id, bt.bicycleType_name, b.bicycle_status;


-- -----------------------------------------------
-- [VIEW 8] UserRentalSummary (사용자별 대여 이력 요약)
-- 사용자마다 총 대여 횟수, 반납/미반납/대여중 건수, 마지막 대여일 집계
-- -----------------------------------------------
CREATE OR REPLACE VIEW UserRentalSummary AS
SELECT
    u.user_id,
    u.user_name,
    u.user_phone,
    u.user_status,
    COUNT(r.rental_id)                                                         AS total_rentals,
    SUM(CASE WHEN r.rental_status = '반납'   THEN 1 ELSE 0 END)               AS returned_count,
    SUM(CASE WHEN r.rental_status = '미반납' THEN 1 ELSE 0 END)               AS unreturned_count,
    SUM(CASE WHEN r.rental_status = '대여중' THEN 1 ELSE 0 END)               AS active_count,
    MAX(r.rental_start_time)                                                   AS last_rental_at
FROM User u
LEFT JOIN Rental r ON u.user_id = r.rental_user_id
GROUP BY u.user_id, u.user_name, u.user_phone, u.user_status;


-- ==============================================
-- 뷰 생성 확인용 조회
-- ==============================================
SELECT * FROM StationBicycleStatus;
SELECT * FROM CurrentRentalStatus;
SELECT * FROM ActivePenaltyUser;
SELECT * FROM BicycleTypeUtilization;
SELECT * FROM UnresolvedIncident;
SELECT * FROM OngoingRetrieve;
SELECT * FROM BicycleMaintenanceHistory;
SELECT * FROM UserRentalSummary;