-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 DDL
-- 작성 기준: MySQL 8.0 / InnoDB / utf8mb4
-- ==============================================
--
-- [DB 전체 구조 요약]
--   지역(Region) → 대여소(Station) → 거치 슬롯(Dock) → 자전거(Bicycle)
--   사용자(User) ↔ 대여(Rental) ↔ 결제(Payment)
--   대여 완료 후 리뷰(Review) 1건, 마일리지 적립(MileageHistory)
--   관리자(AdminStaff) → 신고(IncidentReport) → 정비(Maintenance) / 회수(Retrieve)
-- ==============================================


-- ==============================================
-- [설계 요약] 유니크 인덱스 적용 대상
--   중복을 허용하지 않아야 하는 필드 목록
-- ==============================================
-- User.login_id              -- 로그인 아이디 중복 불가
-- User.phone                 -- 전화번호 중복 불가
-- Bicycle.serial_no          -- 자전거 일련번호 중복 불가
-- Review.rental_id           -- 대여 1건당 리뷰 1개만 허용
-- Dock.(station_id, dock_no) -- 대여소 내 슬롯 번호 유일성
-- Payment.pg_transaction_id  -- PG사 거래 ID 중복 불가
-- AdminStaff.login_id        -- 관리자 로그인 아이디 중복 불가

-- ==============================================
-- [설계 요약] 검색 성능용 인덱스 적용 대상
--   자주 사용되는 조회 패턴에 맞춰 복합 인덱스를 설정
-- ==============================================
-- Rental(user_id, start_time)                  -- 사용자별 대여 이력 조회
-- Rental(bicycle_id, start_time)               -- 자전거별 이용 이력 조회
-- Rental(rental_status, start_time)            -- 미반납(RENTED/OVERDUE) 모니터링
-- Payment(user_id, payment_time)               -- 사용자별 결제 내역
-- Payment(rental_id)                           -- 대여-결제 조인
-- IncidentReport(incident_status, reported_at) -- 미처리 신고 모니터링
-- IncidentReport(bicycle_id)                   -- 자전거별 신고 이력
-- Maintenance(bicycle_id, started_at)          -- 자전거 정비 이력
-- MileageHistory(user_id, created_at)          -- 마일리지 이력 조회
-- Retrieve(bicycle_id)                         -- 자전거별 회수 이력
-- Retrieve(retrieve_status)                    -- 진행 중인 회수 작업 모니터링

-- ==============================================
-- [설계 요약] CHECK 제약 조건 적용 대상
--   잘못된 수치 입력을 DB 레벨에서 차단
-- ==============================================
-- Review.rating BETWEEN 1 AND 5       -- 평점은 1~5점만 허용
-- Payment.amount >= 0                 -- 결제 금액 음수 불가
-- Rental.used_mileage >= 0            -- 마일리지 사용량 음수 불가
-- Rental.final_fare >= 0              -- 최종 요금 음수 불가
-- FarePolicy.base_fare >= 0           -- 기본요금 음수 불가
-- FarePolicy.per_minute_fare >= 0     -- 분당요금 음수 불가
-- FarePolicy.mileage_rate BETWEEN 0 AND 1 -- 마일리지 적립률 0~100% 이내
-- Station.total_dock_count >= 0       -- 슬롯 수 음수 불가
-- User.mileage_balance >= 0           -- 잔여 마일리지 음수 불가


-- 외래키 체크 비활성화 (테이블 생성 순서 무관하게 실행 가능하도록)
SET FOREIGN_KEY_CHECKS = 0;


-- ==============================================
-- 1. Region (지역)
-- 역할: 시흥시 내 행정 구역(동 단위)을 관리하는 최상위 지역 테이블.
--       대여소(Station)와 관리자(AdminStaff)가 이 지역을 참조하여
--       지역별 통계 및 관할 구역 분리에 활용된다.
-- ==============================================
CREATE TABLE Region (
    region_id   INT          AUTO_INCREMENT PRIMARY KEY,
    region_name VARCHAR(50)  NOT NULL UNIQUE COMMENT '동 이름',
    created_at  DATETIME     NOT NULL DEFAULT NOW()
) ENGINE=InnoDB COMMENT='지역(동 단위)';


-- ==============================================
-- 2. Station (대여소)
-- 역할: 자전거를 빌리고 반납하는 물리적 거점 정보.
--       어느 지역(Region)에 속하는지, 위경도 좌표, 총 거치 슬롯 수,
--       운영 상태(정상/비활성/점검) 등을 관리한다.
--       대여(Rental) 시 출발·도착 대여소로 참조된다.
-- ==============================================
CREATE TABLE Station (
    station_id        INT          AUTO_INCREMENT PRIMARY KEY,
    region_id         INT          NOT NULL COMMENT '소속 지역',
    station_name      VARCHAR(100) NOT NULL COMMENT '대여소 명칭',
    address           VARCHAR(255) NOT NULL COMMENT '도로명 주소',
    latitude          DECIMAL(9,6) NOT NULL COMMENT '위도',
    longitude         DECIMAL(9,6) NOT NULL COMMENT '경도',
    total_dock_count  INT          NOT NULL DEFAULT 0 COMMENT '총 거치 슬롯 수',
    station_status    ENUM('ACTIVE','INACTIVE','MAINTENANCE') NOT NULL DEFAULT 'ACTIVE',
    created_at        DATETIME     NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_station_region
        FOREIGN KEY (region_id) REFERENCES Region(region_id)
) ENGINE=InnoDB COMMENT='대여소';


-- ==============================================
-- 3. Dock (거치 슬롯)
-- 역할: 대여소(Station) 내 개별 자전거 거치 공간(슬롯).
--       각 슬롯은 비어있거나(EMPTY), 자전거가 꽂혀있거나(OCCUPIED),
--       고장 상태(BROKEN)를 가진다.
--       자전거(Bicycle)와 대여(Rental)가 이 슬롯을 참조하여
--       정확한 출발/반납 위치를 기록한다.
--       (station_id, dock_no) 복합 유니크 키로 같은 대여소 내 슬롯 번호 중복을 방지한다.
-- ==============================================
CREATE TABLE Dock (
    dock_id      INT         AUTO_INCREMENT PRIMARY KEY,
    station_id   INT         NOT NULL,
    dock_no      VARCHAR(10) NOT NULL COMMENT '대여소 내 슬롯 번호',
    dock_status  ENUM('EMPTY','OCCUPIED','BROKEN') NOT NULL DEFAULT 'EMPTY',
    UNIQUE KEY uq_dock_no (station_id, dock_no),
    CONSTRAINT fk_dock_station
        FOREIGN KEY (station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='개별 거치 슬롯';


-- ==============================================
-- 4. Bicycle (자전거)
-- 역할: 서비스에 등록된 개별 자전거 정보.
--       일반/전동 구분, 현재 상태(이용 가능/대여 중/정비 중/분실/회수 중),
--       현재 위치(대여소·슬롯)를 실시간으로 추적한다.
--       대여 시작 시 bike_status = 'IN_USE', 반납 시 'AVAILABLE'로 갱신된다.
--       current_station_id / current_dock_id는 반납 완료 후에만 값을 가진다.
-- ==============================================
CREATE TABLE Bicycle (
    bicycle_id         BIGINT       AUTO_INCREMENT PRIMARY KEY,
    serial_no          VARCHAR(100) NOT NULL UNIQUE COMMENT '차량 일련번호',
    bike_type          ENUM('NORMAL','ELECTRIC') NOT NULL DEFAULT 'NORMAL',
    bike_status        ENUM('AVAILABLE','IN_USE','MAINTENANCE','LOST','RETRIEVED')
                       NOT NULL DEFAULT 'AVAILABLE',
    current_station_id INT          DEFAULT NULL,  -- 현재 위치 대여소 (대여 중엔 NULL)
    current_dock_id    INT          DEFAULT NULL,  -- 현재 거치 슬롯 (대여 중엔 NULL)
    manufacture_date   DATE,
    registered_at      DATETIME     NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_bicycle_station
        FOREIGN KEY (current_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_bicycle_dock
        FOREIGN KEY (current_dock_id) REFERENCES Dock(dock_id)
) ENGINE=InnoDB COMMENT='자전거';


-- ==============================================
-- 5. FarePolicy (요금 정책)
-- 역할: 대여 요금 계산 기준을 버전 관리하는 테이블.
--       기본 무료 이용 시간, 기본요금, 초과 분당 추가요금,
--       마일리지 적립 비율을 정의한다.
--       effective_from ~ effective_to 기간으로 요금 정책 이력을 관리하며,
--       effective_to = NULL이면 현재 적용 중인 정책이다.
--       Rental이 생성될 때 당시 유효한 policy_id를 기록해 사후 요금 분쟁을 방지한다.
-- ==============================================
CREATE TABLE FarePolicy (
    policy_id       INT           AUTO_INCREMENT PRIMARY KEY,
    policy_name     VARCHAR(100)  NOT NULL COMMENT '정책명',
    base_minutes    INT           NOT NULL COMMENT '기본 무료 이용 시간(분)',
    base_fare       INT           NOT NULL DEFAULT 0 COMMENT '기본요금(원)',
    per_minute_fare INT           NOT NULL COMMENT '초과 분당 추가요금(원)',
    mileage_rate    DECIMAL(4,2)  NOT NULL DEFAULT 0.05 COMMENT '마일리지 적립 비율 (예: 0.05 = 5%)',
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    effective_from  DATE          NOT NULL COMMENT '정책 적용 시작일',
    effective_to    DATE          DEFAULT NULL COMMENT '정책 종료일 (NULL = 현재 유효)',
    CONSTRAINT chk_farePolicy_base_fare     CHECK (base_fare >= 0),
    CONSTRAINT chk_farePolicy_per_minute    CHECK (per_minute_fare >= 0),
    CONSTRAINT chk_farePolicy_mileage_rate  CHECK (mileage_rate BETWEEN 0 AND 1)
) ENGINE=InnoDB COMMENT='요금 정책';


-- ==============================================
-- 6. User (사용자)
-- 역할: 서비스를 이용하는 일반 회원 정보.
--       로그인 인증 정보(login_id, password_hash), 연락처, 계정 상태,
--       마일리지 잔액(mileage_balance)을 관리한다.
--       계정 상태: ACTIVE(정상) / SUSPENDED(정지) / WITHDRAWN(탈퇴)
--       마일리지 잔액은 MileageHistory 테이블에 모든 변동 이력이 기록된다.
-- ==============================================
CREATE TABLE User (
    user_id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    login_id         VARCHAR(50)  NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    name             VARCHAR(50)  NOT NULL,
    phone            VARCHAR(20)  NOT NULL UNIQUE,
    email            VARCHAR(100) UNIQUE DEFAULT NULL,
    user_status      ENUM('ACTIVE','SUSPENDED','WITHDRAWN') NOT NULL DEFAULT 'ACTIVE',
    mileage_balance  INT          NOT NULL DEFAULT 0,
    created_at       DATETIME     NOT NULL DEFAULT NOW(),
    updated_at       DATETIME     NOT NULL DEFAULT NOW() ON UPDATE NOW(),
    CONSTRAINT chk_user_mileage CHECK (mileage_balance >= 0)
) ENGINE=InnoDB COMMENT='서비스 이용자';


-- ==============================================
-- 7. Rental (대여 이력)
-- 역할: 사용자가 자전거를 대여하고 반납하는 전 과정을 기록하는 핵심 트랜잭션 테이블.
--       출발·도착 대여소/슬롯, 이용 시간, 이동 거리, 사용 마일리지, 최종 요금을 저장한다.
--       대여 상태: RENTED(이용 중) / RETURNED(반납 완료) / OVERDUE(연체) / CANCELLED(취소)
--       요금 정책(FarePolicy)은 대여 생성 시점의 policy_id를 고정 기록하여 이력 추적을 보장한다.
--       end_station_id / end_dock_id / end_time / final_fare는 반납 완료 후 채워진다.
-- [주의] uq_active_rental_user 인덱스는 MySQL의 조건부 유니크 제약 한계로
--        동시 진행 대여 1건 제한을 완전히 보장하지 못하므로 애플리케이션 레이어에서 병행 검증 필요.
-- ==============================================
CREATE TABLE Rental (
    rental_id        BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT       NOT NULL,
    bicycle_id       BIGINT       NOT NULL,
    policy_id        INT          NOT NULL,
    start_station_id INT          NOT NULL,
    start_dock_id    INT          NOT NULL,
    end_station_id   INT          DEFAULT NULL,  -- 반납 완료 후 입력
    end_dock_id      INT          DEFAULT NULL,  -- 반납 완료 후 입력
    start_time       DATETIME     NOT NULL,
    end_time         DATETIME     DEFAULT NULL,  -- 반납 완료 후 입력
    distance_km      DECIMAL(6,2) DEFAULT NULL,  -- GPS 기반 이동 거리
    used_mileage     INT          NOT NULL DEFAULT 0 COMMENT '차감된 마일리지(원)',
    final_fare       INT          DEFAULT NULL,  -- 반납 완료 후 최종 계산된 요금
    rental_status    ENUM('RENTED','RETURNED','OVERDUE','CANCELLED')
                     NOT NULL DEFAULT 'RENTED',
    CONSTRAINT fk_rental_user           FOREIGN KEY (user_id)          REFERENCES User(user_id),
    CONSTRAINT fk_rental_bicycle        FOREIGN KEY (bicycle_id)       REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_rental_policy         FOREIGN KEY (policy_id)        REFERENCES FarePolicy(policy_id),
    CONSTRAINT fk_rental_start_station  FOREIGN KEY (start_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_rental_start_dock     FOREIGN KEY (start_dock_id)    REFERENCES Dock(dock_id),
    CONSTRAINT fk_rental_end_station    FOREIGN KEY (end_station_id)   REFERENCES Station(station_id),
    CONSTRAINT fk_rental_end_dock       FOREIGN KEY (end_dock_id)      REFERENCES Dock(dock_id),
    CONSTRAINT chk_rental_used_mileage  CHECK (used_mileage >= 0),
    CONSTRAINT chk_rental_final_fare    CHECK (final_fare IS NULL OR final_fare >= 0)
) ENGINE=InnoDB COMMENT='대여 이력';

-- 사용자당 진행 중 대여 1건 제한 인덱스
-- [한계] MySQL은 조건부(Partial) UNIQUE INDEX를 지원하지 않아 모든 상태를 포함한다.
--        (user_id, RENTED) 중복 방지는 애플리케이션 레이어에서 SELECT FOR UPDATE로 병행 처리 권장.
CREATE UNIQUE INDEX uq_active_rental_user
    ON Rental(user_id, rental_status);


-- ==============================================
-- 8. Payment (결제 이력)
-- 역할: 대여 완료 후 발생하는 결제 트랜잭션을 기록.
--       결제 수단(카드/마일리지/혼합), 상태(성공/실패/취소/환불),
--       PG사 거래 ID를 저장하여 외부 결제 시스템과 매핑한다.
--       결제 성공(SUCCESS) 시 trg_payment_earn_mileage 트리거가 자동으로 마일리지를 적립한다.
-- ==============================================
CREATE TABLE Payment (
    payment_id        BIGINT       AUTO_INCREMENT PRIMARY KEY,
    rental_id         BIGINT       NOT NULL,
    user_id           BIGINT       NOT NULL,
    amount            INT          NOT NULL COMMENT '결제 금액(원)',
    payment_method    ENUM('CARD','MILEAGE','MIXED') NOT NULL,
    payment_time      DATETIME     NOT NULL DEFAULT NOW(),
    payment_status    ENUM('SUCCESS','FAIL','CANCEL','REFUND') NOT NULL,
    pg_transaction_id VARCHAR(100) UNIQUE DEFAULT NULL COMMENT 'PG사 거래 ID (마일리지 단독 결제 시 NULL)',
    CONSTRAINT fk_payment_rental FOREIGN KEY (rental_id) REFERENCES Rental(rental_id),
    CONSTRAINT fk_payment_user   FOREIGN KEY (user_id)   REFERENCES User(user_id),
    CONSTRAINT chk_payment_amount CHECK (amount >= 0)
) ENGINE=InnoDB COMMENT='결제 이력';


-- ==============================================
-- 9. MileageHistory (마일리지 이력)
-- 역할: 사용자 마일리지의 모든 변동 내역(적립/사용/소멸/관리자 조정)을 기록.
--       User.mileage_balance의 현재값을 감사(Audit)하는 보조 테이블로,
--       변동 후 잔액(balance_after)을 함께 저장해 언제든 잔액 이력을 재현할 수 있다.
--       change_type: EARN(적립) / USE(사용) / EXPIRE(소멸) / ADMIN_ADJUST(관리자 직접 조정)
--       관리자 조정(ADMIN_ADJUST)의 경우 rental_id가 NULL일 수 있다.
-- ==============================================
CREATE TABLE MileageHistory (
    mileage_id    BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id       BIGINT       NOT NULL,
    rental_id     BIGINT       DEFAULT NULL COMMENT '관리자 조정 시 NULL 가능',
    change_type   ENUM('EARN','USE','EXPIRE','ADMIN_ADJUST') NOT NULL,
    change_amount INT          NOT NULL COMMENT '양수=적립, 음수=차감',
    balance_after INT          NOT NULL COMMENT '변동 후 최종 잔액',
    description   VARCHAR(255) DEFAULT NULL COMMENT '변동 사유 메모',
    created_at    DATETIME     NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mileage_user   FOREIGN KEY (user_id)   REFERENCES User(user_id),
    CONSTRAINT fk_mileage_rental FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
) ENGINE=InnoDB COMMENT='마일리지 이력';


-- ==============================================
-- 10. Review (이용 리뷰)
-- 역할: 대여 완료 후 사용자가 남기는 만족도 평가.
--       rental_id에 UNIQUE 제약으로 대여 1건당 리뷰 1개만 허용한다.
--       rating은 1~5점 정수(CHECK 제약 적용), comment는 선택 입력이다.
--       서비스 품질 모니터링 및 자전거/대여소 개선에 활용된다.
-- ==============================================
CREATE TABLE Review (
    review_id  BIGINT   AUTO_INCREMENT PRIMARY KEY,
    rental_id  BIGINT   NOT NULL UNIQUE COMMENT '대여 1건당 1리뷰',
    user_id    BIGINT   NOT NULL,
    rating     TINYINT  NOT NULL COMMENT '1~5점 평점',
    comment    TEXT     DEFAULT NULL COMMENT '상세 후기 (선택)',
    created_at DATETIME NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_review_rental FOREIGN KEY (rental_id) REFERENCES Rental(rental_id),
    CONSTRAINT fk_review_user   FOREIGN KEY (user_id)   REFERENCES User(user_id),
    CONSTRAINT chk_review_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB COMMENT='이용 리뷰';


-- ==============================================
-- 11. AdminStaff (운영 관리자)
-- 역할: 시스템을 운영·관리하는 내부 직원 계정.
--       역할(role)에 따라 권한이 구분된다:
--         OPERATOR  - 일반 운영 담당 (대여소 현황 확인, 민원 처리)
--         ENGINEER  - 자전거 정비·회수 담당
--         ADMIN     - 전체 시스템 관리 (요금 정책 변경, 사용자 계정 관리 등)
--       region_id가 NULL이면 특정 지역에 구애받지 않는 전체 담당 관리자를 의미한다.
-- ==============================================
CREATE TABLE AdminStaff (
    staff_id      INT          AUTO_INCREMENT PRIMARY KEY,
    login_id      VARCHAR(50)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    staff_name    VARCHAR(50)  NOT NULL,
    phone         VARCHAR(20)  UNIQUE DEFAULT NULL,
    role          ENUM('OPERATOR','ENGINEER','ADMIN') NOT NULL,
    region_id     INT          DEFAULT NULL COMMENT 'NULL이면 전체 담당',
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    DATETIME     NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_staff_region FOREIGN KEY (region_id) REFERENCES Region(region_id)
) ENGINE=InnoDB COMMENT='운영 관리자';


-- ==============================================
-- 12. IncidentReport (고장/민원 신고)
-- 역할: 사용자가 접수한 자전거 고장, 안전 문제, 분실, 도난, 기타 민원을 관리.
--       신고 대상은 자전거(bicycle_id) 또는 대여소(station_id) 중 하나이며 둘 다 NULL일 수도 있다.
--       담당 관리자(assigned_staff_id)가 배정되면 IN_PROGRESS 상태로 전환된다.
--         → trg_maintenance_update_incident 트리거가 Maintenance 생성 시 자동으로 상태를 갱신한다.
--       신고 상태: OPEN(접수) / IN_PROGRESS(처리 중) / RESOLVED(해결) / CLOSED(종결)
-- ==============================================
CREATE TABLE IncidentReport (
    incident_id       BIGINT   AUTO_INCREMENT PRIMARY KEY,
    reporter_user_id  BIGINT   NOT NULL,
    bicycle_id        BIGINT   DEFAULT NULL COMMENT '신고 대상 자전거 (없으면 NULL)',
    station_id        INT      DEFAULT NULL COMMENT '신고 대상 대여소 (없으면 NULL)',
    incident_type     ENUM('BROKEN','SAFETY','LOST','THEFT','ETC') NOT NULL,
    description       TEXT     DEFAULT NULL COMMENT '상세 신고 내용',
    reported_at       DATETIME NOT NULL DEFAULT NOW(),
    incident_status   ENUM('OPEN','IN_PROGRESS','RESOLVED','CLOSED')
                      NOT NULL DEFAULT 'OPEN',
    assigned_staff_id INT      DEFAULT NULL COMMENT '담당 관리자 (미배정 시 NULL)',
    resolved_at       DATETIME DEFAULT NULL COMMENT '처리 완료 시각',
    CONSTRAINT fk_incident_user    FOREIGN KEY (reporter_user_id)  REFERENCES User(user_id),
    CONSTRAINT fk_incident_bicycle FOREIGN KEY (bicycle_id)        REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_incident_station FOREIGN KEY (station_id)        REFERENCES Station(station_id),
    CONSTRAINT fk_incident_staff   FOREIGN KEY (assigned_staff_id) REFERENCES AdminStaff(staff_id)
) ENGINE=InnoDB COMMENT='고장 및 민원 신고';


-- ==============================================
-- 13. Maintenance (정비 이력)
-- 역할: 관리자(ENGINEER)가 자전거에 수행한 정비 작업 기록.
--       정비 유형: ROUTINE(정기 점검) / REPAIR(수리) / INSPECTION(임시 점검)
--       신고(IncidentReport)에서 파생된 정비라면 incident_id를 연결한다.
--       정비 생성 시 trg_maintenance_update_incident 트리거가 연계 신고를 IN_PROGRESS로 갱신하고,
--       정비 완료(COMPLETED) 시 trg_maintenance_complete_bicycle 트리거가
--       자전거 상태를 AVAILABLE로 자동 복구한다.
-- ==============================================
CREATE TABLE Maintenance (
    maintenance_id     BIGINT   AUTO_INCREMENT PRIMARY KEY,
    bicycle_id         BIGINT   NOT NULL,
    staff_id           INT      NOT NULL,
    incident_id        BIGINT   DEFAULT NULL COMMENT '연계 신고 (자체 정비면 NULL)',
    maintenance_type   ENUM('ROUTINE','REPAIR','INSPECTION') NOT NULL,
    description        TEXT     DEFAULT NULL COMMENT '정비 상세 내역',
    started_at         DATETIME NOT NULL,
    ended_at           DATETIME DEFAULT NULL COMMENT '정비 완료 시각',
    maintenance_status ENUM('IN_PROGRESS','COMPLETED') NOT NULL DEFAULT 'IN_PROGRESS',
    CONSTRAINT fk_maintenance_bicycle  FOREIGN KEY (bicycle_id)  REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_maintenance_staff    FOREIGN KEY (staff_id)    REFERENCES AdminStaff(staff_id),
    CONSTRAINT fk_maintenance_incident FOREIGN KEY (incident_id) REFERENCES IncidentReport(incident_id)
) ENGINE=InnoDB COMMENT='정비 이력';


-- ==============================================
-- 14. Retrieve (회수 이력)
-- 역할: 지정 구역 이탈, 방치, 신고 등으로 발생한 자전거 회수 작업 기록.
--       발견 위치(retrieve_location, 위경도), 목표 반납 대여소(target_station_id),
--       회수 사유(OUT_OF_AREA/ABANDONED/REPORTED/ETC)를 저장한다.
--       회수 완료(COMPLETED) 후 자전거 상태 및 위치는 애플리케이션 레이어에서 갱신 처리한다.
--       신고(IncidentReport)에서 파생된 회수라면 incident_id를 연결한다.
-- ==============================================
CREATE TABLE Retrieve (
    retrieve_id       BIGINT        AUTO_INCREMENT PRIMARY KEY,
    bicycle_id        BIGINT        NOT NULL,
    staff_id          INT           NOT NULL,
    incident_id       BIGINT        DEFAULT NULL COMMENT '연계 신고 (자체 회수면 NULL)',
    retrieve_location VARCHAR(255)  NOT NULL COMMENT '발견 위치 주소',
    retrieve_lat      DECIMAL(9,6)  DEFAULT NULL COMMENT '발견 위도',
    retrieve_lng      DECIMAL(9,6)  DEFAULT NULL COMMENT '발견 경도',
    target_station_id INT           NOT NULL COMMENT '반납 목표 대여소',
    retrieved_at      DATETIME      NOT NULL DEFAULT NOW() COMMENT '회수 시작 시각',
    completed_at      DATETIME      DEFAULT NULL COMMENT '회수 완료 시각',
    retrieve_reason   ENUM('OUT_OF_AREA','ABANDONED','REPORTED','ETC') NOT NULL,
    retrieve_status   ENUM('IN_PROGRESS','COMPLETED') NOT NULL DEFAULT 'IN_PROGRESS',
    CONSTRAINT fk_retrieve_bicycle  FOREIGN KEY (bicycle_id)        REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_retrieve_staff    FOREIGN KEY (staff_id)          REFERENCES AdminStaff(staff_id),
    CONSTRAINT fk_retrieve_incident FOREIGN KEY (incident_id)       REFERENCES IncidentReport(incident_id),
    CONSTRAINT fk_retrieve_station  FOREIGN KEY (target_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='자전거 회수 이력';


-- ==============================================
-- 검색 성능 인덱스
-- 목적: 운영 대시보드·통계·모니터링 쿼리의 풀 테이블 스캔을 방지한다.
-- ==============================================

-- 사용자별 대여 이력 조회 (마이페이지, 이용 내역)
CREATE INDEX idx_rental_user_time         ON Rental(user_id, start_time);
-- 자전거별 이용 이력 조회 (자전거 상태 추적)
CREATE INDEX idx_rental_bicycle_time      ON Rental(bicycle_id, start_time);
-- 미반납·연체 자전거 실시간 모니터링
CREATE INDEX idx_rental_status_time       ON Rental(rental_status, start_time);
-- 사용자별 결제 내역 조회
CREATE INDEX idx_payment_user_time        ON Payment(user_id, payment_time);
-- 대여-결제 조인 최적화
CREATE INDEX idx_payment_rental           ON Payment(rental_id);
-- 미처리(OPEN) 신고 목록 모니터링
CREATE INDEX idx_incident_status_time     ON IncidentReport(incident_status, reported_at);
-- 자전거별 신고 이력 조회
CREATE INDEX idx_incident_bicycle         ON IncidentReport(bicycle_id);
-- 자전거별 정비 이력 조회
CREATE INDEX idx_maintenance_bicycle_time ON Maintenance(bicycle_id, started_at);
-- 사용자별 마일리지 변동 이력 조회
CREATE INDEX idx_mileage_user_time        ON MileageHistory(user_id, created_at);
-- 자전거별 회수 이력 조회
CREATE INDEX idx_retrieve_bicycle         ON Retrieve(bicycle_id);
-- 진행 중인 회수 작업 목록 모니터링
CREATE INDEX idx_retrieve_status          ON Retrieve(retrieve_status);

-- 외래키 체크 재활성화
SET FOREIGN_KEY_CHECKS = 1;


-- ==============================================
-- 트리거 (Triggers)
-- 목적: 연관 테이블 간 상태 동기화를 DB 레벨에서 자동화하여
--       애플리케이션 코드의 실수나 누락으로 인한 데이터 불일치를 방지한다.
-- ==============================================

-- [트리거 1] trg_maintenance_update_incident
-- 동작: Maintenance 레코드가 INSERT될 때 실행
-- 효과: 연결된 IncidentReport가 아직 OPEN 상태이면 자동으로 IN_PROGRESS로 변경
--       → 정비 착수 즉시 신고 상태를 별도 업데이트하지 않아도 된다
DELIMITER $$
CREATE TRIGGER trg_maintenance_update_incident
AFTER INSERT ON Maintenance
FOR EACH ROW
BEGIN
    IF NEW.incident_id IS NOT NULL THEN
        UPDATE IncidentReport
        SET incident_status = 'IN_PROGRESS'
        WHERE incident_id = NEW.incident_id
          AND incident_status = 'OPEN';
    END IF;
END$$
DELIMITER ;

-- [트리거 2] trg_maintenance_complete_bicycle
-- 동작: Maintenance 레코드가 UPDATE될 때 실행
-- 효과: 정비 상태가 IN_PROGRESS → COMPLETED로 바뀌면 해당 자전거를 AVAILABLE로 복구
--       → 정비 완료 처리 한 번으로 자전거 상태까지 자동 정상화
DELIMITER $$
CREATE TRIGGER trg_maintenance_complete_bicycle
AFTER UPDATE ON Maintenance
FOR EACH ROW
BEGIN
    IF NEW.maintenance_status = 'COMPLETED' AND OLD.maintenance_status = 'IN_PROGRESS' THEN
        UPDATE Bicycle
        SET bike_status = 'AVAILABLE'
        WHERE bicycle_id = NEW.bicycle_id;
    END IF;
END$$
DELIMITER ;

-- [트리거 3] trg_payment_earn_mileage
-- 동작: Payment 레코드가 INSERT될 때 실행
-- 효과: 결제 상태가 SUCCESS이면 대여에 연결된 요금 정책의 mileage_rate를 조회해
--       결제금액 × 적립률만큼 User.mileage_balance를 증가시키고
--       MileageHistory에 EARN 이력을 자동 기록한다
--       → 결제 성공 처리 한 번으로 마일리지 적립까지 원자적으로 처리
DELIMITER $$
CREATE TRIGGER trg_payment_earn_mileage
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    DECLARE v_rate    DECIMAL(4,2);
    DECLARE v_earn    INT;
    DECLARE v_balance INT;

    IF NEW.payment_status = 'SUCCESS' THEN
        -- 해당 대여에 적용된 요금 정책의 마일리지 적립률 조회
        SELECT fp.mileage_rate INTO v_rate
        FROM Rental r
        JOIN FarePolicy fp ON r.policy_id = fp.policy_id
        WHERE r.rental_id = NEW.rental_id;

        SET v_earn = FLOOR(NEW.amount * v_rate);  -- 원 단위 절사

        -- 사용자 마일리지 잔액 증가
        UPDATE User SET mileage_balance = mileage_balance + v_earn
        WHERE user_id = NEW.user_id;

        -- 변동 후 잔액 조회 (MileageHistory 기록용)
        SELECT mileage_balance INTO v_balance FROM User WHERE user_id = NEW.user_id;

        -- 마일리지 적립 이력 기록
        INSERT INTO MileageHistory(user_id, rental_id, change_type, change_amount, balance_after, description)
        VALUES (NEW.user_id, NEW.rental_id, 'EARN', v_earn, v_balance, '대여 이용 마일리지 적립');
    END IF;
END$$
DELIMITER ;


-- ==============================================
-- 핵심 운영 쿼리 예시
-- 목적: 관리자 대시보드 및 운영 모니터링에 자주 사용되는 쿼리 패턴을 정리
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
