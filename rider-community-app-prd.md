# Rider Community App PRD (V1)

## Problem Statement
Delivery riders in Delhi NCR (`Delhi`, `Gurgaon`, `Noida`) face daily job-related problems (earnings, account blocks, safety, operations) but do not have a focused rider-only platform for fast peer help and structured support. Generic social platforms are noisy and not optimized for city/company-specific rider problems.

## Solution
Build an Android-first rider community app using `Flutter` where riders can:
- sign up and join a public rider feed,
- post text/image problems,
- get comments/replies from other riders,
- filter feed by city/company/language/tags,
- use optional anonymous posting,
- submit structured default problem forms,
- access EV lead section for buy/rent support.

Backend stack:
- `Django`: auth authority, admin/moderation/control panel, migrations.
- `FastAPI`: core community APIs (write/read), feed, search, high-speed query endpoints.
- Dev DB: `SQLite`; Prod DB: `PostgreSQL`.
- API versioning from day one: `/api/v1/...`.

## User Stories (Condensed Core Set)
1. As a rider, I want to sign up with phone/email/password/photo so I can join a trusted rider-only community.
2. As a rider, I want to log in with email+password so access is simple and low-cost.
3. As a rider, I want to post text and one image so I can explain issues clearly.
4. As a rider, I want to comment/reply so I can get and provide solutions.
5. As a rider, I want city/company filters so I see relevant posts.
6. As a rider, I want optional anonymous posting so I can share sensitive issues safely.
7. As an admin, I want identity visibility for anonymous posts so abuse can be controlled.
8. As a rider, I want common-problem forms so I can quickly submit recurring issue types.
9. As a rider, I want EV interest form so team can help with buy/rent options.
10. As a rider, I want push + in-app notifications for comments/replies.
11. As admin, I want report/block + moderation tooling to maintain community safety.
12. As product owner, I want KPI tracking (WAR + helpful response rate) to measure impact.

## Locked Product Decisions
- Target users: delivery riders only.
- Feed visibility: public to all logged-in riders.
- Feed order: latest first.
- Post types: text + image (max 1 image/post, compressed, size capped).
- Anonymous: optional, default OFF; admins can still see identity.
- Location/company metadata: city mandatory; company from predefined list + `Other`.
- Cold start: show latest NCR posts.
- Languages: Hindi + English UI; auto-translation for post text only in v1 + "see original".
- Engagement: comments + replies; users can mark multiple comments helpful.
- Edit rule: edit allowed only within 15 min; show edited label.
- Delete rule: soft delete (hidden to users, retained for admin).
- Signup: required `phone + email + password + photo`; login `email + password`.
- Verification model: soft approach for now (growth-first).
- Safety: report + block user; critical incident queue + emergency contact display.
- Moderation SLA: 12 hours for reported content.
- Search: full search in v1 (`posts + comments + tags`), simple relevance.
- Tags: suggested + user-created; max 3 tags/post; banned-word filter.
- Notifications: FCM push + in-app.
- Monetization at launch: no ads shown, but dynamic backend card system ready.
- Dynamic cards (admin): schedule, audience targeting, priority ordering, expiry.
- EV flow: lead form only (name + phone + city), team follow-up.
- Profile visibility: name + photo + city + company.
- Consent: mandatory Terms + Privacy + Community Guidelines.
- Password recovery: email reset only.
- Admin roles: single admin role in v1.
- Access model: no guest mode; login required.
- Launch model: direct public release in 4 weeks; all P0/P1 bugs must be closed.
- Infra: launch on VPS, migrate to AWS when growth/reliability trigger hits.
- Migration trigger: either 10k riders OR infra incidents threshold reached.
- Analytics: Firebase Analytics + backend event logs; 12-15 key events.

## Architecture Decisions
- Django owns:
  - user/auth authority (token issue),
  - admin panel + moderation workflows,
  - schema migrations,
  - legal/policy acceptance records.
- FastAPI owns:
  - community read/write APIs (posts/comments/tags/forms/notifications),
  - feed/filter/search endpoints,
  - performance-critical APIs for Flutter.
- Token model:
  - Django issues token; FastAPI validates and enforces auth.
- Storage:
  - Images on server disk (v1 cost control), store file paths in DB.
- Backups:
  - weekly manual backup (DB + uploads), with explicit owner checklist.

## Testing Decisions
- Behavior-first testing focus:
  - auth/signup/login validation,
  - post/comment/reply flow,
  - anonymous visibility rules,
  - feed filter correctness,
  - search correctness across posts/comments/tags,
  - report/block + moderation action handling,
  - push/in-app notification triggers,
  - default problem form submissions,
  - EV lead capture flow.
- Release gate:
  - no open P0/P1 bugs at launch.

## Out of Scope (Launch)
- iOS release.
- chat/messaging.
- video posts.
- advanced recommendation ranking.
- automated rider ID verification enforcement.
- ads live monetization (engine ready, ads off).
- AWS-first production architecture.

## 4-Week Execution Plan

### Week 1 - Foundation + Auth + Core Models
- Set up Flutter Android app scaffold + localization base.
- Set up Django + FastAPI services and shared DB schema strategy.
- Implement signup/login/password reset.
- Implement profile, city/company metadata.
- Implement consent capture (ToS/Privacy/Guidelines).
- Create admin skeleton for moderation + dynamic cards.

### Week 2 - Community Core
- Build create post (text/image), feed listing (latest first), post details.
- Implement comments/replies and helpful marking.
- Add anonymous posting behavior with admin identity visibility.
- Implement edit window (15 min) + soft delete.
- Add city/company/tag model and filtering.

### Week 3 - Search + Safety + Notifications
- Implement full search (`posts + comments + tags`) with basic relevance.
- Add report + block functionality.
- Build critical incident priority handling path.
- Integrate FCM + in-app notifications for comment/reply events.
- Add common-problem forms (3 default types).

### Week 4 - EV + Dynamic Cards + QA + Release
- Build EV listing + lead form (`name/phone/city`).
- Implement dynamic card serving (schedule/target/priority/expiry) in backend + app rendering.
- Wire analytics (Firebase + backend logs, 12-15 events).
- Run bug bash + close all P0/P1.
- Launch directly to public (Android).
