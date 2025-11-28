# Testing Guide: Parallax Connect

Complete step-by-step guide to test full communication flow from mobile app → server.py → Parallax.

## Prerequisites

### On Windows Device (Friend's PC)

**1. Install Parallax**

```powershell
# Download and run the installer
# https://github.com/GradientHQ/parallax_win_cli/releases/latest/download/Parallax_Win_Setup.exe

# Open Windows Terminal as Administrator (REQUIRED)
# Right-click Start → "Windows Terminal (Admin)"

# Install dependencies (takes ~30 minutes)
parallax install

# Verify installation
parallax --help
```

**2. Install Python Dependencies for server.py**

```powershell
# Navigate to project directory
cd C:\path\to\parallax-connect

# Install requirements
pip install fastapi uvicorn httpx pyngrok qrcode pillow python-multipart
```

## Setup Process

### Step 1: Start Parallax

```powershell
# Open Windows Terminal as Administrator
# Run Parallax scheduler
parallax run

# You should see output like:
# - Scheduler starting on port 3001
# - Scheduler ID (e.g., 12D3KooW...)
# - Web interface at http://localhost:3001
```

> **Important**: Keep this terminal window open. Parallax must keep running.

**Verify Parallax is Running:**

```powershell
# In a new terminal, test the API directly
curl http://localhost:3001/health
# Should return: {"status":"ok"} or similar

# Test chat completion
curl http://localhost:3001/v1/chat/completions -H "Content-Type: application/json" -d "{\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}],\"stream\":false,\"max_tokens\":50}"
```

### Step 2: Configure and Start server.py

**A. Set Server Mode**

Edit `server.py` line 23:

```python
# For testing with Parallax:
SERVER_MODE = "PROXY"

# For testing UI without Parallax:
# SERVER_MODE = "MOCK"
```

**B. Start server.py**

```powershell
# In a NEW terminal (not Administrator required)
cd C:\path\to\parallax-connect

# Start the server
python server.py
```

**During startup you'll see:**

```
🚀 Server Starting... MODE: PROXY
Testing connection to Parallax at http://localhost:3001/v1/chat/completions...
✅ Parallax connection successful

🔒 Set a password for this server? (y/n):
```

**C. Set Password (Optional but Recommended)**

- Press `y` and enter a password (e.g., `test123`)
- Remember this password - you'll need it in the mobile app

**D. Connection URLs**

Server will display:

```
📲 CONNECT YOUR APP
=================================================

🌍 CLOUD MODE (Recommended)
URL: https://xxxx-xx-xx.ngrok-free.app
[QR CODE]

🏠 LOCAL MODE (Same Wi-Fi only)  
URL: http://192.168.1.X:8000
[QR CODE]
```

**For Testing:**

- **Same Wi-Fi**: Use LOCAL MODE URL
- **Different Networks**: Use CLOUD MODE URL (requires ngrok account)

### Step 3: Test server.py

**In a new PowerShell terminal:**

```powershell
# Test health check (no password needed)
curl http://localhost:8000/healthz
# Expected: {"status":"ok"}

# Test status endpoint (replace YOUR_PASSWORD if you set one)
curl http://localhost:8000/status -H "x-password: YOUR_PASSWORD"
# Expected: {"server":"online","mode":"PROXY","parallax":"connected",...}

# Test chat in MOCK mode (to verify server works)
# First change SERVER_MODE to "MOCK" in server.py and restart
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" -d "{\"prompt\":\"test\"}"
# Expected: {"response":"[MOCK] Server received: 'test'..."}

# Test chat in PROXY mode (to verify Parallax connection)
# Change SERVER_MODE back to "PROXY" and restart
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" -H "x-password: YOUR_PASSWORD" -d "{\"prompt\":\"Say hello\"}"
# Expected: {"response":"Hello! How can I assist you today?", "metadata":{"usage":{...}, "timing":{...}}}
```

### Step 4: Configure Mobile App

**A. Disable Test Mode**

Edit `app/lib/src/core/constants/app_constants.dart`:

```dart
class TestConfig {
  static const bool enabled = false; // Change to false for real mode
  //...
}
```

**B. Rebuild App**

```bash
cd app
flutter clean
flutter pub get
flutter run
```

**C. Set Server URL in App**

1. Open app on your phone
2. Go to **Config/Settings** screen
3. Enter the server URL:
   - **Local**: `http://192.168.1.X:8000` (from server.py output)
   - **Cloud**: `https://xxxx.ngrok-free.app` (from server.py output)
4. If you set a password, enter it
5. Click **Test Connection**
   - Should show ✅ "Connection successful"

### Step 5: End-to-End Test

**Send a Test Message:**

1. Open the **Chat** screen
2. Type a message: "Hello, can you help me?"
3. Send the message
4. **Expected behavior:**
   - Message appears in chat
   - Loading indicator shows
   - Response appears from Parallax

**Monitor the Logs:**

**Server.py Terminal:**

```
📝 [20251125105530123456] Received chat request: Hello, can you help me?...
🔄 [20251125105530123456] Forwarding to Parallax at http://localhost:3001/v1/chat/completions
✅ [20251125105530123456] Received response from Parallax (2.34s)
📊 [20251125105530123456] Tokens - Prompt: 15, Completion: 127, Total: 142
```

**Parallax Terminal:**

- You should see processing logs

## Troubleshooting

### Issue: "Cannot connect to server"

**Check:**

1. Is server.py running? Look for the terminal window
2. Is the URL correct in the app?
3. Are you on the same Wi-Fi (for local mode)?
4. Is firewall blocking port 8000?

**Solution:**

```powershell
# Allow port 8000 in Windows Firewall
New-NetFirewallRule -DisplayName "Parallax Server" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow
```

### Issue: "Parallax connection failed"

**Check:**

1. Is Parallax running? (`parallax run`)
2. Can you access `http://localhost:3001/health`?
3. Check server.py logs for connection errors

**Solution:**

```powershell
# Restart Parallax
# Close the parallax terminal
# Reopen Windows Terminal as Administrator
parallax run
```

### Issue: "Invalid password"

**Check:**

- Did you enter the same password you set in server.py?
- Passwords are case-sensitive

**Solution:**

- Restart server.py and set a new password
- Or set `PASSWORD = None` in server.py to disable

### Issue: Slow responses

**This is normal for large models!**

- First request may take 10-30 seconds (model loading)
- Subsequent requests: 2-10 seconds depending on model size
- Check server.py logs for timing: `Received response from Parallax (X.XXs)`

### Issue: ngrok authentication error

**Solution:**

```powershell
# Sign up at https://ngrok.com (free)
# Get your auth token
# Configure ngrok:
ngrok config add-authtoken YOUR_TOKEN_HERE
```

## Log Interpretation

### Good Request Flow

**server.py logs:**

```
📝 [ID] Received chat request: Hello...
🔄 [ID] Forwarding to Parallax at http://localhost:3001/v1/chat/completions
✅ [ID] Received response from Parallax (2.50s)
📊 [ID] Tokens - Prompt: 5, Completion: 20, Total: 25
```

**Mobile app:**

- Sees message and response in chat

### Failed Request (Parallax Offline)

**server.py logs:**

```
📝 [ID] Received chat request: Hello...
🔄 [ID] Forwarding to Parallax at http://localhost:3001/v1/chat/completions
🔌 [ID] Cannot connect to Parallax: [Errno 111] Connection refused
```

**Solution:** Start Parallax with `parallax run`

### Failed Request (Timeout)

**server.py logs:**

```
📝 [ID] Received chat request: Very complex question...
🔄 [ID] Forwarding to Parallax at http://localhost:3001/v1/chat/completions
⏱️ [ID] Parallax request timeout: TimeoutException
```

**This means:** Model is taking too long (>60s). Consider:

- Using a smaller/faster model
- Increasing timeout in server.py line 161

## Network Modes Explained

### Local Mode (Same Wi-Fi)

- **URL**: `http://192.168.1.X:8000`
- **Pros**: Fast, no external dependencies, free
- **Cons**: Only works on same Wi-Fi network
- **Best for**: Testing at home

### Cloud Mode (ngrok)

- **URL**: `https://xxxx.ngrok-free.app`
- **Pros**: Works from anywhere, mobile data support
- **Cons**: Requires ngrok account, slightly slower
- **Best for**: Remote testing, different networks

## Testing Checklist

- [ ] Parallax installed and running
- [ ] server.py running in PROXY mode
- [ ] Password set (optional)
- [ ] Mobile app configured with correct URL
- [ ] Test connection successful
- [ ] Can send message and receive response
- [ ] Logs show proper flow
- [ ] Multiple messages work
- [ ] Response time acceptable

## Quick Reference Commands

```powershell
# Start Parallax (Administrator terminal)
parallax run

# Start server.py
python server.py

# Test Parallax directly
curl http://localhost:3001/health

# Test server.py
curl http://localhost:8000/healthz

# Test full chain
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" -H "x-password: YOUR_PASSWORD" -d "{\"prompt\":\"test\"}"
```

## Next Steps

Once everything works:

1. Try different prompts and test response quality
2. Test with multiple messages in a conversation
3. Try the private chat mode in the app
4. Experiment with different Parallax models
