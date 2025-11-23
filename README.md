# 📂 Project: Parallax Connect

**Competition:** GradientHQ "Build Your Own AI Lab"
**Deadline:** Nov 30, 2025
**Role:** Flutter Developer (Team of 1 + Friend's Hardware)

## 🏆 The Core Concept

**"Parallax Connect: The Sovereign AI Interface"**

* **Tagline:** *"Powered by Gradient. Hosted by You. Accessible Anywhere."*
* **The Pitch:** A Universal "Bring Your Own Device" Client that turns a single Parallax-enabled GPU into a private, multi-tenant AI Cloud for family or field teams. It decouples the *Interface* (Mobile) from the *Compute* (GPU).

---

## 🏗️ Technical Architecture

### 1. Hardware Stack

* **Server Node (The Brain):** Friend's Laptop with **RTX 4060 (8GB VRAM)**.
  * **Mode B (Local):** Uses **Local LAN/Hotspot** for 100% offline, air-gapped access.

---

## ⚔️ The Winning Narrative (Judging Criteria)

### 1. "Impactful Application"

* **Problem:** High-quality AI is either stuck on a desktop or locked behind Cloud subscriptions/privacy violations.
* **Solution:** Parallax Connect democratizes the GPU. It allows a user to carry their "Home Lab" in their pocket.
* **The Flex:** "Pocket-H100" — One GPU serves the whole family/team simultaneously via Parallax's scheduler.

### 2. "Creative Setup"

* **Remote/Local Switch:** The app seamlessly toggles between Ngrok (Internet) and Local IP (Offline). The video demo will show the internet being cut, and the app switching to Local Mode instantly.
* **Vision Pipeline:** Instead of running vision on the phone, we send the image to the RTX 4060. This proves Parallax can handle multi-modal inputs.

### 3. Why Parallax? (vs Ollama)

* **Argument:** We chose Parallax for **Concurrency**. Unlike Ollama (which typically queues requests), Parallax uses **Request-Time Scheduling** and **Continuous Batching**. This allows multiple family members to query the RTX 4060 at the same time without crashing the server.

---

## 📱 App Features (Flutter)

1. **Chat Interface:** Standard text streaming.
2. **Vision Mode:** Camera capture -> Send Base64 to Server -> Parallax Vision Model -> Return Analysis.
3. **Connection Manager:** A settings page with a toggle:
    * 🔘 **Remote Mode** (Input: Ngrok URL)
    * 🔘 **Local Mode** (Input: 192.168.X.X)
4. **UI Detail:** A "Powered by Gradient Parallax" badge/status indicator to impress judges.

---

## 📅 The 7-Day Sprint Plan

* **Day 1:** Setup Friend's RTX 4060 remotely. Install Parallax, Moondream, Ngrok. Create `server.py` (FastAPI).
* **Day 2-4:** Build Flutter UI (Chat, Camera, Settings Toggle).
* **Day 5:** Integration Test (Send image from phone -> Get text from Parallax).
* **Day 6:** **Filming.** (Scenes: Remote usage in public, cutting internet, switching to local usage).
* **Day 7:** Edit & Submit.
