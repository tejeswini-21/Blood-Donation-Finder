# Project Report

## Blood Donation Finder and Emergency Request System

**Course context:** End-semester Java full-stack project  
**Stack:** Java 17, Spring Boot 3.3.5, Spring MVC, Spring Data JPA, Spring Security, Thymeleaf, Bootstrap 5, Flyway, H2 / MySQL 8.4

---

## Abstract

The Blood Donation Finder and Emergency Request System is a web application that helps a recipient or hospital locate a compatible donor without publishing that donor's phone number. Users register as donors, requesters, or hospitals. An administrator account is created only by the application seeder. The system matches red-blood-cell groups, filters by city and area, and hides donors who are unavailable, unverified, disabled, or still inside a configurable 90-day interval since their last donation. Requests move through open, accepted, fulfilled, cancelled, and expired states. Accepting a request is transactional and version-checked so two donors cannot both claim the same single-donor request. Hospitals maintain stock by blood group. The administrator verifies hospitals, blocks accounts, reviews requests, views charts built from database aggregates, and exports requests to CSV. The default profile uses an in-memory H2 database so the project runs with `mvn spring-boot:run` and no separate database install. A MySQL profile uses the same Flyway migration.

## 1. Introduction

Blood shortages are time-critical. A family that needs O negative blood in a particular city may not know which nearby donors last donated, which accounts are genuine, or which blood bank still has units. Informal forwarding of phone numbers also exposes donors who are not eligible to donate again.

This project models that workflow as a secured web application. It is a college demonstration, not a clinical system. Compatibility tables and the 90-day gap are simplified teaching rules. A real transfusion still requires blood-bank cross-matching and a physician's decision.

## 2. Problem definition

Existing informal search has four failures this project addresses:

1. Compatible donors are hard to filter by group and location at the same time.
2. Donors who donated recently can still be contacted, because eligibility is not tracked.
3. Phone numbers are visible before anyone agrees to help.
4. Hospitals and administrators have no shared record of request status or stock.

The application must persist users, requests, donations, stock, and notifications, and it must refuse actions that the caller's role does not own.

## 3. Objectives

- Register and authenticate four roles with hashed passwords and CSRF-protected forms.
- Calculate donor eligibility from the last donation date and a configurable interval (`app.donor.eligibility-days`, default 90).
- Search donors with compatibility, city, optional area priority, availability, verification, and enabled status.
- Create, accept, reject, cancel, fulfil, and expire blood requests.
- Store a donation record and update the donor when a request is fulfilled.
- Let hospitals maintain non-negative stock and see low stock below five units.
- Give administrators verification, blocking, monitoring, charts, and CSV export.
- Notify users inside the application, with email attempted only when a mail sender is available.
- Seed fictional demo data once, and keep repeated startups from duplicating it.

## 4. Scope

**In scope**

- Web UI with Thymeleaf and Bootstrap for public pages and four dashboards.
- Relational schema for users, donors, requests, responses, donations, banks, stock, and notifications.
- H2 for demonstration and MySQL 8.4 for a configured deployment.
- Unit and service tests for compatibility, eligibility, requests, stock, and security flags.

**Out of scope**

- Real laboratory cross-match, platelet or plasma rules, payment, GPS, or government identity verification.
- Production hardening such as HTTPS termination, secret rotation, and a hardened mail server. The seeded admin password is documented as development-only.

## 5. Proposed system

A recipient creates a request with patient name, blood group, units (1–10), hospital, city, area, urgency, required-by date, and a contact number. The service rejects a second open request from the same requester for the same patient and blood group. Matching donors in that city receive an in-app notification. Emergency requests are ordered ahead of ordinary ones.

A donor may accept only when the request is still open, the donor is eligible and available, and the blood groups are compatible. The request row carries a `@Version` column. The accept method runs in one transaction, re-reads the status, and fails clearly if another donor already accepted it. Multi-unit requests still record each donor response; the request is not marked fulfilled merely because the first donor accepted. Fulfilment is a separate confirmation by the requester or an authorized hospital. That step writes a `DonationRecord`, sets status to `FULFILLED`, and updates `lastDonationDate` and `totalDonations`.

A daily scheduler marks open or accepted requests as `EXPIRED` when `requiredBy` is before today.

Hospitals register in an unverified state. They cannot sign in until an administrator verifies the account. Donor and requester self-registration is verified immediately so a classroom demonstration can proceed; the administrator can still disable those accounts. Seeded unverified and disabled donors exist to show the lockout.

## 6. System architecture

```
Browser
  -> DispatcherServlet
  -> Controller (validation, model, redirects)
  -> Service interface
  -> Service implementation (transactions, rules, logging)
  -> Repository (Spring Data JPA)
  -> EntityManager / Hibernate
  -> Flyway schema (H2 or MySQL)
```

Spring Security sits in front of the controllers. Public routes are the home page, about, donor search, blood-bank search, login, and registration. `/donor/**` requires `ROLE_DONOR`, `/requester/**` requires `ROLE_REQUESTER`, `/hospital/**` requires `ROLE_HOSPITAL`, and `/admin/**` requires `ROLE_ADMIN`. A custom success handler sends each role to its dashboard. Session timeout is 30 minutes.

`GlobalExceptionHandler` maps not-found, ineligible donor, duplicate request, and unauthorized action cases onto user-visible messages instead of stack traces. Dedicated templates exist for 403, 404, and 500.

## 7. Modules

| Module | Responsibility |
| --- | --- |
| Authentication | Registration DTOs, BCrypt, login, logout, role redirect |
| Donor | Profile, availability, eligibility date, incoming requests, history |
| Requests | Create, match, accept, reject, cancel, fulfil, expire, duplicate check |
| Compatibility | `BloodCompatibilityUtil` donor and recipient maps |
| Notifications | Persist messages; optional `JavaMailSender` |
| Blood bank | Bank profile, stock upsert, low-stock flag, public search |
| Administration | Counts, verification, block, request oversight, CSV, chart data |
| Seeding | Idempotent `CommandLineRunner` for empty databases |

## 8. Database design

Normalized tables:

- `users` — identity shared by every role. Email is unique. Password column stores a BCrypt hash.
- `donors` — one-to-one with a user. Blood group, age, gender, last donation, availability, total donations.
- `blood_requests` — many-to-one requester, optional accepting donor, urgency, status, optimistic `version`.
- `request_responses` — one row per donor decision (`ACCEPTED` or `REJECTED`).
- `donation_records` — donor is required. Request is optional so a walk-in history row does not need a transient `BloodRequest`.
- `blood_banks` — optional hospital user, verified flag.
- `blood_stocks` — unique `(blood_bank_id, blood_group)`, units cannot be stored negative by the service.
- `notifications` — user, message, read flag, optional link.

Indexes cover email, city, blood group, request status, and notification user. Enumerations are stored as strings: `Role`, `BloodGroup`, `UrgencyLevel`, `RequestStatus`.

The entity relationship diagram is in `README.md`.

**Startup fix.** An earlier seeder attached donation history to blood requests that were not yet persistent, which caused Hibernate `TransientPropertyValueException`. Donation rows are now saved only after donors and requests are flushed. Historical rows set `request` to null. `DonationRecord.request` is optional. `BloodRequest.version` starts null so Spring Data inserts a new row instead of merging a transient one. Flyway still defines `version BIGINT NOT NULL DEFAULT 0`, and Hibernate assigns the version on insert.

## 9. OOP concepts used

- **Encapsulation.** Entity fields are private. Callers use getters and setters. Password hashes are never placed on registration DTOs that render back to the page.
- **Abstraction.** Controllers depend on `UserService`, `DonorService`, `BloodRequestService`, `BloodBankService`, `NotificationService`, and `AdminService`, not on repository queries.
- **Inheritance.** Controllers and services use Spring stereotypes. Domain exceptions extend `RuntimeException`. `CustomUserDetails` implements `UserDetails`.
- **Polymorphism.** Each service interface has one implementation that can be replaced in tests with Mockito.
- **Composition.** `Donor` contains a `User`. `BloodStock` contains a `BloodBank`. A request contains a requester and an optional donor.
- **Enums.** Invalid blood groups and statuses cannot be stored as free text from Java code.

## 10. Technologies

- **Spring MVC and Thymeleaf** render server-side pages and fragments for the navbar, sidebar, footer, and alerts.
- **Spring Data JPA and Hibernate** map entities and use parameterized queries, which avoids concatenated SQL.
- **Bean Validation** checks email format, Indian 10-digit mobiles that start with 6–9, donor age 18–65, and units 1–10.
- **Spring Security** provides form login, BCrypt, CSRF, and access-denied handling.
- **Flyway** versions the schema. Hibernate `ddl-auto` is `validate` on both profiles so the two tools do not both change tables.
- **Chart.js** draws admin charts from counts computed in `AdminService`, not from hardcoded series.
- **JUnit 5 and Mockito** test rules without a browser. `@SpringBootTest` checks that the context starts and the seeder inserts the admin, at least 15 donors, and at least 5 requests.

## 11. Testing

Automated tests live under `src/test/java/com/bloodfinder`.

| Class | What it checks |
| --- | --- |
| `BloodCompatibilityUtilTest` | All eight recipient groups and incompatible combinations |
| `DonorEligibilityTest` | No donation, &lt; 90 days, exactly 90 days, &gt; 90 days, unavailable, unverified, disabled |
| `BloodRequestServiceTest` | Create, duplicate, accept, second accept, reject, cancel, fulfil, expire |
| `BloodBankServiceTest` | Create stock, update stock, reject negative units |
| `SecurityTest` | BCrypt match, `ROLE_` mapping, blocked user, unverified user |
| `BloodDonationApplicationTests` | Context load and idempotent seed counts |

Command: `mvnw.cmd test`.

Manual role checks against the running server:

- Public pages return the home, about, find-donors, blood-banks, login, and register views.
- Donor, requester, hospital, and admin each land on their own dashboard.
- A donor session that requests `/admin/dashboard` is denied.
- Unverified donor `lakshmi.a_neg@example.com` and disabled donor `tarun.ab_pos@example.com` cannot sign in.
- An eligible O+ donor can accept an open compatible request. A second acceptance path is covered by the service test.
- Hospital stock update persists a new unit count.
- Admin CSV export returns `text/csv`.

## 12. Expected outcomes

After startup the home page shows database counts rather than invented marketing numbers. A requester in Vijayawada can see eligible compatible donors and can open an emergency request. The accepting donor's phone appears on that request only after acceptance. Fulfilment adds a donation row and pushes the donor's next eligibility date forward by the configured interval. Administrators can export the request table and see pending hospital verifications. Stopping the H2 process clears data; the next start seeds it again.

## 13. Limitations

- Ninety days is a single project constant. Real eligibility depends on donation type, hemoglobin, and local medical policy.
- Only red-cell compatibility is implemented.
- City and area matching is case-insensitive text, not a map.
- Email delivery depends on a mail server. Without one, only in-app notifications are stored.
- Donor and requester self-registration is auto-verified for the demo. Hospital accounts are not.
- The H2 database is in-memory. A demo restart loses requests created during the session.
- The seeded administrator password is public in this repository and must be changed before deployment.
- The UI is server-rendered. It does not offer a separate mobile API.

## 14. Future enhancements

- SMTP and SMS templates for emergency requests.
- Distance-based ranking and map display.
- Separate compatibility rules for platelets and plasma.
- Stronger identity checks for donors and hospitals.
- Audit trail for verification and block actions.
- Optional file storage for hospital license documents.
- Remember-me tokens and password reset, still without exposing hashes.

## 15. Conclusion

The project meets the assigned workflow: a Java 17 Spring Boot application with a real database, role-based security, compatibility and eligibility rules, a locked request lifecycle, blood-bank stock, administrator reports, and tests that exercise those rules. The interface uses a blood-red healthcare theme, shared Thymeleaf fragments, and dashboards whose numbers come from the signed-in user's data. It is suitable for an end-semester demonstration on H2, and the MySQL profile is ready when environment variables are supplied.

## References

- Spring Boot 3.3 reference documentation
- Spring Security reference (form login, CSRF, method and request authorization)
- Jakarta Persistence and Hibernate 6 optimistic locking
- Flyway database migrations
- Standard ABO and Rh red-cell transfusion compatibility used as the teaching table in `BloodCompatibilityUtil`
