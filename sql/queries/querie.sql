-- ==============================================
-- 핵심 운영 쿼리
-- 목적: 관리자 대시보드 및 운영 모니터링에 자주 사용되는 쿼리 패턴
-- ==============================================

-- [쿼리 1] 대여소별 현재 대여 가능한 자전거 수
--          → 대시보드에서 실시간 재고 현황 표시에 사용
SELECT s.station_name, COUNT(*) AS available_count
FROM Bicycle b
JOIN Station s ON b.current_station_id = s.station_id
WHERE b.bike_status = 'AVAILABLE'
GROUP BY s.station_id, s.station_name;

-- [쿼리 2] 미처리(OPEN) 신고 목록 (최신 접수 순)
--          → 운영자가 우선 처리해야 할 신고를 확인할 때 사용
SELECT i.incident_id, u.name AS reporter, b.serial_no, i.incident_type, i.reported_at
FROM IncidentReport i
JOIN User u ON i.reporter_user_id = u.user_id
LEFT JOIN Bicycle b ON i.bicycle_id = b.bicycle_id
WHERE i.incident_status = 'OPEN'
ORDER BY i.reported_at DESC;

-- [쿼리 3] 현재 연체 중인 대여 목록 (오래된 순)
--          → 연체 자전거를 파악하고 이용자에게 알림 발송 시 사용
SELECT r.rental_id, u.name, u.phone, b.serial_no,
       TIMESTAMPDIFF(MINUTE, r.start_time, NOW()) AS elapsed_minutes
FROM Rental r
JOIN User u ON r.user_id = u.user_id
JOIN Bicycle b ON r.bicycle_id = b.bicycle_id
WHERE r.rental_status = 'OVERDUE'
ORDER BY r.start_time ASC;

-- [쿼리 4] 자전거별 누적 수익 상위 10대
--          → 고수익 자전거 파악 및 정비 우선순위 산정에 활용
SELECT b.serial_no, SUM(p.amount) AS total_revenue
FROM Payment p
JOIN Rental r ON p.rental_id = r.rental_id
JOIN Bicycle b ON r.bicycle_id = b.bicycle_id
WHERE p.payment_status = 'SUCCESS'
GROUP BY b.bicycle_id, b.serial_no
ORDER BY total_revenue DESC
LIMIT 10;

-- [쿼리 5] 동별 월간 대여 건수 통계
--          → 지역별 수요 분석 및 자전거 배치 최적화에 활용
SELECT rg.region_name,
       DATE_FORMAT(r.start_time, '%Y-%m') AS ym,
       COUNT(*) AS rental_count
FROM Rental r
JOIN Station s ON r.start_station_id = s.station_id
JOIN Region rg ON s.region_id = rg.region_id
GROUP BY rg.region_id, ym
ORDER BY rg.region_name, ym;
