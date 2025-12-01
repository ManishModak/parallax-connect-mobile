# Parallax Connect

**Your Personal AI Cloud.**

Parallax Connect allows you to use your powerful home computer's AI capabilities from your mobile phone, anywhere in the world. It's like having your own private ChatGPT, running entirely on your own hardware.

## 🚀 Quick Start

### 1. Prerequisites

- A computer with an NVIDIA GPU (Windows/Linux).
- [Python 3.10+](https://www.python.org/downloads/) installed.
- [Parallax](https://github.com/ManishModak/parallax) installed and running.

### 2. Installation

Open your terminal (Command Prompt or PowerShell) and run:

```bash
# 1. Download the code (or unzip the folder)
git clone https://github.com/ManishModak/parallax-connect.git
cd parallax-connect

# 2. Install requirements
pip install -r requirements.txt
```

### 3. Run the Server

```bash
python run_server.py
```

Follow the on-screen prompts to start the server. You can choose **Normal Mode** for standard use or **Mock Mode** to test without a GPU.

### 4. Connect Your Phone

1. Open the **Parallax Connect** app on your phone.
2. Scan the **QR Code** displayed in your terminal.
3. Start chatting!

---

## 🌟 Features

- **Private & Secure**: Your data never leaves your control.
- **Anywhere Access**: Connect via local Wi-Fi or over the internet (using Ngrok).
- **Smart AI**: Supports "Thinking" models with visual reasoning steps.
- **Web Search**: The AI can search the web to answer current questions.
- **Multi-Device**: Share your GPU with family members.

## 📚 Documentation

- **[Setup Guide](SERVER_SETUP.md)**: Detailed instructions for installing and configuring the server.
- **[Usage Guide](SERVER_USAGE_GUIDE.md)**: Technical details for developers and advanced users.

## ❓ Troubleshooting

**"Cannot connect to Parallax"**
> Make sure the main Parallax service is running (`parallax run`) before starting this server.

**"Ngrok error"**
> If you want to connect from outside your home, you need a free Ngrok account. Run `ngrok config add-authtoken YOUR_TOKEN`.

**"Port already in use"**
> Another program might be using port 8000. Close it or restart your computer.

---

*Built with ❤️ for the Local AI Community.*
