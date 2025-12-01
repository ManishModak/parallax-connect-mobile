# Server Setup Guide

This guide will help you set up the Parallax Connect server on your computer.

## ✅ Prerequisites

Before you begin, make sure you have:

1. **Python Installed**: Download Python 3.10 or newer from [python.org](https://www.python.org/downloads/).
    * *Note during installation*: Check the box that says **"Add Python to PATH"**.
2. **Parallax Running**: You must have the main Parallax AI software installed and running.
    * Run `parallax run` in a separate terminal window.

---

## 🛠️ Step-by-Step Installation

### Step 1: Download the Server

If you haven't already, download this project folder to your computer.
* **Option A**: Download ZIP and extract it.
* **Option B**: Use Git: `git clone https://github.com/ManishModak/parallax-connect.git`

### Step 2: Open a Terminal

1. Open the folder `parallax-connect`.
2. Right-click in the empty space and select **"Open in Terminal"** (or "Open PowerShell window here").

### Step 3: Install Dependencies

Run this command to install the necessary software libraries:

```bash
pip install -r requirements.txt
```

*If you see a warning about "pip version", you can ignore it.*

### Step 4: Start the Server

Run the interactive launcher:

```bash
python run_server.py
```

You will see a menu like this:

```
🚀 Parallax Connect Server Launcher
===================================

Select Operation Mode:
  1. Normal (Default) - Standard operation
  2. Debug            - Verbose logging & auto-reload
  3. Mock             - Simulated responses (no GPU required)

Enter choice [1]:
```

* **Press Enter** to select Normal mode.
* You may be asked to set a **Password**. This is optional but recommended if you plan to share the connection.

### Step 5: Connect

Once the server starts, you will see a big **QR Code** in the terminal.

1. Open the **Parallax Connect** app on your phone.
2. Tap **"Scan QR Code"**.
3. Point your camera at the screen.

---

## 🌐 Connection Modes

The server supports two ways to connect:

### 1. Local Mode (Fastest) 🏠

- **How**: Your phone and computer must be on the **same Wi-Fi network**.
* **Pros**: Super fast, no internet required.
* **Cons**: Only works at home.

### 2. Cloud Mode (Anywhere) ☁️

- **How**: Uses a secure tunnel (Ngrok) to connect over the internet.
* **Pros**: Works from anywhere (coffee shop, 5G, etc.).
* **Cons**: Requires a free Ngrok account.

**To enable Cloud Mode:**

1. Sign up at [ngrok.com](https://dashboard.ngrok.com/signup).
2. Copy your **Authtoken**.
3. Run this command in your terminal:

    ```bash
    ngrok config add-authtoken YOUR_TOKEN_HERE
    ```

4. Restart the server (`python run_server.py`). It will now generate a Cloud URL.

---

## ❓ Common Issues

**Q: The QR code is too big/small.**
A: Resize your terminal window or scroll up.

**Q: "Command not found: python"**
A: Try using `python3` instead. If that fails, reinstall Python and ensure **"Add to PATH"** is checked.

**Q: The app says "Connection Refused".**
A:
* Check if your firewall is blocking Python.
* Ensure your phone is on the same Wi-Fi (for Local Mode).
* Try using Cloud Mode (Ngrok) if local connection fails.
