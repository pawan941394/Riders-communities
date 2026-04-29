# Riders Communities

A rider-first community app for delivery workers to share real problems, get peer support, and access structured help.

## Vision

Build a trusted digital community where delivery riders can post work-life issues, receive useful responses quickly, and discover practical support resources.

## Launch Scope (V1)

- Rider-only community (login required)
- Text + image posts (1 image max)
- Comments + replies
- Optional anonymous posting (off by default)
- Feed filters: city, company, language, tags
- Search across posts, comments, and tags
- Common problem forms:
  - Payment/Earnings
  - Account Blocked/Suspended
  - Safety/Accident
- EV section with lead form
- Push + in-app notifications
- Report + block controls

## Target Launch Region

- Delhi
- Gurgaon
- Noida

## Product KPIs (First 60 Days)

- Weekly Active Riders (WAR)
- Percentage of posts getting at least one helpful comment within 24 hours

## Tech Stack

- Frontend: Flutter (Android-first for V1)
- Backend:
  - Django (auth authority, admin, moderation, migrations)
  - FastAPI (community APIs, feed, search, performance endpoints)
- Database:
  - Development: SQLite
  - Production: PostgreSQL
- Notifications: FCM
- Analytics: Firebase Analytics + backend event logs

## Architecture Notes

- API versioning from day one: `/api/v1/...`
- Django issues auth tokens; FastAPI validates them
- Image storage in V1 is server disk (file path stored in DB)
- Weekly manual backups planned for DB + uploads
- Dynamic backend-controlled cards supported (updates/announcements now, ads later)

## Project Docs

- Product requirements and execution plan: [`rider-community-app-prd.md`](./rider-community-app-prd.md)

## 4-Week Execution Plan

### Week 1
- Foundation setup (Flutter + Django + FastAPI)
- Auth flows
- Core user/profile models
- Admin skeleton

### Week 2
- Community posting and feed
- Comments/replies/helpful marking
- Anonymous posting rules
- Filters and tag system

### Week 3
- Full search (posts/comments/tags)
- Safety controls (report/block/critical handling)
- Notifications
- Default problem forms

### Week 4
- EV lead flow
- Dynamic cards delivery
- Analytics wiring
- Bug bash and launch readiness (close all P0/P1)

## Current Status

- [x] PRD finalized
- [ ] App scaffolding started
- [ ] Backend services initialized
- [ ] CI/CD setup
- [ ] V1 launched

## Contribution (Initial)

This repository currently tracks product planning and will soon include implementation code.  
Development process will follow:

1. Finalize scope from PRD
2. Build MVP in weekly milestones
3. Track bugs by priority (P0/P1/P2)
4. Launch only when all P0/P1 are resolved
