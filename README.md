# Ghosted ðŸ‘»

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=flat-square&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-Media-3448C5?style=flat-square&logo=cloudinary&logoColor=white)](https://cloudinary.com)
[![Status](https://img.shields.io/badge/Status-Archived%20Project-FF8700?style=flat-square)](https://ghosted-2c50e.web.app)

An anonymous campus social web application built with **Flutter** and **Firebase** for Adani University students.

---

### Links
* **Interactive Demo:** [https://ghosted-2c50e.web.app/demo/](https://ghosted-2c50e.web.app/demo/)
* **Project Status / Farewell Page:** [https://ghosted-2c50e.web.app](https://ghosted-2c50e.web.app)
* **Showcase Repository:** [https://github.com/Rudra-Singh-Rajput/Ghosted_Showcase](https://github.com/Rudra-Singh-Rajput/Ghosted_Showcase)

---

## ðŸ“Œ Project Overview

**Ghosted** was my first major full-stack project, built during my time at **Adani University**. 

The concept was straightforward: social media and campus group chats often come with social anxiety, peer judgment, and permanent digital footprints. Ghosted was built to give students a lighthearted, pressure-free space where they could speak their minds, ask honest questions, share campus stories, or watch videos togetherâ€”completely anonymously.

To ensure safety and relevance, accounts were strictly restricted to verified `@adaniuni.ac.in` student email addresses, and all content was designed to automatically disappear after 24 hours.

---

## ðŸš€ Key Features

* **Anonymous Campus Feed (Ghost Board):** Students could post anonymous text and photo whispers. Posts decayed over 24 hours so discussions stayed relevant and temporary.
* **Hauwa / Confession Board:** A dedicated section for campus confessions, thoughts, and advice, organized with category tags (`#Hostel`, `#Exams`, `#Crush`, `#Faculty`).
* **Ephemeral Chat & View-Once Photos:** 1-on-1 and group chats with self-destructing message bubbles and a 5-second view-once photo viewer.
* **Happy Watch (Synchronized Video Room):** A real-time synchronized video room where students in different hostel rooms could watch YouTube videos together with synchronized play/pause and live chat reactions.
* **Campus Stories:** 24-hour stories with floating text captions and music tags.
* **Yearbook & Streaks:** An anonymous directory of student avatars categorized by university department (`ICT`, `Design`, `Engineering`) with daily activity streaks.
* **Custom Themes:** Multiple UI themes including Ghosted Orange (Warm Ember), Cosmic Purple, Aurora Teal, and a Comic Panel style.

---

## ðŸ› ï¸ Tech Stack

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Frontend** | **Flutter Web & Mobile (Dart)** | Custom dark-mode UI, responsive layouts, animations |
| **Database** | **Cloud Firestore** | Real-time streams for feeds, chats, and synchronized rooms |
| **Authentication** | **Firebase Auth** | Domain-restricted login (`@adaniuni.ac.in`) |
| **Media Pipeline** | **Cloudinary** | Image compression and media hosting |
| **Hosting** | **Firebase Hosting** | Fast global CDN delivery |

---

## ðŸ’¡ What I Learned (First Project Reflections)

Building Ghosted from scratch was a huge learning curve and gave me practical hands-on experience:
* **State Management in Flutter:** Managing complex multi-screen state across feeds, chats, and real-time watchers.
* **NoSQL Database Modeling:** Designing efficient Firestore document structures and queries while keeping read/write limits in mind on the free tier.
* **Real-Time Synchronization:** Implementing sub-second playback and chat state sync for the Happy Watch feature.
* **Security & Ephemeral Logic:** Setting up domain-locked authentication and automated 24-hour TTL data cleanup policies.
* **UI/UX Engineering:** Designing a cohesive dark aesthetic with custom themes, glassmorphism, and responsive components.

---

## ðŸ”’ Project Status & Source Code Note

The live backend service has been officially retired and shut down to manage database resources. 

The original core app codebase is maintained privately to protect student privacy and proprietary configs. This public repository serves as project documentation and hosts the interactive frontend showcase demo.

---

<p align="center">
  Built by <strong>Rudra Singh Rajput</strong> â€¢ Adani University (2024â€“2026)
</p>


