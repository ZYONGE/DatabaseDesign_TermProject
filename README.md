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

The system models the full service lifecycle — from member registration and bicycle rental to payment processing, mileage management, incident reporting, and bicycle retrieval — using **14 normalized entities**.

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
- **Bicycle & Dock Management** — inventory, real-time status, and placement tracking
- **Rental & Return** — start/end station, elapsed time, and distance calculation
- **Payment & Mileage** — charge settlement and point earn/use/history management
- **Fare Policy Management** — base fare, per-minute rate, and versioned policy history
- **Operations Management** — maintenance logs, incident reports, and admin staff records
- **User Experience** — post-rental reviews and ratings
- **Bicycle Retrieval** — out-of-area and abandoned bicycle retrieval history

---

## Entity List (14 tables)

| # | Entity | Description |
|---|--------|-------------|
| 1 | `Region` | Administrative district (동 unit) |
| 2 | `Station` | Rental station |
| 3 | `Dock` | Individual bicycle slot |
| 4 | `Bicycle` | Bicycle entity |
| 5 | `FarePolicy` | Fare policy version |
| 6 | `User` | Service member |
| 7 | `Rental` | Rental history |
| 8 | `Payment` | Payment history |
| 9 | `MileageHistory` | Mileage earn/use history |
| 10 | `Review` | Rental review |
| 11 | `AdminStaff` | Operations staff |
| 12 | `IncidentReport` | Incident / complaint report |
| 13 | `Maintenance` | Maintenance history |
| 14 | `Retrieve` | Bicycle retrieval history |

---

## Project Structure

```
데이터베이스설계_기말프로젝트/
├── docs/
│   ├── erd/                 # ERD diagrams (MySQL Workbench .mwb, PNG exports)
│   └── design.md            # DB design document (entities, relations, triggers)
├── sql/
│   ├── ddl/
│   │   └── schema.sql       # CREATE TABLE, indexes, triggers
│   ├── dml/
│   │   └── seed.sql         # Sample / test data
│   └── queries/
│       └── queries.sql      # Operational queries (dashboard, monitoring)
├── LICENSE                  # MIT License
├── .gitignore
└── README.md
```

---

## License

This project is licensed under the MIT License.

See the [LICENSE](LICENSE) file for details.


## Author

Name: Jiyong Kim (ZYONGE)  
Profile: https://github.com/ZYONGE  

## Motivation

Please give me A+!!!!!!
