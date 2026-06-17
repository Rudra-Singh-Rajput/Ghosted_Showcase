# Ghosted 👻

> An anonymous, high-fidelity social network built for university students to share thoughts, ask questions, and chat without social pressure.

---

## 🌌 Project Overview
**Ghosted** is a mobile application developed using **Flutter** and **Firebase** that provides a safe, anonymous space for university campus interaction. The app uses a premium, dark-mode design with glowing purple and orange aesthetics to deliver a highly responsive and gamified social experience.

*Note: The actual source code of this project is private to protect proprietary implementation details. This repository acts as a public showcase of the product features, architecture, and design.*

---

## 🎨 User Interface & Aesthetics
The application uses a custom visual style designed to feel premium, mysterious, and modern:
*   **Aesthetic Theme:** Sleek dark-mode background (`#0A0A0A`) with custom-colored glassmorphism containers.
*   **Accents:** Vibrant neon purple/magenta (`#BD00FF`) and spectral orange (`#FF8700`).
*   **Typography:** Google Fonts integration (Outfits for headlines, Inter for body copy, Inconsolata for system elements).

---

## ⚡ Core Features

### 1. The Ghost Board (Main Feed)
*   **Anonymous Whispers:** Students can post text and image/video "whispers" into the campus void.
*   **Vaporizing Content:** Whispers decay naturally over 24 hours. The text blurs and fades as it gets closer to vanishing.
*   **Locked Secrets (The Payoff):** Users can set up "polls" with locked secrets. When the community vote goal is reached, the secret payload is automatically revealed.

### 2. Direct Messaging & Vapor Bubbles
*   **Ephemeral Chatting:** One-on-one anonymous chat rooms.
*   **Vapor Bubbles:** Chat messages decay and self-destruct after 24 hours to ensure privacy.
*   **Downtime Sleep Mode:** The network goes dark between 11:50 PM and midnight daily, prompting users to disconnect.

### 3. Gamified Resonance System
*   **Resonance Points (XP):** Earn XP by posting, commenting, and maintaining daily logins.
*   **Spectral Ranks:** Level up from a basic **Phantom** to **Wraith**, **Nightstalker**, and finally **Void Sovereign**.
*   **Activity Streaks:** Tracks daily usage and rewards bonus resonance points for continuous daily participation.

---

## 🛠️ Architecture & Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Database & Backend:** Cloud Firestore (NoSQL)
*   **Authentication:** Firebase Auth (Domain-locked login for `@adaniuni.ac.in`)
*   **Media Hosting:** Cloudinary API integration (optimized image/video uploads)
*   **Animations:** `flutter_animate` for smooth transition effects

---

## 📝 License
This project is proprietary. All rights reserved. 
The source code is hosted privately and is not open for public redistribution or commercial usage.
