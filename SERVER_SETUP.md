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

### Step 3: Create a Virtual Environment (Recommended)

A virtual environment keeps your project dependencies isolated from your system Python.

**Creating the virtual environment:**

**Windows:**

```bash
python -m venv venv
```

**macOS/Linux:**

```bash
python3 -m venv venv
```

**Then activate it:**

**Windows PowerShell:**

```powershell
.\venv\Scripts\Activate.ps1
```

**Windows CMD:**

```cmd
venv\Scripts\activate.bat
```

**macOS/Linux:**

```bash
source venv/bin/activate
```

*You should see `(venv)` appear at the start of your terminal prompt.*

**Already have a venv folder?** Skip the creation command and just activate:
* **Windows PowerShell**: `.\venv\Scripts\Activate.ps1`
* **Windows CMD**: `venv\Scripts\activate.bat`
* **macOS/Linux**: `source venv/bin/activate`

**Troubleshooting Windows Activation:**
* **If the script opens in Notepad**: You're likely in CMD instead of PowerShell. Use `venv\Scripts\activate.bat` instead.
* **If you get "scripts is disabled" error**: Run this command in PowerShell as Administrator:

  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Step 4: Install Dependencies

Run this command to install the necessary software libraries:

```bash
pip install -r requirements.txt
```

*If you see a warning about "pip version", you can ignore it.*

### Step 5: Start the Server

Run the interactive launcher:

```bash
python run_server.py
```

You will see a menu like this:

```text
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

### Step 6: Connect

Once the server starts, you will see a big **QR Code** in the terminal.

1. Open the **Parallax Connect** app on your phone.
2. Tap **"Scan QR Code"**.
3. Point your camera at the screen.

---

## 🌐 Connection Modes

The server supports two ways to connect:

### 1. Local Mode (Fastest) 🏠

* **How**: Your phone and computer must be on the **same Wi-Fi network**.
* **Pros**: Super fast, no internet required.
* **Cons**: Only works at home.

### 2. Cloud Mode (Anywhere) ☁️

* **How**: Uses a secure tunnel (Ngrok) to connect over the internet.
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

---

## 🔧 Troubleshooting Local Connection Issues

### Issue: "It worked yesterday but not connecting today" (Random MAC Address)

**Symptom**: Local Mode worked fine before, but now fails to connect even though both devices are on the same Wi-Fi.

**Root Cause**: Modern Android/iOS devices use **MAC Address Randomization** for privacy. This can occasionally cause network routing issues.

**Solution**: Set WiFi to use **Device MAC** instead of random MAC:

#### Android

1. Open **Settings** → **Wi-Fi**
2. Long-press your current Wi-Fi network → **Modify network**
3. Tap **Advanced options**
4. Under **Privacy**, change from **"Randomized MAC"** to **"Use device MAC"**
5. Tap **Save**
6. Reconnect to WiFi and retry connection

#### iOS

1. Open **Settings** → **Wi-Fi**
2. Tap the **(i)** icon next to your connected network
3. Toggle **OFF** the option **"Private Wi-Fi Address"**
4. Reconnect to WiFi and retry connection

**Note**: This is only needed if you experience intermittent connection issues. Random MAC usually works fine.

### Issue: Firewall Blocking Connection

**Symptom**: Server starts successfully but app cannot reach it.

**Solution**:

* **Windows**: Allow Python through Windows Defender Firewall
  * Go to **Settings** → **Privacy & Security** → **Windows Security** → **Firewall & network protection**
  * Click **Allow an app through firewall**
  * Find Python and ensure both **Private** and **Public** are checked
  
* **macOS**: Allow Python in System Preferences → Security & Privacy → Firewall

### Issue: Wrong Network Interface

**Symptom**: Server shows IP like `192.168.56.1` but phone is on `192.168.1.x`

**Solution**:

* Ensure computer is connected to the **same WiFi network** as phone (not Ethernet/VPN)
* Disable VPN on both devices
* If using virtual machines (VMware/VirtualBox), disable their network adapters temporarily
