-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 VIEW (속성명 전역 유일 적용)
-- DBMS : MySQL 8.0 / InnoDB / utf8mb4
-- ==============================================

USE siheung_bicycle1;

-- -----------------------------------------------
-- [VIEW 1] 대여소별 자전거 현황
-- [변경] s.region_id → s.station_region_id
--        s.totaldocks → s.station_totaldocks
--        b.station_id → b.bicycle_station_id
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_station_bicycle_summary AS
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
-- [VIEW 2] 현재 대여중인 자전거 현황
-- [변경] r.user_id → r.rental_user_id
--        r.bicycle_id → r.rental_bicycle_id
--        r.start_time → r.rental_start_time
--        b.type_id → b.bicycleType_id
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
-- [VIEW 3] 미반납 패널티 대상자 현황
-- [변경] p.user_id → p.penalty_user_id
--        p.rental_id → p.penalty_rental_id
--        p.ban_start → p.penalty_ban_start
--        p.ban_end → p.penalty_ban_end
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_active_penalties AS
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
-- [VIEW 4] 자전거 종류별 가동 현황
-- [변경] b.type_id → b.bicycleType_id
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
LEFT JOIN Bicycle b ON bt.bicycleType_id = b.bicycleType_id
GROUP BY bt.bicycleType_id, bt.bicycleType_name, bt.max_passenger, bt.inspection_cycle;


-- -----------------------------------------------
-- [VIEW 5] 미처리 신고 현황
-- [변경] i.user_id → i.incident_user_id
--        i.bicycle_id → i.incident_bicycle_id
--        i.description → i.incident_description
--        i.reported_at → i.incident_reported_at
--        i.staff_id → i.incident_staff_id
--        b.type_id → b.bicycleType_id
-- -----------------------------------------------
CREATE OR REPLACE VIEW vw_pending_incidents AS
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
-- [VIEW 6] 진행중인 회수 현황
-- [변경] rv.bicycle_id → rv.retrieve_bicycle_id
--        rv.staff_id → rv.retrieve_staff_id
--        rv.station_id → rv.retrieve_station_id
--        b.type_id → b.bicycleType_id
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
JOIN  Bicycle      b  ON rv.retrieve_bicycle_id = b.bicycle_id
JOIN  BicycleType  bt ON b.bicycleType_id       = bt.bicycleType_id
LEFT JOIN AdminStaff a ON rv.retrieve_staff_id  = a.staff_id
JOIN  Station      ts ON rv.retrieve_station_id = ts.station_id
WHERE rv.retrieve_status = '진행중';


-- -----------------------------------------------
-- [VIEW 7] 자전거별 정비 이력
-- [변경] m.bicycle_id → m.maintenance_bicycle_id
--        m.started_at → m.maintenance_started_at
--        b.type_id → b.bicycleType_id
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
    MAX(m.maintenance_started_at)                               AS last_maintenance_at
FROM Bicycle b
JOIN BicycleType bt ON b.bicycleType_id = bt.bicycleType_id
LEFT JOIN Maintenance m ON b.bicycle_id = m.maintenance_bicycle_id
GROUP BY b.bicycle_id, bt.bicycleType_name, b.bicycle_status;


-- -----------------------------------------------
-- [VIEW 8] 사용자 대여 이력 요약
-- [변경] r.user_id → r.rental_user_id
--        r.start_time → r.rental_start_time
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
    MAX(r.rental_start_time)                                                   AS last_rental_at
FROM User u
LEFT JOIN Rental r ON u.user_id = r.rental_user_id
GROUP BY u.user_id, u.user_name, u.user_phone, u.user_status;