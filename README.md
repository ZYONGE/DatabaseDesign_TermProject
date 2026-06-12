<div align="center">

# 시흥시 공공 자전거 대여 서비스 — DB 설계

Final team project for the **Database Design** course

</div>

<img src="https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white"/>
<img src="https://img.shields.io/badge/MySQL%20Workbench-4479A1?style=for-the-badge&logo=mysql&logoColor=white"/>
<img src="https://img.shields.io/badge/DBeaver-382923?style=for-the-badge&logo=dbeaver&logoColor=white"/>

---

## Project Overview

**Course:** Database Design (데이터베이스 설계)

**University:** Tech University of Korea (TUK)

**Type:** Final Team Project

This repository contains the MySQL 8.0 relational database design and implementation for a **public bicycle rental service in Siheung City (시흥시)**, Gyeonggi Province.

The system models the full service lifecycle — from member registration and bicycle rental to incident reporting and bicycle retrieval — using **12 normalized entities**.

---

## Tech Stack

### Language

- SQL

### Database

- MySQL 8.0
- DBeaver (Database Management Tool)
- MySQL Workbench (Database Design Tool)

### Tools

- Git
- GitHub
- Visual Studio Code

---

## Features

This database design covers the following core functions:

- **Member Management** — sign-up, account status, and suspension handling
- **Bicycle Management** — inventory, status, and type management (standard / children's / tandem)
- **Station Management** — regional stations and real-time placement tracking
- **Rental & Return** — start/end station, elapsed time, and distance calculation
- **Penalty System** — automated penalty (ban period) for unreturned bicycles
- **Operations Management** — maintenance logs, incident reports, and admin staff records
- **Bicycle Retrieval** — GPS-based out-of-area detection and abandoned bicycle retrieval
- **Bicycle Allocation** — demand-driven placement strategy and allocation history

---

## Entity List (12 tables)

| # | Entity | Description |
|---|--------|-------------|
| 1 | `Region` | Administrative district (동 unit) |
| 2 | `BicycleType` | Bicycle type (standard / children's / tandem) |
| 3 | `Station` | Rental station |
| 4 | `Bicycle` | Bicycle entity |
| 5 | `User` | Service member |
| 6 | `AdminStaff` | Operations staff |
| 7 | `Rental` | Rental history |
| 8 | `IncidentReport` | Incident / complaint report |
| 9 | `Maintenance` | Maintenance history |
| 10 | `Retrieve` | Bicycle retrieval history |
| 11 | `Penalty` | Unreturned bicycle penalty |
| 12 | `Allocation` | Bicycle placement history |

---

## Project Structure

```
데이터베이스설계_기말프로젝트/
├── docs/
│   ├── erd/                 # ERD diagrams (DFD, logical, physical)
│   ├── design.md            # DB design document (entities, relations, triggers)
│   ├── crud_matrix.md       # CRUD matrix by feature
│   └── views.md             # VIEW 명세
├── sql/
│   ├── ddl/
│   │   └── DDL.sql       # CREATE TABLE, indexes, triggers
│   ├── dml/
│   │   └── DML.sql   # Sample / test data
│   ├── views/
│   │   └── views.sql        # VIEW 정의 (source of truth)
│   └── Query/
│       └── Query.sql        # Operational queries (dashboard, monitoring)
├── LICENSE                  # MIT License
├── .gitignore
└── README.md
```

---

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.


## Author

Name: 김지용(팀장), 김민준, 양예진. 이준석, 윤하원, 천세윤

## Motivation

DataBaseDesign TermProject
