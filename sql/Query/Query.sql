-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 운영 쿼리 (DDL 기준 수정본)
-- 설계 기준 : docs/design.md
-- ==============================================

-- --------------------------------------------------
-- [쿼리 1] 대여소별 이용 가능 자전거 현황 (종류별 집계)
-- [수정] bt.type_name → bt.bicycleType_name
--        b.bike_status → b.bicycle_status
--        b.current_station_id → b.station_id
-- --------------------------------------------------
SELECT
    rg.region_name,
    s.station_name,
    COUNT(b.bicycle_id)                                                          AS total_available,
    SUM(CASE WHEN bt.bicycleType_name = '일반'   THEN 1 ELSE 0 END)             AS normal_count,
    SUM(CASE WHEN bt.bicycleType_name = '어린이' THEN 1 ELSE 0 END)             AS child_count,
    SUM(CASE WHEN bt.bicycleType_name = '2인용'  THEN 1 ELSE 0 END)             AS tandem_count
FROM Station s
JOIN Region rg ON s.region_id = rg.region_id
LEFT JOIN Bicycle b  ON b.station_id = s.station_id
                     AND b.bicycle_status = '정상'
LEFT JOIN BicycleType bt ON b.type_id = bt.bicycleType_id
WHERE s.station_status = '운영중'
GROUP BY s.station_id, rg.region_name, s.station_name
ORDER BY rg.region_name, s.station_name;


-- --------------------------------------------------
-- [쿼리 2] 현재 대여중인 자전거 목록 (경과 시간 포함)
-- [수정] u.name → u.user_name
--        u.phone → u.user_phone
--        bt.type_name → bt.bicycleType_name
--        r.rental_status = '대여중' (유지)
-- --------------------------------------------------
SELECT
    r.rental_id,
    u.user_name                                                  AS user_name,
    u.user_phone,
    bt.bicycleType_name                                          AS bike_type,
    ss.station_name                                              AS start_station,
    r.start_time,
    TIMESTAMPDIFF(MINUTE, r.start_time, NOW())                  AS elapsed_minutes,
    CASE
        WHEN TIMESTAMPDIFF(HOUR, r.start_time, NOW()) >= 24 THEN '미반납 위험'
        WHEN TIMESTAMPDIFF(HOUR, r.start_time, NOW()) >= 12 THEN '장기 이용'
        ELSE '정상'
    END                                                          AS rental_warning
FROM Rental r
JOIN User        u  ON r.user_id          = u.user_id
JOIN Bicycle     b  ON r.bicycle_id       = b.bicycle_id
JOIN BicycleType bt ON b.type_id          = bt.bicycleType_id
JOIN Station     ss ON r.start_station_id = ss.station_id
WHERE r.rental_status = '대여중'
ORDER BY r.start_time ASC;


-- --------------------------------------------------
-- [쿼리 3] 미반납 감지 및 패널티 생성 대상 조회
-- [수정] u.name → u.user_name
--        u.phone → u.user_phone
--        r.rental_date → DATE(r.start_time)  (DDL에 rental_date 없으므로 대체)
-- --------------------------------------------------
SELECT
    r.rental_id,
    u.user_id,
    u.user_name,
    u.user_phone,
    DATE(r.start_time)                                                       AS rental_date,
    r.start_time,
    DATEDIFF(CURDATE(), DATE(r.start_time))                                  AS overdue_days,
    DATEDIFF(CURDATE(), DATE(r.start_time)) * 10                             AS penalty_days,
    CURDATE()                                                                AS ban_start,
    DATE_ADD(CURDATE(),
        INTERVAL DATEDIFF(CURDATE(), DATE(r.start_time)) * 10 DAY)          AS ban_end
FROM Rental r
JOIN User u ON r.user_id = u.user_id
WHERE r.rental_status = '대여중'
  AND TIMESTAMPDIFF(HOUR, r.start_time, NOW()) >= 24
  AND NOT EXISTS (
      SELECT 1 FROM Penalty p WHERE p.rental_id = r.rental_id
  )
ORDER BY r.start_time ASC;


-- --------------------------------------------------
-- [쿼리 4] 특정 사용자·자전거의 대여 가능 여부 확인
-- [수정] u.name → u.user_name
--        u.birth_date → u.user_birth_date
--        bt.type_name → bt.bicycleType_name
--        b.bike_status → b.bicycle_status
-- --------------------------------------------------
SELECT
    u.user_id,
    u.user_name,
    TIMESTAMPDIFF(YEAR, u.user_birth_date, CURDATE())                                   AS age,
    b.bicycle_id,
    bt.bicycleType_name                                                                 AS bike_type,
    -- 조건 1: 계정 상태
    u.user_status                                                                       AS cond1_status,
    -- 조건 2: 현재 대여중 여부 (1인 1대 제한)
    (SELECT COUNT(*)
     FROM Rental r
     WHERE r.user_id = u.user_id AND r.rental_status = '대여중')                       AS cond2_active_rentals,
    -- 조건 3: 활성 패널티
    (SELECT COUNT(*)
     FROM Penalty p
     WHERE p.user_id   = u.user_id
       AND p.ban_start <= CURDATE()
       AND (p.ban_end IS NULL OR p.ban_end >= CURDATE()))                               AS cond3_active_penalties,
    -- 조건 4: 자전거 상태
    b.bicycle_status                                                                    AS cond4_bike_status,
    -- 조건 5: 어린이 자전거 연령 제한
    CASE
        WHEN TIMESTAMPDIFF(YEAR, u.user_birth_date, CURDATE()) < 13
             AND bt.bicycleType_name != '어린이' THEN '불가: 만 13세 미만은 어린이 자전거만 가능'
        WHEN TIMESTAMPDIFF(YEAR, u.user_birth_date, CURDATE()) >= 13
             AND bt.bicycleType_name  = '어린이' THEN '불가: 어린이 자전거는 만 13세 미만 전용'
        ELSE '조건 충족'
    END                                                                                 AS cond5_age_check,
    -- 최종 판정
    CASE
        WHEN u.user_status != '정상'
            THEN '대여 불가: 계정 정지 상태'
        WHEN (SELECT COUNT(*) FROM Rental r WHERE r.user_id = u.user_id AND r.rental_status = '대여중') > 0
            THEN '대여 불가: 이미 대여 중 (1인 1대 제한)'
        WHEN (SELECT COUNT(*) FROM Penalty p WHERE p.user_id = u.user_id AND p.ban_start <= CURDATE() AND (p.ban_end IS NULL OR p.ban_end >= CURDATE())) > 0
            THEN '대여 불가: 패널티 적용 중'
        WHEN b.bicycle_status != '정상'
            THEN CONCAT('대여 불가: 자전거 상태 [', b.bicycle_status, ']')
        WHEN TIMESTAMPDIFF(YEAR, u.user_birth_date, CURDATE()) < 13 AND bt.bicycleType_name != '어린이'
            THEN '대여 불가: 만 13세 미만은 어린이 자전거만 가능'
        WHEN TIMESTAMPDIFF(YEAR, u.user_birth_date, CURDATE()) >= 13 AND bt.bicycleType_name = '어린이'
            THEN '대여 불가: 어린이 자전거는 만 13세 미만 전용'
        ELSE '대여 가능'
    END                                                                                 AS rental_eligibility
FROM User        u
CROSS JOIN Bicycle     b
JOIN   BicycleType bt ON b.type_id = bt.bicycleType_id
WHERE  u.user_id    = 1   -- 확인할 사용자 ID
  AND  b.bicycle_id = 1;  -- 확인할 자전거 ID


-- --------------------------------------------------
-- [쿼리 5] 지역별 월간 대여 통계
-- [수정] r.rental_date → DATE(r.start_time)  (DDL에 rental_date 없으므로 대체)
--        r.duration_min, r.distance_km 제거 (DDL에 없음)
-- --------------------------------------------------
SELECT
    rg.region_name,
    DATE_FORMAT(r.start_time, '%Y-%m')                              AS ym,
    COUNT(*)                                                        AS total_rentals,
    SUM(CASE WHEN r.rental_status = '반납'   THEN 1 ELSE 0 END)    AS returned,
    SUM(CASE WHEN r.rental_status = '미반납' THEN 1 ELSE 0 END)    AS unreturned,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, r.start_time, r.end_time)), 1) AS avg_duration_min
FROM Rental r
JOIN Station s  ON r.start_station_id = s.station_id
JOIN Region  rg ON s.region_id        = rg.region_id
GROUP BY rg.region_id, rg.region_name, ym
ORDER BY rg.region_name, ym;


-- --------------------------------------------------
-- [쿼리 6] 자전거 종류별 현황 (전체 대수·상태별 집계)
-- [수정] bt.type_name → bt.bicycleType_name
--        b.bike_status → b.bicycle_status
--        bt.type_id → bt.bicycleType_id
-- --------------------------------------------------
SELECT
    bt.bicycleType_name,
    bt.max_passenger,
    COUNT(b.bicycle_id)                                                   AS total_count,
    SUM(CASE WHEN b.bicycle_status = '정상'   THEN 1 ELSE 0 END)         AS available,
    SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)         AS in_use,
    SUM(CASE WHEN b.bicycle_status = '정비중' THEN 1 ELSE 0 END)         AS in_maintenance,
    SUM(CASE WHEN b.bicycle_status = '회수중' THEN 1 ELSE 0 END)         AS retrieving,
    SUM(CASE WHEN b.bicycle_status = '분실'   THEN 1 ELSE 0 END)         AS lost,
    ROUND(
        SUM(CASE WHEN b.bicycle_status = '대여중' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(b.bicycle_id), 0) * 100, 1
    )                                                                      AS utilization_pct
FROM BicycleType bt
LEFT JOIN Bicycle b ON bt.bicycleType_id = b.type_id
GROUP BY bt.bicycleType_id, bt.bicycleType_name, bt.max_passenger
ORDER BY bt.bicycleType_id;


-- --------------------------------------------------
-- [쿼리 7] 미처리 신고 목록 (접수·처리중, 최신 접수순)
-- [수정] u.name → u.user_name
--        i.assigned_staff_id → i.staff_id
--        a.staff_name (유지)
--        bt.type_name → bt.bicycleType_name
-- --------------------------------------------------
SELECT
    i.incident_id,
    i.incident_type,
    i.incident_status,
    COALESCE(u.user_name, '관리자 직접 접수')                             AS reporter,
    b.bicycle_id,
    bt.bicycleType_name                                                    AS bike_type,
    i.description,
    i.reported_at,
    TIMESTAMPDIFF(HOUR, i.reported_at, NOW())                             AS hours_pending,
    a.staff_name                                                           AS assigned_staff
FROM IncidentReport i
LEFT JOIN User        u  ON i.user_id    = u.user_id
JOIN      Bicycle     b  ON i.bicycle_id = b.bicycle_id
JOIN      BicycleType bt ON b.type_id    = bt.bicycleType_id
LEFT JOIN AdminStaff  a  ON i.staff_id   = a.staff_id
WHERE i.incident_status IN ('접수', '처리중')
ORDER BY i.reported_at DESC;


-- --------------------------------------------------
-- [쿼리 8] 진행중인 회수 현황
-- [수정] rv.target_station_id → rv.station_id
--        bt.type_name → bt.bicycleType_name
-- --------------------------------------------------
SELECT
    rv.retrieve_id,
    rv.retrieve_reason,
    b.bicycle_id,
    bt.bicycleType_name                                                   AS bike_type,
    rv.retrieve_location,
    rv.retrieve_latitude,
    rv.retrieve_longitude,
    rv.retrieved_at,
    TIMESTAMPDIFF(HOUR, rv.retrieved_at, NOW())                          AS hours_elapsed,
    COALESCE(a.staff_name, '미배정')                                     AS assigned_staff,
    ts.station_name                                                       AS target_station,
    i.incident_type                                                       AS related_incident
FROM Retrieve rv
JOIN  Bicycle      b  ON rv.bicycle_id  = b.bicycle_id
JOIN  BicycleType  bt ON b.type_id      = bt.bicycleType_id
LEFT JOIN AdminStaff a  ON rv.staff_id  = a.staff_id
JOIN  Station      ts ON rv.station_id  = ts.station_id
LEFT JOIN IncidentReport i ON rv.incident_id = i.incident_id
WHERE rv.retrieve_status = '진행중'
ORDER BY rv.retrieved_at ASC;


-- --------------------------------------------------
-- [쿼리 9] 자전거별 정비 이력 현황
-- [수정] bt.type_name → bt.bicycleType_name
--        b.bike_status → b.bicycle_status
--        m.return_station_id 제거 (DDL에 없음)
-- --------------------------------------------------
SELECT
    b.bicycle_id,
    bt.bicycleType_name,
    b.bicycle_status,
    m.maintenance_id,
    m.maintenance_type,
    m.maintenance_status,
    m.started_at,
    m.ended_at,
    COALESCE(i.incident_type, '정기점검 외주 의뢰')                      AS trigger_type,
    COALESCE(i.description,   '-')                                        AS incident_desc
FROM Maintenance m
JOIN  Bicycle      b  ON m.bicycle_id  = b.bicycle_id
JOIN  BicycleType  bt ON b.type_id     = bt.bicycleType_id
LEFT JOIN IncidentReport i ON m.incident_id = i.incident_id
ORDER BY m.started_at DESC;


-- --------------------------------------------------
-- [쿼리 10] 활성 패널티 보유 사용자 목록
-- [수정] u.name → u.user_name
--        u.phone → u.user_phone
-- --------------------------------------------------
SELECT
    u.user_id,
    u.user_name,
    u.user_phone,
    u.user_status,
    p.penalty_id,
    r.rental_id                                                           AS unreturned_rental,
    p.penalty_days,
    p.ban_start,
    p.ban_end,
    DATEDIFF(p.ban_end, CURDATE())                                        AS days_remaining
FROM Penalty p
JOIN User   u ON p.user_id   = u.user_id
JOIN Rental r ON p.rental_id = r.rental_id
WHERE p.ban_start <= CURDATE()
  AND (p.ban_end IS NULL OR p.ban_end >= CURDATE())
ORDER BY p.ban_end ASC;



USE siheung_bicycle1;

SELECT * FROM vw_station_bicycle_summary;
SELECT * FROM vw_active_rentals;
SELECT * FROM vw_active_penalties;
SELECT * FROM vw_bicycle_type_summary;
SELECT * FROM vw_pending_incidents;
SELECT * FROM vw_active_retrievals;
SELECT * FROM vw_bicycle_maintenance;
SELECT * FROM vw_user_rental_summary;