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

        try:
            choice = input("👉 Auto-install requirements? (Y/n): ").strip().lower()
        except EOFError:
            choice = "y"

        if choice in ["", "y", "yes"]:
            print("📦 Installing dependencies...")
            try:
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", "-r", "requirements.txt"]
                )
                print("✅ Dependencies installed!")
                print("\n" + "=" * 50)
                print("⚠️  Please restart the server to load new packages.")
                print("   Run: python run_server.py")
                print("=" * 50)
                sys.exit(0)
            except subprocess.CalledProcessError as e:
                print(f"❌ Installation failed: {e}")
                print("Please run 'pip install -r requirements.txt' manually.")
                sys.exit(1)
        else:
            print("❌ Cannot start without dependencies.")
            print("Run: pip install -r requirements.txt")
            sys.exit(1)
    else:
        print("✅ All dependencies found.\n")


def ask_choice(prompt, options, default=1):
    """Ask user to pick from numbered options. Returns 1-indexed choice."""
    while True:
        try:
            answer = input(f"{prompt} [{default}]: ").strip()
        except EOFError:
            return default

        if answer == "":
            return default
        try:
            choice = int(answer)
            if 1 <= choice <= len(options):
                return choice
        except ValueError:
            pass
        print(f"Please enter 1-{len(options)}")


def main():
    print("\n" + "=" * 50)
    print("🚀 PARALLAX CONNECT SERVER")
    print("=" * 50)

    # Check dependencies first
    check_and_install_dependencies()

    # Now safe to import uvicorn
    import uvicorn

    # 1. Select Mode
    print("Select Operation Mode:")
    print("  1. Normal  - Standard operation")
    print("  2. Debug   - Verbose logging & auto-reload")
    print("  3. Mock    - Simulated responses (no GPU required)")

    mode_choice = ask_choice("\nEnter choice", [1, 2, 3], default=1)

    mode = "NORMAL"
    log_level = "INFO"

    if mode_choice == 2:
        mode = "DEBUG"
        log_level = "DEBUG"
    elif mode_choice == 3:
        mode = "MOCK"
        log_level = "INFO"

    print(f"✅ Mode: {mode}")

    # 2. Password Configuration
    print("\n🔒 Password Protection:")
    try:
        confirm_pass = input("Set/Update server password? (y/N): ").strip().lower()
    except EOFError:
        confirm_pass = "n"

    if confirm_pass == "y":
        while True:
            try:
                password = getpass.getpass("Enter password: ")
                if not password:
                    print("⚠️  Empty password. Server will be open.")
                    os.environ["SERVER_PASSWORD"] = ""
                    break

                confirm = getpass.getpass("Confirm password: ")

                if password == confirm:
                    os.environ["SERVER_PASSWORD"] = password
                    print("✅ Password set.")
                    break
                else:
                    print("❌ Passwords don't match. Try again.")
            except EOFError:
                os.environ["SERVER_PASSWORD"] = ""
                break
    else:
        os.environ["SERVER_PASSWORD"] = ""
        print("⚠️  No password. Server is open.")

    # 3. OCR/Document Processing (optional)
    print("\n📷 Server-Side Vision/Document Processing:")
    print("   Enable OCR for images and PDF text extraction on server?")
    print("   (Requires ~100-300MB download for OCR models)")

    try:
        enable_vision = input("Enable vision processing? (y/N): ").strip().lower()
    except EOFError:
        enable_vision = "n"

    if enable_vision == "y":
        os.environ["OCR_ENABLED"] = "true"

        print("\nSelect OCR engine:")
        print("  1. PaddleOCR - Faster & more accurate (recommended)")
        print("  2. EasyOCR   - Simpler, smaller download")

        engine_choice = ask_choice("Enter choice", [1, 2], default=1)

        if engine_choice == 1:
            os.environ["OCR_ENGINE"] = "paddleocr"
            # Check if installed
            if importlib.util.find_spec("paddleocr") is None:
                print("\n📦 PaddleOCR not installed. Installing...")
                try:
                    subprocess.check_call(
                        [
                            sys.executable,
                            "-m",
                            "pip",
                            "install",
                            "paddlepaddle",
                            "paddleocr",
                            "-q",
                        ]
                    )
                    print("✅ PaddleOCR installed!")
                except subprocess.CalledProcessError:
                    print("⚠️  PaddleOCR install failed. Trying EasyOCR...")
                    os.environ["OCR_ENGINE"] = "easyocr"
                    subprocess.check_call(
                        [sys.executable, "-m", "pip", "install", "easyocr", "-q"]
                    )
        else:
            os.environ["OCR_ENGINE"] = "easyocr"
            if importlib.util.find_spec("easyocr") is None:
                print("\n📦 Installing EasyOCR...")
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", "easyocr", "-q"]
                )
                print("✅ EasyOCR installed!")

        print(f"✅ OCR: {os.environ.get('OCR_ENGINE', 'easyocr')}")

        # Document processing
        os.environ["DOC_ENABLED"] = "true"
        if importlib.util.find_spec("fitz") is None:
            print("📦 Installing PyMuPDF for PDF processing...")
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "pymupdf", "-q"]
            )
        os.environ["DOC_ENGINE"] = "pymupdf"
        print("✅ PDF processing: pymupdf")
    else:
        os.environ["OCR_ENABLED"] = "false"
        os.environ["DOC_ENABLED"] = "false"
        print("ℹ️  Vision disabled. Mobile Edge OCR will be used.")

    # Set Environment Variables
    os.environ["SERVER_MODE"] = mode
    os.environ["LOG_LEVEL"] = log_level
    if mode == "DEBUG":
        os.environ["DEBUG_MODE"] = "true"

    # Start Server
    print("\n" + "=" * 50)
    print(f"🚀 Starting server...")
    print(f"   Mode: {mode}")
    print(f"   Password: {'Enabled' if os.environ.get('SERVER_PASSWORD') else 'None'}")
    print(f"   OCR: {os.environ.get('OCR_ENGINE', 'disabled')}")
    print("=" * 50 + "\n")

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
        print("\n\n👋 Server stopped. Goodbye!")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        input("Press Enter to exit...")
        sys.exit(1)
