-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 VIEW
-- DBMS : MySQL 8.0 / InnoDB / utf8mb4
-- ==============================================

USE siheung_bicycle1;

-- -----------------------------------------------
-- [VIEW 1] 대여소별 자전거 현황
--          대여소마다 정상/대여중/정비중 자전거 수를 한눈에 확인
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_station_bicycle_summary AS
SELECT
    rg.region_name,
    s.station_id,
    s.station_name,
    s.station_status,
    s.totaldocks,
    COUNT(b.bicycle_id)                                                        AS total_bicycles,
    SUM(CASE WHEN b.bicycle_status = '정상'   THEN 1 ELSE 0 END)              AS available,
    SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)              AS in_use,
    SUM(CASE WHEN b.bicycle_status = '정비중' THEN 1 ELSE 0 END)              AS in_maintenance,
    SUM(CASE WHEN b.bicycle_status = '회수중' THEN 1 ELSE 0 END)              AS retrieving,
    SUM(CASE WHEN b.bicycle_status = '분실'   THEN 1 ELSE 0 END)              AS lost
FROM Station s
JOIN Region rg ON s.region_id = rg.region_id
LEFT JOIN Bicycle b ON b.station_id = s.station_id
GROUP BY rg.region_name, s.station_id, s.station_name, s.station_status, s.totaldocks;


-- -----------------------------------------------
-- [VIEW 2] 현재 대여중인 자전거 현황
--          실시간 대여 모니터링용
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_active_rentals AS
SELECT
    r.rental_id,
    u.user_id,
    u.user_name,
    u.user_phone,
    b.bicycle_id,
    bt.bicycleType_name                                         AS bike_type,
    ss.station_name                                             AS start_station,
    r.start_time,
    TIMESTAMPDIFF(MINUTE, r.start_time, NOW())                 AS elapsed_minutes,
    CASE
        WHEN TIMESTAMPDIFF(HOUR, r.start_time, NOW()) >= 24 THEN '미반납 위험'
        WHEN TIMESTAMPDIFF(HOUR, r.start_time, NOW()) >= 12 THEN '장기 이용'
        ELSE '정상'
    END                                                         AS rental_warning
FROM Rental r
JOIN User        u  ON r.user_id          = u.user_id
JOIN Bicycle     b  ON r.bicycle_id       = b.bicycle_id
JOIN BicycleType bt ON b.type_id          = bt.bicycleType_id
JOIN Station     ss ON r.start_station_id = ss.station_id
WHERE r.rental_status = '대여중';


-- -----------------------------------------------
-- [VIEW 3] 미반납 패널티 대상자 현황
--          패널티 적용 중인 사용자 목록
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_active_penalties AS
SELECT
    u.user_id,
    u.user_name,
    u.user_phone,
    u.user_status,
    p.penalty_id,
    p.penalty_days,
    p.ban_start,
    p.ban_end,
    DATEDIFF(p.ban_end, CURDATE())                             AS days_remaining,
    r.rental_id                                                AS related_rental
FROM Penalty p
JOIN User   u ON p.user_id   = u.user_id
JOIN Rental r ON p.rental_id = r.rental_id
WHERE p.ban_start <= CURDATE()
  AND (p.ban_end IS NULL OR p.ban_end >= CURDATE());


-- -----------------------------------------------
-- [VIEW 4] 자전거 종류별 가동 현황
--          종류별 전체 대수 및 가동률 확인
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_bicycle_type_summary AS
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
LEFT JOIN Bicycle b ON bt.bicycleType_id = b.type_id
GROUP BY bt.bicycleType_id, bt.bicycleType_name, bt.max_passenger, bt.inspection_cycle;


-- -----------------------------------------------
-- [VIEW 5] 미처리 신고 현황
--          접수·처리중 신고 목록 (운영자 대시보드용)
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_pending_incidents AS
SELECT
    i.incident_id,
    i.incident_type,
    i.incident_status,
    COALESCE(u.user_name, '관리자 직접 접수')                  AS reporter,
    b.bicycle_id,
    bt.bicycleType_name                                         AS bike_type,
    i.description,
    i.reported_at,
    TIMESTAMPDIFF(HOUR, i.reported_at, NOW())                  AS hours_pending,
    a.staff_name                                                AS assigned_staff
FROM IncidentReport i
LEFT JOIN User        u  ON i.user_id    = u.user_id
JOIN      Bicycle     b  ON i.bicycle_id = b.bicycle_id
JOIN      BicycleType bt ON b.type_id    = bt.bicycleType_id
LEFT JOIN AdminStaff  a  ON i.staff_id   = a.staff_id
WHERE i.incident_status IN ('접수', '처리중');


-- -----------------------------------------------
-- [VIEW 6] 진행중인 회수 현황
--          회수 요원 배정 및 현장 출동 모니터링
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_active_retrievals AS
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
JOIN  Bicycle      b  ON rv.bicycle_id = b.bicycle_id
JOIN  BicycleType  bt ON b.type_id     = bt.bicycleType_id
LEFT JOIN AdminStaff a ON rv.staff_id  = a.staff_id
JOIN  Station      ts ON rv.station_id = ts.station_id
WHERE rv.retrieve_status = '진행중';


-- -----------------------------------------------
-- [VIEW 7] 자전거별 정비 이력
--          자전거 생애주기 관리 및 잦은 고장 파악
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_bicycle_maintenance AS
SELECT
    b.bicycle_id,
    bt.bicycleType_name,
    b.bicycle_status,
    COUNT(m.maintenance_id)                                     AS total_maintenance_count,
    SUM(CASE WHEN m.maintenance_type = '수리'     THEN 1 ELSE 0 END) AS repair_count,
    SUM(CASE WHEN m.maintenance_type = '정기점검' THEN 1 ELSE 0 END) AS inspection_count,
    SUM(CASE WHEN m.maintenance_type = '청소'     THEN 1 ELSE 0 END) AS clean_count,
    MAX(m.started_at)                                           AS last_maintenance_at
FROM Bicycle b
JOIN BicycleType bt ON b.type_id = bt.bicycleType_id
LEFT JOIN Maintenance m ON b.bicycle_id = m.bicycle_id
GROUP BY b.bicycle_id, bt.bicycleType_name, b.bicycle_status;


-- -----------------------------------------------
-- [VIEW 8] 사용자 대여 이력 요약
--          사용자별 총 대여 횟수 및 미반납 이력 확인
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_user_rental_summary AS
SELECT
    u.user_id,
    u.user_name,
    u.user_phone,
    u.user_status,
    COUNT(r.rental_id)                                                         AS total_rentals,
    SUM(CASE WHEN r.rental_status = '반납'   THEN 1 ELSE 0 END)               AS returned_count,
    SUM(CASE WHEN r.rental_status = '미반납' THEN 1 ELSE 0 END)               AS unreturned_count,
    SUM(CASE WHEN r.rental_status = '대여중' THEN 1 ELSE 0 END)               AS active_count,
    MAX(r.start_time)                                                          AS last_rental_at
FROM User u
LEFT JOIN Rental r ON u.user_id = r.user_id
GROUP BY u.user_id, u.user_name, u.user_phone, u.user_status;
