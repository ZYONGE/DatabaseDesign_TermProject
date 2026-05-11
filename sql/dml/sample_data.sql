-- ==============================================
-- 샘플 데이터 (Seed Data)
-- 목적: 개발 및 테스트 환경에서 사용하는 초기 데이터
-- ==============================================

-- Region 샘플 데이터
INSERT INTO Region (region_name) VALUES
    ('은행동'),
    ('대야동'),
    ('신천동'),
    ('군자동'),
    ('능곡동');

-- FarePolicy 샘플 데이터
INSERT INTO FarePolicy (policy_name, base_minutes, base_fare, per_minute_fare, mileage_rate, is_active, effective_from)
VALUES ('기본요금제', 30, 1000, 50, 0.05, TRUE, '2025-01-01');
