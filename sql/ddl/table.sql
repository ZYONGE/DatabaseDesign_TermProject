-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 DDL
-- 설계 기준 : docs/design.md
-- DBMS     : MySQL 8.0 / InnoDB / utf8mb4
-- ==============================================
-- 엔터티 생성 순서 (FK 의존성 기준)
--   1. Region        2. BicycleType   3. Station
--   4. Bicycle       5. User          6. AdminStaff
--   7. Rental        8. IncidentReport 9. Maintenance
--  10. Retrieve     11. Penalty      12. Allocation
-- ==============================================

SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------
-- 1. Region (지역)
--    시흥시 내 행정 구역(동 단위) 최상위 참조 테이블.
--    Station, Allocation 이 region_id 를 참조한다.
-- -----------------------------------------------
CREATE TABLE Region (
    region_id   INT         AUTO_INCREMENT PRIMARY KEY,
    region_name VARCHAR(50) NOT NULL UNIQUE COMMENT '동 이름',
    created_at  DATETIME    NOT NULL DEFAULT NOW()
) ENGINE=InnoDB COMMENT='지역(동 단위)';


-- -----------------------------------------------
-- 2. BicycleType (자전거 종류)
--    일반(1인) / 어린이 / 2인용 3종.
--    어린이 자전거는 만 13세 미만(User.birth_date 기준) 만 대여 가능.
--    점검 주기(inspection_cycle) 는 종류별로 다르게 설정한다.
-- -----------------------------------------------
CREATE TABLE BicycleType (
    type_id          INT         AUTO_INCREMENT PRIMARY KEY,
    type_name        VARCHAR(50) NOT NULL UNIQUE COMMENT '종류명 (일반/어린이/2인용)',
    max_passenger    TINYINT     NOT NULL DEFAULT 1  COMMENT '최대 탑승 인원',
    inspection_cycle INT         NOT NULL DEFAULT 30 COMMENT '정기점검 주기(일)',
    description      TEXT                            COMMENT '종류 설명'
) ENGINE=InnoDB COMMENT='자전거 종류';


-- -----------------------------------------------
-- 3. Station (대여소)
--    자전거를 대여·반납하는 물리적 거점.
--    반납은 시흥시 내 운영중('운영중')인 모든 대여소에서 가능하다.
-- -----------------------------------------------
CREATE TABLE Station (
    station_id     INT           AUTO_INCREMENT PRIMARY KEY,
    region_id      INT           NOT NULL                    COMMENT '소속 지역',
    station_name   VARCHAR(100)  NOT NULL                    COMMENT '대여소 명칭',
    address        VARCHAR(255)  NOT NULL                    COMMENT '주소',
    contact        VARCHAR(20)   DEFAULT NULL                COMMENT '연락처',
    latitude       DECIMAL(10,7) DEFAULT NULL                COMMENT 'GPS 위도',
    longitude      DECIMAL(10,7) DEFAULT NULL                COMMENT 'GPS 경도',
    total_docks    INT           NOT NULL DEFAULT 0          COMMENT '총 거치대 수',
    station_status ENUM('운영중','휴관','정비중') NOT NULL DEFAULT '운영중',
    created_at     DATETIME      NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_station_region FOREIGN KEY (region_id) REFERENCES Region(region_id)
) ENGINE=InnoDB COMMENT='대여소';


-- -----------------------------------------------
-- 4. Bicycle (자전거)
--    GPS 위치를 실시간 추적하며, 대여중일 때만 gps 컬럼이 갱신된다.
--    반납·회수 완료 시 gps 컬럼은 NULL 로 초기화한다.
--    current_station_id 는 대여중·정비중·분실·회수중 상태일 때 NULL 이다.
-- -----------------------------------------------
CREATE TABLE Bicycle (
    bicycle_id         INT           AUTO_INCREMENT PRIMARY KEY,
    type_id            INT           NOT NULL     COMMENT '자전거 종류',
    bike_status        ENUM('정상','대여중','정비중','분실','회수중')
                                     NOT NULL DEFAULT '정상',
    current_station_id INT           DEFAULT NULL COMMENT '현재 위치 대여소 (대여중·분실·회수중 시 NULL)',
    gps_latitude       DECIMAL(10,7) DEFAULT NULL COMMENT '실시간 GPS 위도 (대여중일 때만 갱신)',
    gps_longitude      DECIMAL(10,7) DEFAULT NULL COMMENT '실시간 GPS 경도 (대여중일 때만 갱신)',
    gps_updated_at     DATETIME      DEFAULT NULL COMMENT 'GPS 최종 갱신 일시',
    registered_at      DATETIME      NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_bicycle_type    FOREIGN KEY (type_id)            REFERENCES BicycleType(type_id),
    CONSTRAINT fk_bicycle_station FOREIGN KEY (current_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='자전거';


-- -----------------------------------------------
-- 5. User (사용자)
--    birth_date 로 만 13세 미만 여부를 대여 시점에 실시간 계산한다.
--    is_minor 파생 컬럼은 3NF 위반(이행 종속)으로 제거. (design.md 7.8, 8.2 참조)
-- -----------------------------------------------
CREATE TABLE User (
    user_id     INT          AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL                      COMMENT '실명',
    birth_date  DATE         NOT NULL                      COMMENT '생년월일 (어린이 자전거 이용 자격 검증)',
    phone       VARCHAR(20)  NOT NULL UNIQUE               COMMENT '연락처',
    address     VARCHAR(255) DEFAULT NULL                  COMMENT '주소',
    user_status ENUM('정상','정지') NOT NULL DEFAULT '정상',
    created_at  DATETIME     NOT NULL DEFAULT NOW()
) ENGINE=InnoDB COMMENT='서비스 이용자';


-- -----------------------------------------------
-- 6. AdminStaff (운영 관리자)
--    station_id = NULL : 전사 관리 역할 (관리자)
--    station_id = 지정 : 해당 대여소 상주 직원 (정비사·운영요원)
--    역할 구분은 애플리케이션 레이어에서 처리한다. (design.md 7.9 참조)
-- -----------------------------------------------
CREATE TABLE AdminStaff (
    staff_id   INT         AUTO_INCREMENT PRIMARY KEY,
    staff_name VARCHAR(50) NOT NULL       COMMENT '성명',
    phone      VARCHAR(20) NOT NULL UNIQUE COMMENT '연락처',
    station_id INT         DEFAULT NULL   COMMENT '담당 대여소 (전사 관리자는 NULL 허용)',
    is_active  TINYINT(1)  NOT NULL DEFAULT 1 COMMENT '재직 여부 (1=재직, 0=퇴직)',
    created_at DATETIME    NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_staff_station FOREIGN KEY (station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='운영 관리자';


-- -----------------------------------------------
-- 7. Rental (대여 이력)
--    rental_date 는 start_time 에서 도출 가능하나
--    날짜 기반 집계 쿼리 성능을 위해 의도적으로 분리 저장한다. (design.md 8.3)
--    end_station_id 는 대여중 NULL, 반납 완료 후 채워진다.
-- -----------------------------------------------
CREATE TABLE Rental (
    rental_id        INT          AUTO_INCREMENT PRIMARY KEY,
    user_id          INT          NOT NULL      COMMENT '이용 사용자',
    bicycle_id       INT          NOT NULL      COMMENT '대여 자전거',
    start_station_id INT          NOT NULL      COMMENT '대여 시작 대여소',
    end_station_id   INT          DEFAULT NULL  COMMENT '반납 대여소 (대여중 NULL)',
    rental_date      DATE         NOT NULL      COMMENT '대여 날짜 (집계 인덱스용, 의도적 비정규화)',
    start_time       DATETIME     NOT NULL      COMMENT '대여 시작 일시',
    end_time         DATETIME     DEFAULT NULL  COMMENT '반납 일시',
    duration_min     INT          DEFAULT NULL  COMMENT '이용 시간(분)',
    distance_km      DECIMAL(7,3) DEFAULT NULL  COMMENT '이용 거리(km)',
    rental_status    ENUM('대여중','반납','미반납') NOT NULL DEFAULT '대여중',
    CONSTRAINT fk_rental_user          FOREIGN KEY (user_id)          REFERENCES User(user_id),
    CONSTRAINT fk_rental_bicycle       FOREIGN KEY (bicycle_id)       REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_rental_start_station FOREIGN KEY (start_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_rental_end_station   FOREIGN KEY (end_station_id)   REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='대여 이력';


-- -----------------------------------------------
-- 8. IncidentReport (고장/민원 신고)
--    user_id = NULL : 관리자가 직접 접수한 신고
--    bicycle_id 는 NOT NULL (신고는 반드시 자전거 단위로 접수)
-- -----------------------------------------------
CREATE TABLE IncidentReport (
    incident_id       INT      AUTO_INCREMENT PRIMARY KEY,
    user_id           INT      DEFAULT NULL  COMMENT '신고자 (NULL = 관리자 직접 접수)',
    bicycle_id        INT      NOT NULL      COMMENT '신고 대상 자전거',
    incident_type     ENUM('고장','방치','분실','기타') NOT NULL,
    description       TEXT     DEFAULT NULL  COMMENT '신고 내용',
    reported_at       DATETIME NOT NULL DEFAULT NOW(),
    incident_status   ENUM('접수','처리중','완료') NOT NULL DEFAULT '접수',
    assigned_staff_id INT      DEFAULT NULL  COMMENT '담당 관리자 (미배정 시 NULL)',
    resolved_at       DATETIME DEFAULT NULL  COMMENT '처리 완료 일시',
    CONSTRAINT fk_incident_user    FOREIGN KEY (user_id)           REFERENCES User(user_id),
    CONSTRAINT fk_incident_bicycle FOREIGN KEY (bicycle_id)        REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_incident_staff   FOREIGN KEY (assigned_staff_id) REFERENCES AdminStaff(staff_id)
) ENGINE=InnoDB COMMENT='고장/민원 신고';


-- -----------------------------------------------
-- 9. Maintenance (정비 이력)
--    정비는 외부 업체(외주)에 위탁한다. (design.md 5.9, 7.5 참조)
--    본 테이블은 "정비를 외주에 맡겼다"는 사실과 반납 결과만 기록한다.
--    외주 업체 작업자·방법은 관리하지 않으므로 staff_id 없음.
--    incident_id = NULL : 신고 없이 의뢰하는 정기점검
--    return_station_id  : 외주 업체가 정비 완료 후 자전거를 반납할 대여소
--    정비 완료 시 trg_maintenance_complete 가 Bicycle 상태를 자동 복구한다.
-- -----------------------------------------------
CREATE TABLE Maintenance (
    maintenance_id     INT      AUTO_INCREMENT PRIMARY KEY,
    bicycle_id         INT      NOT NULL      COMMENT '정비 자전거',
    incident_id        INT      DEFAULT NULL  COMMENT '연계 신고 (정기점검 의뢰 시 NULL)',
    maintenance_type   ENUM('정기점검','수리','청소') NOT NULL,
    description        TEXT     DEFAULT NULL  COMMENT '정비 의뢰 내용',
    return_station_id  INT      DEFAULT NULL  COMMENT '외주 정비 완료 후 자전거 반납 대여소',
    started_at         DATETIME NOT NULL      COMMENT '정비 의뢰 일시',
    ended_at           DATETIME DEFAULT NULL  COMMENT '정비 완료(자전거 반납) 일시',
    maintenance_status ENUM('진행중','완료') NOT NULL DEFAULT '진행중',
    CONSTRAINT fk_maintenance_bicycle  FOREIGN KEY (bicycle_id)        REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_maintenance_incident FOREIGN KEY (incident_id)       REFERENCES IncidentReport(incident_id),
    CONSTRAINT fk_maintenance_station  FOREIGN KEY (return_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='정비 외주 의뢰 이력';


-- -----------------------------------------------
-- 10. Retrieve (자전거 회수 이력)
--    staff_id = NULL : GPS 자동 감지로 생성된 회수 건 (이후 관리자가 배정)
--    incident_id = NULL : 신고 없이 자동 감지된 회수 건
--    회수 완료 시 trg_retrieve_complete 가 Bicycle 상태를 자동 복구한다.
-- -----------------------------------------------
CREATE TABLE Retrieve (
    retrieve_id        INT           AUTO_INCREMENT PRIMARY KEY,
    bicycle_id         INT           NOT NULL      COMMENT '회수 자전거',
    staff_id           INT           DEFAULT NULL  COMMENT '담당 회수 요원 (자동 생성 시 NULL, 이후 배정)',
    incident_id        INT           DEFAULT NULL  COMMENT '연계 신고 (자동 감지 시 NULL)',
    retrieve_latitude  DECIMAL(10,7) DEFAULT NULL  COMMENT '발견 위치 위도',
    retrieve_longitude DECIMAL(10,7) DEFAULT NULL  COMMENT '발견 위치 경도',
    retrieve_location  VARCHAR(255)  NOT NULL      COMMENT '발견 주소',
    target_station_id  INT           NOT NULL      COMMENT '반납 목표 대여소',
    retrieved_at       DATETIME      NOT NULL DEFAULT NOW() COMMENT '회수 시작 일시',
    completed_at       DATETIME      DEFAULT NULL  COMMENT '반납 완료 일시',
    retrieve_reason    ENUM('방치','미반납','구역이탈','기타') NOT NULL,
    retrieve_status    ENUM('진행중','완료') NOT NULL DEFAULT '진행중',
    CONSTRAINT fk_retrieve_bicycle  FOREIGN KEY (bicycle_id)        REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_retrieve_staff    FOREIGN KEY (staff_id)          REFERENCES AdminStaff(staff_id),
    CONSTRAINT fk_retrieve_incident FOREIGN KEY (incident_id)       REFERENCES IncidentReport(incident_id),
    CONSTRAINT fk_retrieve_station  FOREIGN KEY (target_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='자전거 회수 이력';


-- -----------------------------------------------
-- 11. Penalty (패널티)
--    rental_id UNIQUE : 미반납 1건당 패널티 1건 (중복 방지)
--    penalty_days = 경과일수 × 10  (design.md 7.4)
--    ban_end = NULL : 영구 금지 (수동 설정 시)
--    패널티 만료(ban_end < CURRENT_DATE) 시 User.user_status → '정상' 자동 복구 (배치 처리)
-- -----------------------------------------------
CREATE TABLE Penalty (
    penalty_id   INT      AUTO_INCREMENT PRIMARY KEY,
    user_id      INT      NOT NULL       COMMENT '대상 사용자',
    rental_id    INT      NOT NULL UNIQUE COMMENT '미반납 대여 건 (건당 1개)',
    penalty_days INT      NOT NULL       COMMENT '대여 금지 일수 (경과일수 × 10)',
    ban_start    DATE     NOT NULL       COMMENT '금지 시작일',
    ban_end      DATE     DEFAULT NULL   COMMENT '금지 종료일 (NULL = 영구 금지)',
    created_at   DATETIME NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_penalty_user   FOREIGN KEY (user_id)   REFERENCES User(user_id),
    CONSTRAINT fk_penalty_rental FOREIGN KEY (rental_id) REFERENCES Rental(rental_id)
) ENGINE=InnoDB COMMENT='미반납 패널티';


-- -----------------------------------------------
-- 12. Allocation (자전거 배치 이력)
--    region_id 와 station_id 를 함께 저장한다.
--    station_id = NULL : 지역만 지정된 배치 (대여소 미확정)
--    region_id 는 station_id 가 NULL 일 때 지역 식별을 위한 의도적 비정규화. (design.md 8.3)
-- -----------------------------------------------
CREATE TABLE Allocation (
    allocation_id INT      AUTO_INCREMENT PRIMARY KEY,
    bicycle_id    INT      NOT NULL      COMMENT '배치 자전거',
    region_id     INT      NOT NULL      COMMENT '배치 지역',
    station_id    INT      DEFAULT NULL  COMMENT '배치 대여소 (미정 시 NULL, 확정 시 업데이트)',
    allocated_by  INT      NOT NULL      COMMENT '배치 담당자',
    allocated_at  DATETIME NOT NULL DEFAULT NOW() COMMENT '배치 일시',
    note          TEXT     DEFAULT NULL  COMMENT '비고',
    CONSTRAINT fk_allocation_bicycle FOREIGN KEY (bicycle_id)   REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_allocation_region  FOREIGN KEY (region_id)    REFERENCES Region(region_id),
    CONSTRAINT fk_allocation_station FOREIGN KEY (station_id)   REFERENCES Station(station_id),
    CONSTRAINT fk_allocation_staff   FOREIGN KEY (allocated_by) REFERENCES AdminStaff(staff_id)
) ENGINE=InnoDB COMMENT='자전거 배치 이력';


-- ==============================================
-- 인덱스 (design.md 9절 기준)
-- ==============================================

-- Station: 지역별 대여소 조회, 운영 상태 필터링
CREATE INDEX idx_station_region ON Station(region_id);
CREATE INDEX idx_station_status ON Station(station_status);

-- Bicycle: 상태·위치별 자전거 조회
CREATE INDEX idx_bicycle_type    ON Bicycle(type_id);
CREATE INDEX idx_bicycle_status  ON Bicycle(bike_status);
CREATE INDEX idx_bicycle_station ON Bicycle(current_station_id);
-- 구역 이탈 감시 대상 필터링 (대여중 + GPS 갱신 시각)
CREATE INDEX idx_bicycle_gps_watch ON Bicycle(bike_status, gps_updated_at);

-- Rental: 사용자별·날짜별 대여 조회, 대여소별 이용 통계
CREATE INDEX idx_rental_user          ON Rental(user_id);
CREATE INDEX idx_rental_bicycle       ON Rental(bicycle_id);
CREATE INDEX idx_rental_status        ON Rental(rental_status);
CREATE INDEX idx_rental_date          ON Rental(rental_date);
CREATE INDEX idx_rental_start_station ON Rental(start_station_id);
CREATE INDEX idx_rental_end_station   ON Rental(end_station_id);

-- Penalty: 활성 패널티 유효성 검증
CREATE INDEX idx_penalty_user_ban ON Penalty(user_id, ban_start, ban_end);

-- IncidentReport: 자전거별 신고 현황 조회
CREATE INDEX idx_incident_bicycle ON IncidentReport(bicycle_id);
CREATE INDEX idx_incident_status  ON IncidentReport(incident_status);

-- Maintenance: 자전거별 정비 현황 조회
CREATE INDEX idx_maintenance_bicycle ON Maintenance(bicycle_id);
CREATE INDEX idx_maintenance_status  ON Maintenance(maintenance_status);

-- Retrieve: 자전거별 진행중 회수 중복 방지 조회
CREATE INDEX idx_retrieve_bicycle_status ON Retrieve(bicycle_id, retrieve_status);

SET FOREIGN_KEY_CHECKS = 1;


-- ==============================================
-- 트리거 (Triggers)
-- 설계 문서 7절 비즈니스 규칙 자동화
-- ==============================================

-- [트리거 1] trg_maintenance_complete
-- 동작: Maintenance 가 UPDATE 될 때 실행
-- 효과: 정비 상태가 진행중 → 완료로 변경되면
--       - Bicycle.bike_status → '정상'
--       - Bicycle.current_station_id → Maintenance.return_station_id (외주 반납 대여소)
--       - 연계 IncidentReport.incident_status → '완료'
-- 정비는 외주로 진행되므로 staff 기반 station 참조 없음.
-- return_station_id 가 NULL 이면 자전거 위치는 미확정(애플리케이션에서 수동 처리).
DELIMITER $$
CREATE TRIGGER trg_maintenance_complete
AFTER UPDATE ON Maintenance
FOR EACH ROW
BEGIN
    IF NEW.maintenance_status = '완료' AND OLD.maintenance_status = '진행중' THEN
        UPDATE Bicycle
        SET bike_status        = '정상',
            current_station_id = NEW.return_station_id
        WHERE bicycle_id = NEW.bicycle_id;

        IF NEW.incident_id IS NOT NULL THEN
            UPDATE IncidentReport
            SET incident_status = '완료',
                resolved_at     = NOW()
            WHERE incident_id     = NEW.incident_id
              AND incident_status != '완료';
        END IF;
    END IF;
END$$
DELIMITER ;


-- [트리거 2] trg_retrieve_complete
-- 동작: Retrieve 가 UPDATE 될 때 실행
-- 효과: 회수 상태가 진행중 → 완료로 변경되면
--       - Bicycle.bike_status → '정상'
--       - Bicycle.current_station_id → target_station_id
--       - Bicycle GPS 컬럼 전체 NULL 초기화
--       - 연계 IncidentReport.incident_status → '완료'
DELIMITER $$
CREATE TRIGGER trg_retrieve_complete
AFTER UPDATE ON Retrieve
FOR EACH ROW
BEGIN
    IF NEW.retrieve_status = '완료' AND OLD.retrieve_status = '진행중' THEN
        UPDATE Bicycle
        SET bike_status        = '정상',
            current_station_id = NEW.target_station_id,
            gps_latitude       = NULL,
            gps_longitude      = NULL,
            gps_updated_at     = NULL
        WHERE bicycle_id = NEW.bicycle_id;

        IF NEW.incident_id IS NOT NULL THEN
            UPDATE IncidentReport
            SET incident_status = '완료',
                resolved_at     = NOW()
            WHERE incident_id     = NEW.incident_id
              AND incident_status != '완료';
        END IF;
    END IF;
END$$
DELIMITER ;
