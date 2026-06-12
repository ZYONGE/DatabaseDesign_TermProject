# Report Replacement Checklist

Use this file when re-exporting the final report PDF. Each row identifies which old report
pages are superseded and which replacement source file to use.

## Files in this directory

| File | Replaces | Notes |
|------|----------|-------|
| `appendix_DDL.sql` | Report appendix DDL (approx. pp. 60–65) | Verbatim copy of current `sql/ddl/DDL.sql` |
| `appendix_views.sql` | Report appendix VIEW definitions (approx. pp. 38–45) | Verbatim copy of current `sql/views/views.sql` |
| `table_spec_corrected.md` | Report Table 기술서 | All 12 tables regenerated from DDL catalog; see corrections below |
| `CHANGES.md` | This file | Checklist for team when re-exporting |

---

## Known errors in the existing report (not auto-fixable in PDF)

### DDL appendix (pp. 60–65)
- The appended DDL used **old, unprefixed column names** (e.g., `type_id`, `station_id`,
  `region_id`, `user_id`, `bicycle_id`, `ban_start`, `ban_end`, etc.).
- Replace with `appendix_DDL.sql` (属性명 전역 유일 적용 버전).

### VIEW appendix (pp. 38–45)
- The VIEW definitions referenced old column names.
- Replace with `appendix_views.sql`.

### Table 기술서
The following semantic errors existed in the original Table 기술서 (some of which may also
appear in the physical ERD diagram). Fix all of them using `table_spec_corrected.md`:

| Table | Error | Correction |
|-------|-------|------------|
| Bicycle | Default value listed as `'대여가능'` | Correct default is `'정상'`; ENUM is `('정상','대여중','정비중','분실','회수중')` — `'대여가능'` never existed |
| Retrieve | `retrieve_reason` default shown as `'무단방치'` | `retrieve_reason` has **no default** (NOT NULL only); ENUM is `('방치','미반납','구역이탈','기타')` |
| Retrieve | `retrieve_status` listed as `'회수요청'` | Correct ENUM is `('진행중','완료')`, default `'진행중'`; `'회수요청'` does not exist |
| Retrieve | Phantom column `found_region_id` in remarks | Column does not exist in DDL — remove |
| Maintenance | "기본 상태 정비중" described as an ENUM value | ENUM is `('진행중','완료')`, default `'진행중'`; `'정비중'` is a **Bicycle** status, not Maintenance |
| Allocation | `from_station_id` / `to_station_id` in remarks | Allocation uses a **single** `allocation_station_id`; no from/to split exists |
| Maintenance | `staff_id` column shown in Table 기술서 | `Maintenance` has **no** `staff_id` — maintenance is outsourced (외주 원칙) |
| station_status | Marked nullable in some tables | DDL: NOT NULL |
| user_status | Marked nullable | DDL: NOT NULL |
| rental_status | Marked nullable | DDL: NOT NULL |
| incident_status | Marked nullable | DDL: NOT NULL |
| retrieve_reason | Marked nullable | DDL: NOT NULL (no default) |
| retrieve_status | Marked nullable | DDL: NOT NULL |
| start_station_id (Rental) | Marked nullable | DDL: NOT NULL |
| penalty_rental_id | UNIQUE constraint missing | DDL: NOT NULL UNIQUE |

### Physical ERD
- The physical ERD should reflect the prefixed column names (e.g., `station_region_id` not
  `region_id`, `rental_user_id` not `user_id`, etc.).
- Re-export the ERD from MySQL Workbench after applying the current `DDL.sql`.

### bicycle_registered_at
- The column in the current DDL is `bicycle_registered_at` (correct spelling).
- Earlier versions of the report may spell it `bicycle_registerd_at` (missing 'e').
  The DDL has been corrected; update any remaining occurrences in the report to
  `bicycle_registered_at`.
