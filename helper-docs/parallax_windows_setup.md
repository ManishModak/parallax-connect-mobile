# Parallax Windows Set Up

## Windows Application

[Click here](https://github.com/GradientHQ/parallax_win_cli/releases/latest/download/Parallax_Win_Setup.exe) to get latest Windows installer.

After installing .exe, right click Windows start button and click **Windows Terminal (Admin)** to start a Powershell console as administrator.

> [!IMPORTANT]
> **Administrator Privileges Required**: Make sure you open your terminal with administrator privileges.

**Ways to run Windows Terminal as administrator:**

* **Start menu:** Right‑click Start and choose “Windows Terminal (Admin)”, or search “Windows Terminal”, right‑click the result, and select “Run as administrator”.
* **Run dialog:** Press `Win+R` → type `wt` → press `Ctrl+Shift+Enter`.
* **Task Manager:** Press `Ctrl+Shift+Esc` → File → Run new task → enter `wt` → check “Create this task with administrator privileges”.
* **File Explorer:** Open the target folder → hold `Ctrl+Shift` → right‑click in the folder → select “Open in Terminal”.

### Installation

Start Windows dependencies installation by simply typing this command in console:

```powershell
parallax install
```

*Installation process may take around 30 minutes.*

To see a description of all Parallax Windows configurations you can do:

```powershell
parallax --help
```

## Getting Started

We will walk through you the easiest way to quickly set up your own AI cluster.

### With Frontend

**Step 1: Launch scheduler**
First launch our scheduler on the main node (recommend using your most convenient computer).
For Windows, start Powershell console as administrator and run:

```powershell
parallax run
```

*Note: To disable basic info reporting, use the `-u` flag:* `parallax run -u`

**Step 2: Set cluster and model config**
Open `http://localhost:3001` and you should see the setup interface.
Select your desired node and model config and click continue.

**Step 3: Connect your nodes**
Copy the generated join command line to your node and run. For remote connection, you can find your scheduler-address in the scheduler logs.

```powershell
# local area network env
parallax join

# public network env
parallax join -s {scheduler-address}
# example: parallax join -s 12D3KooWLX7MWuzi1Txa5LyZS4eTQ2tPaJijheH8faHggB9SxnBu
```

You should see your nodes start to show up with their status. Wait until all nodes are successfully connected, and you will automatically be directed to the chat interface.

**Step 4: Chat**
Done! You have your own AI cluster now.

### Chat on Node

If you are only running the node service on your machine, you can visit `http://localhost:3002` to access the chat page.
