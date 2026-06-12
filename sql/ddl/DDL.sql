-- ==============================================
-- 시흥시 공공 자전거 대여 서비스 DDL (속성명 전역 유일 적용)
-- DBMS : MySQL 8.0 / InnoDB / utf8mb4
-- ==============================================
-- 엔터티 생성 순서 (FK 의존성 기준)
--   1. Region        2. BicycleType   3. Station
--   4. Bicycle       5. User          6. AdminStaff
--   7. Rental        8. IncidentReport 9. Maintenance
--  10. Retrieve     11. Penalty      12. Allocation
-- ==============================================

CREATE DATABASE IF NOT EXISTS siheung_bicycle1
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE siheung_bicycle1;

SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------
-- 1. Region (지역)
-- -----------------------------------------------
CREATE TABLE Region (
    region_id         INT          NOT NULL AUTO_INCREMENT,
    region_name       VARCHAR(50)  NOT NULL UNIQUE COMMENT '동 이름',
    region_created_at DATETIME     NOT NULL DEFAULT NOW(),
    PRIMARY KEY (region_id)
) ENGINE=InnoDB COMMENT='지역(동 단위)';


-- -----------------------------------------------
-- 2. BicycleType (자전거타입)
-- -----------------------------------------------
CREATE TABLE BicycleType (
    bicycleType_id          INT          NOT NULL AUTO_INCREMENT,
    bicycleType_name        VARCHAR(50)  NOT NULL UNIQUE COMMENT '종류명 (일반/어린이/2인용)',
    max_passenger           TINYINT      NOT NULL DEFAULT 1  COMMENT '최대 탑승 인원',
    inspection_cycle        INT          NOT NULL DEFAULT 30 COMMENT '정기점검 주기(일)',
    bicycletype_description MEDIUMTEXT            DEFAULT NULL COMMENT '종류 설명',
    PRIMARY KEY (bicycleType_id)
) ENGINE=InnoDB COMMENT='자전거 종류';


-- -----------------------------------------------
-- 3. Station (대여소)
-- -----------------------------------------------
CREATE TABLE Station (
    station_id            INT           NOT NULL AUTO_INCREMENT,
    station_name          VARCHAR(100)  NOT NULL               COMMENT '대여소 명칭',
    station_address       VARCHAR(255)  NOT NULL               COMMENT '주소',
    station_contactnumber VARCHAR(20)            DEFAULT NULL  COMMENT '연락처',
    station_status        ENUM('운영중','휴관','정비중')
                                        NOT NULL DEFAULT '운영중',
    station_created_at    DATETIME               DEFAULT NOW(),
    station_latitude      DECIMAL(10,7)          DEFAULT NULL  COMMENT 'GPS 위도',
    station_longitude     DECIMAL(10,7)          DEFAULT NULL  COMMENT 'GPS 경도',
    station_totaldocks    INT                    DEFAULT 0     COMMENT '총 거치대 수',
    station_region_id     INT           NOT NULL               COMMENT '소속 지역 (FK)',
    PRIMARY KEY (station_id),
    CONSTRAINT fk_station_region FOREIGN KEY (station_region_id) REFERENCES Region(region_id)
) ENGINE=InnoDB COMMENT='대여소';


-- -----------------------------------------------
-- 4. Bicycle (자전거)
-- -----------------------------------------------
CREATE TABLE Bicycle (
    bicycle_id              INT           NOT NULL AUTO_INCREMENT,
    bicycle_status          ENUM('정상','대여중','정비중','분실','회수중')
                                          NOT NULL DEFAULT '정상',
    bicycle_registerd_at    DATETIME               DEFAULT NOW()  COMMENT '등록일시',
    bicycle_gps_latitude    DECIMAL(10,7)          DEFAULT NULL   COMMENT 'GPS 위도',
    bicycle_gps_longitude   DECIMAL(10,7)          DEFAULT NULL   COMMENT 'GPS 경도',
    bicycle_gps_updated_at  DATETIME               DEFAULT NULL   COMMENT 'GPS 최종 갱신일시',
    bicycleType_id          INT           NOT NULL               COMMENT '자전거 종류 (FK)',
    bicycle_station_id      INT                    DEFAULT NULL   COMMENT '현재 대여소 (FK)',
    PRIMARY KEY (bicycle_id),
    CONSTRAINT fk_bicycle_type    FOREIGN KEY (bicycleType_id)    REFERENCES BicycleType(bicycleType_id),
    CONSTRAINT fk_bicycle_station FOREIGN KEY (bicycle_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='자전거';


-- -----------------------------------------------
-- 5. User (사용자)
-- -----------------------------------------------
CREATE TABLE User (
    user_id         INT          NOT NULL AUTO_INCREMENT,
    user_name       VARCHAR(50)  NOT NULL               COMMENT '실명',
    user_birth_date DATE         NOT NULL               COMMENT '생년월일',
    user_phone      VARCHAR(20)  NOT NULL UNIQUE        COMMENT '연락처',
    user_address    VARCHAR(255)          DEFAULT NULL  COMMENT '주소',
    user_status     ENUM('정상','정지')
                                 NOT NULL DEFAULT '정상',
    user_created_at DATETIME              DEFAULT NOW(),
    PRIMARY KEY (user_id)
) ENGINE=InnoDB COMMENT='서비스 이용자';


-- -----------------------------------------------
-- 6. AdminStaff (운영관리자)
-- -----------------------------------------------
CREATE TABLE AdminStaff (
    staff_id         INT         NOT NULL AUTO_INCREMENT,
    staff_name       VARCHAR(50) NOT NULL               COMMENT '성명',
    staff_phone      VARCHAR(20) NOT NULL UNIQUE        COMMENT '연락처',
    staff_is_active  TINYINT(1)           DEFAULT 1     COMMENT '재직 여부 (1=재직, 0=퇴직)',
    staff_created_at DATETIME             DEFAULT NOW(),
    staff_station_id INT                  DEFAULT NULL  COMMENT '담당 대여소 (FK)',
    PRIMARY KEY (staff_id),
    CONSTRAINT fk_staff_station FOREIGN KEY (staff_station_id) REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='운영 관리자';


-- -----------------------------------------------
-- 7. Rental (대여이력)
-- -----------------------------------------------
CREATE TABLE Rental (
    rental_id        INT      NOT NULL AUTO_INCREMENT,
    rental_start_time DATETIME NOT NULL               COMMENT '대여 시작일시',
    rental_end_time  DATETIME          DEFAULT NULL  COMMENT '반납일시',
    rental_status    ENUM('대여중','반납','미반납')
                              NOT NULL DEFAULT '대여중',
    start_station_id INT      NOT NULL               COMMENT '시작 대여소 (FK)',
    return_station_id INT              DEFAULT NULL  COMMENT '반납 대여소 (FK)',
    rental_bicycle_id INT     NOT NULL               COMMENT '대여 자전거 (FK)',
    rental_user_id   INT      NOT NULL               COMMENT '이용 사용자 (FK)',
    PRIMARY KEY (rental_id),
    CONSTRAINT fk_rental_start_station FOREIGN KEY (start_station_id)  REFERENCES Station(station_id),
    CONSTRAINT fk_rental_end_station   FOREIGN KEY (return_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_rental_bicycle       FOREIGN KEY (rental_bicycle_id) REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_rental_user          FOREIGN KEY (rental_user_id)    REFERENCES User(user_id)
) ENGINE=InnoDB COMMENT='대여 이력';


-- -----------------------------------------------
-- 8. IncidentReport (고장/민원신고)
-- -----------------------------------------------
CREATE TABLE IncidentReport (
    incident_id          INT      NOT NULL AUTO_INCREMENT,
    incident_type        ENUM('고장','방치','분실','기타') NOT NULL,
    incident_description TEXT              DEFAULT NULL  COMMENT '신고 내용',
    incident_reported_at DATETIME          DEFAULT NOW() COMMENT '신고일시',
    incident_status      ENUM('접수','처리중','완료')
                                  NOT NULL DEFAULT '접수',
    incident_resolved_at DATETIME          DEFAULT NULL  COMMENT '처리 완료일시',
    incident_bicycle_id  INT               DEFAULT NULL  COMMENT '신고 자전거 (FK)',
    incident_user_id     INT               DEFAULT NULL  COMMENT '신고자 (FK)',
    incident_staff_id    INT      NOT NULL               COMMENT '담당 관리자 (FK)',
    PRIMARY KEY (incident_id),
    CONSTRAINT fk_incident_bicycle FOREIGN KEY (incident_bicycle_id) REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_incident_user    FOREIGN KEY (incident_user_id)    REFERENCES User(user_id),
    CONSTRAINT fk_incident_staff   FOREIGN KEY (incident_staff_id)   REFERENCES AdminStaff(staff_id)
) ENGINE=InnoDB COMMENT='고장/민원 신고';


-- -----------------------------------------------
-- 9. Maintenance (정비)
-- -----------------------------------------------
CREATE TABLE Maintenance (
    maintenance_id          INT          NOT NULL AUTO_INCREMENT,
    maintenance_type        ENUM('정기점검','수리','청소') NOT NULL,
    maintenance_description MEDIUMTEXT            DEFAULT NULL  COMMENT '정비 의뢰 내용',
    maintenance_started_at  DATETIME     NOT NULL               COMMENT '정비 의뢰일시',
    maintenance_ended_at    DATETIME              DEFAULT NULL  COMMENT '정비 완료일시',
    maintenance_status      ENUM('진행중','완료')
                                         NOT NULL DEFAULT '진행중',
    maintenance_bicycle_id  INT          NOT NULL               COMMENT '정비 자전거 (FK)',
    maintenance_incident_id INT                   DEFAULT NULL  COMMENT '연계 신고 (FK)',
    PRIMARY KEY (maintenance_id),
    CONSTRAINT fk_maintenance_bicycle  FOREIGN KEY (maintenance_bicycle_id)  REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_maintenance_incident FOREIGN KEY (maintenance_incident_id) REFERENCES IncidentReport(incident_id)
) ENGINE=InnoDB COMMENT='정비 이력';


-- -----------------------------------------------
-- 10. Retrieve (회수)
-- -----------------------------------------------
CREATE TABLE Retrieve (
    retrieve_id           INT           NOT NULL AUTO_INCREMENT,
    retrieve_latitude     DECIMAL(10,7)          DEFAULT NULL  COMMENT '발견 위치 위도',
    retrieve_longitude    DECIMAL(10,7)          DEFAULT NULL  COMMENT '발견 위치 경도',
    retrieve_location     VARCHAR(255)           DEFAULT NULL  COMMENT '발견 주소',
    retrieved_at          DATETIME               DEFAULT NOW() COMMENT '회수 시작일시',
    retrieve_completed_at DATETIME               DEFAULT NULL  COMMENT '반납 완료일시',
    retrieve_reason       ENUM('방치','미반납','구역이탈','기타')
                                        NOT NULL               COMMENT '회수 사유',
    retrieve_status       ENUM('진행중','완료')
                                        NOT NULL DEFAULT '진행중',
    retrieve_bicycle_id   INT                    DEFAULT NULL  COMMENT '회수 자전거 (FK)',
    retrieve_staff_id     INT                    DEFAULT NULL  COMMENT '담당 관리자 (FK)',
    retrieve_incident_id  INT                    DEFAULT NULL  COMMENT '연계 신고 (FK)',
    retrieve_station_id   INT           NOT NULL               COMMENT '반납 목표 대여소 (FK)',
    PRIMARY KEY (retrieve_id),
    CONSTRAINT fk_retrieve_bicycle  FOREIGN KEY (retrieve_bicycle_id)  REFERENCES Bicycle(bicycle_id),
    CONSTRAINT fk_retrieve_staff    FOREIGN KEY (retrieve_staff_id)    REFERENCES AdminStaff(staff_id),
    CONSTRAINT fk_retrieve_incident FOREIGN KEY (retrieve_incident_id) REFERENCES IncidentReport(incident_id),
    CONSTRAINT fk_retrieve_station  FOREIGN KEY (retrieve_station_id)  REFERENCES Station(station_id)
) ENGINE=InnoDB COMMENT='자전거 회수 이력';


-- -----------------------------------------------
-- 11. Penalty (패널티)
-- -----------------------------------------------
CREATE TABLE Penalty (
    penalty_id        INT      NOT NULL AUTO_INCREMENT,
    penalty_days      INT      NOT NULL               COMMENT '대여 금지 일수',
    penalty_ban_start DATE     NOT NULL               COMMENT '금지 시작일',
    penalty_ban_end   DATE     NOT NULL               COMMENT '금지 종료일',
    penalty_user_id   INT      NOT NULL               COMMENT '대상 사용자 (FK)',
    penalty_rental_id INT      NOT NULL UNIQUE        COMMENT '미반납 대여 건 (FK)',
    PRIMARY KEY (penalty_id),
    CONSTRAINT fk_penalty_user   FOREIGN KEY (penalty_user_id)   REFERENCES User(user_id),
    CONSTRAINT fk_penalty_rental FOREIGN KEY (penalty_rental_id) REFERENCES Rental(rental_id)
) ENGINE=InnoDB COMMENT='미반납 패널티';


-- -----------------------------------------------
-- 12. Allocation (재배치)
-- -----------------------------------------------
CREATE TABLE Allocation (
    allocation_id         INT          NOT NULL AUTO_INCREMENT,
    allocated_at          DATETIME              DEFAULT NOW() COMMENT '배치일시',
    allocation_note       MEDIUMTEXT            DEFAULT NULL  COMMENT '비고',
    allocation_station_id INT                   DEFAULT NULL  COMMENT '배치 대여소 (FK)',
    allocation_staff_id   INT                   DEFAULT NULL  COMMENT '배치 담당자 (FK)',
    allocation_bicycle_id INT                   DEFAULT NULL  COMMENT '배치 자전거 (FK)',
    PRIMARY KEY (allocation_id),
    CONSTRAINT fk_allocation_station FOREIGN KEY (allocation_station_id) REFERENCES Station(station_id),
    CONSTRAINT fk_allocation_staff   FOREIGN KEY (allocation_staff_id)   REFERENCES AdminStaff(staff_id),
    CONSTRAINT fk_allocation_bicycle FOREIGN KEY (allocation_bicycle_id) REFERENCES Bicycle(bicycle_id)
) ENGINE=InnoDB COMMENT='자전거 배치 이력';


SET FOREIGN_KEY_CHECKS = 1;