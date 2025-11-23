# Parallax Linux Set Up

## From Source

**For Linux/WSL (GPU):**

```bash
git clone https://github.com/GradientHQ/parallax.git
cd parallax
pip install -e '.[gpu]'
```

## Docker

For Linux+GPU devices, Parallax provides a docker environment for quick setup. Choose the docker image according to the device's GPU architecture.

**GPU architecture:**

* **Blackwell - GPU Series:** RTX50 series/B100/B200...
  * Image Pull Command: `docker pull gradientservice/parallax:latest-blackwell`
* **Ampere/Hopper - GPU Series:** RTX30 series/RTX40 series/A100/H100...
  * Image Pull Command: `docker pull gradientservice/parallax:latest-hopper`

**Run a docker container:**
(Note: `--gpus all` is necessary)

```bash
# For Blackwell
docker run -it --gpus all --network host gradientservice/parallax:latest-blackwell bash

# For Ampere/Hopper
docker run -it --gpus all --network host gradientservice/parallax:latest-hopper bash
```

The container starts under parallax workspace and you should be able to run parallax directly.

## Getting Started

We will walk through you the easiest way to quickly set up your own AI cluster.

### With Frontend

**Step 1: Launch scheduler**
First launch our scheduler on the main node (recommend using your most convenient computer).
For Linux/macOS:

```bash
parallax run
```

**Step 2: Set cluster and model config**
Open `http://localhost:3001` and you should see the setup interface.
Select your desired node and model config and click continue.

**Step 3: Connect your nodes**
Copy the generated join command line to your node and run. For remote connection, you can find your scheduler-address in the scheduler logs.

```bash
# local area network env
parallax join

# public network env
parallax join -s {scheduler-address}
# example: parallax join -s 12D3KooWLX7MWuzi1Txa5LyZS4eTQ2tPaJijheH8faHggB9SxnBu
```

You should see your nodes start to show up with their status. Wait until all nodes are successfully connected, and you will automatically be directed to the chat interface.

*Note: To disable basic info reporting (version/gpu name), use the `-u` flag:* `parallax join -u`

**Step 4: Chat**
Done! You have your own AI cluster now.

### Chat on Node

If you are only running the node service on your machine, you can visit `http://localhost:3002` to access the chat page.
