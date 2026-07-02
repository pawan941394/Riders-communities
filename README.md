# 🏍️ Riders Communities

<div align="center">

![Riders Communities Banner](https://img.shields.io/badge/Riders-Communities-0A66C2?style=for-the-badge&logo=apachekafka&logoColor=white)
![Built With Flutter](https://img.shields.io/badge/Flutter-Mobile_App-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Backend](https://img.shields.io/badge/Backend-Django_%2B_FastAPI-092E20?style=for-the-badge&logo=django&logoColor=white)
![Website](https://img.shields.io/badge/Website-Available-FF6F00?style=for-the-badge&logo=googlechrome&logoColor=white)

**A rider-first community platform for delivery workers to share real problems, get peer support, and access structured help.**

</div>

---

## ✨ Vision

Build a trusted digital community where delivery riders can post work-life issues, receive useful responses quickly, and discover practical support resources.

---

## 🚀 Launch Scope (V1)

- 🔐 Rider-only community (login required)
- 📝 Text + image posts (1 image max)
- 💬 Comments + replies
- 🕶️ Optional anonymous posting (off by default)
- 🎯 Feed filters: city, company, language, tags
- 🔎 Search across posts, comments, and tags
- 🧩 Common problem forms:
  - Payment/Earnings
  - Account Blocked/Suspended
  - Safety/Accident
- ⚡ EV section with lead form
- 🔔 Push + in-app notifications
- 🛡️ Report + block controls

---

## 📍 Target Launch Region

- Delhi
- Gurgaon
- Noida

---

## 📊 Product KPIs (First 60 Days)

- Weekly Active Riders (WAR)
- Percentage of posts getting at least one helpful comment within 24 hours

---

## 🛠️ Tech Stack

- **Frontend:** Flutter (Android-first for V1)
- **Backend:**
  - Django (auth authority, admin, moderation, migrations)
  - FastAPI (community APIs, feed, search, performance endpoints)
- **Database:**
  - Development: SQLite
  - Production: PostgreSQL
- **Notifications:** FCM
- **Analytics:** Firebase Analytics + backend event logs

---

## 🧠 Architecture Notes

- API versioning from day one: `/api/v1/...`
- Django issues auth tokens; FastAPI validates them
- Image storage in V1 is server disk (file path stored in DB)
- Weekly manual backups planned for DB + uploads
- Dynamic backend-controlled cards supported (updates/announcements now, ads later)

---

## 🌿 Project Branches

### 1) Backend Branch
- 🔗 **Open Branch:** [master](https://github.com/pawan941394/Riders-communities/tree/master)
- 📦 **Download ZIP:** [Download Backend](https://github.com/pawan941394/Riders-communities/archive/refs/heads/master.zip)

### 2) Mobile App Branch
- 🔗 **Open Branch:** [mobile_app](https://github.com/pawan941394/Riders-communities/tree/mobile_app)
- 📦 **Download ZIP:** [Download Mobile App](https://github.com/pawan941394/Riders-communities/archive/refs/heads/mobile_app.zip)

### 3) Website Branch
- 🔗 **Open Branch:** [website](https://github.com/pawan941394/Riders-communities/tree/website)
- 📦 **Download ZIP:** [Download Website](https://github.com/pawan941394/Riders-communities/archive/refs/heads/website.zip)

---

## 📚 Project Docs

- Product requirements and execution plan: [`rider-community-app-prd.md`](./rider-community-app-prd.md)

---

## 🤝 Collaboration / Purchase

If anyone wants to **collaborate** on this project or wants to **buy this project**, feel free to connect with me:

- 💼 LinkedIn: [Pawan Kumar](https://www.linkedin.com/in/pawan941394/)
- ▶️ YouTube: [Pawan Kumar Channel](https://www.youtube.com/@Pawankumar-py4tk)

I’m open to partnerships, development collaboration, and project handover discussions.
