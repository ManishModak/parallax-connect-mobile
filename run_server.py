"""Entry point for Parallax Connect Server with interactive configuration."""

import os
import sys
import subprocess
import getpass
import importlib.util


def check_and_install_dependencies():
    """Check for missing dependencies and offer to install them."""
    print("🔍 Checking dependencies...")

    # Map module names to package names in requirements.txt
    required = {
        "fastapi": "fastapi",
        "uvicorn": "uvicorn",
        "python_multipart": "python-multipart",
        "pyngrok": "pyngrok",
        "qrcode": "qrcode",
        "httpx": "httpx",
        "ddgs": "ddgs",
        "bs4": "beautifulsoup4",
        "lxml": "lxml",
    }

    missing = []
    for module, package in required.items():
        if importlib.util.find_spec(module) is None:
            missing.append(package)

    if missing:
        print(f"⚠️  Missing packages: {', '.join(missing)}")
        print("This looks like your first run or new dependencies were added.")
        choice = input("👉 Auto-install requirements? (Y/n): ").strip().lower()

        if choice in ["", "y", "yes"]:
            print("📦 Installing dependencies...")
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", "-r", "requirements.txt"]
                )
                print("✅ Dependencies installed! Restarting server...\n")

                # Restart the script to ensure new packages are loaded correctly
                os.execv(sys.executable, [sys.executable] + sys.argv)
            except subprocess.CalledProcessError as e:
                print(f"❌ Installation failed: {e}")
                print("Please run 'pip install -r requirements.txt' manually.")
                sys.exit(1)
        else:
            print("❌ Cannot start without dependencies.")
            print("Run: pip install -r requirements.txt")
            sys.exit(1)
    else:
        print("✅ All dependencies found.")


def main():
    # Check dependencies before importing anything heavy
    check_and_install_dependencies()

    # Now safe to import uvicorn
    import uvicorn

    print("\n🚀 Parallax Connect Server Launcher")
    print("===================================")

    # 1. Select Mode
    print("\nSelect Operation Mode:")
    print("  1. Normal (Default) - Standard operation")
    print("  2. Debug            - Verbose logging & auto-reload")
    print("  3. Mock             - Simulated responses (no GPU required)")

    mode_choice = input("\nEnter choice [1]: ").strip()

    mode = "NORMAL"
    log_level = "INFO"

    if mode_choice == "2":
        mode = "DEBUG"
        log_level = "DEBUG"
    elif mode_choice == "3":
        mode = "MOCK"
        log_level = "INFO"

    print(f"✅ Selected Mode: {mode}")

    # 2. Reconfirm Password
    print("\nSecurity Configuration:")
    confirm_pass = input("Reconfirm/Set Server Password? (y/N): ").strip().lower()

    if confirm_pass == "y":
        while True:
            password = getpass.getpass("Enter Server Password: ")
            if not password:
                print("❌ Password cannot be empty.")
                continue

            confirm = getpass.getpass("Confirm Server Password: ")

            if password == confirm:
                os.environ["SERVER_PASSWORD"] = password
                print("✅ Password set in environment.")
                break
            else:
                print("❌ Passwords do not match! Please try again.")
    else:
        # Explicitly set to empty string so startup.py knows we skipped it
        os.environ["SERVER_PASSWORD"] = ""

    # Set Environment Variables
    os.environ["SERVER_MODE"] = mode
    os.environ["LOG_LEVEL"] = log_level
    if mode == "DEBUG":
        os.environ["DEBUG_MODE"] = "true"

    print(f"\nStarting server in {mode} mode with LOG_LEVEL={log_level}...")
    print("------------------------------------------------------------\n")

    # Run Uvicorn
    uvicorn.run(
        "server.app:app",
        host="0.0.0.0",
        port=8000,
        reload=(mode == "DEBUG"),
        log_level=log_level.lower(),
    )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Server stopped by user. Goodbye!")
        sys.exit(0)
