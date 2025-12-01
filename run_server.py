"""Entry point for Parallax Connect Server with interactive configuration."""

import os
import sys
import uvicorn
import getpass


def main():
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

    # Set Environment Variables
    os.environ["SERVER_MODE"] = mode
    os.environ["LOG_LEVEL"] = log_level

    print(f"\nStarting server in {mode} mode with LOG_LEVEL={log_level}...")
    print("------------------------------------------------------------\n")

    # Run Uvicorn
    # Using string import string to enable reload in Debug mode
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
