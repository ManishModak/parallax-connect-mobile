#!/usr/bin/env python3
"""
Parallax Connect Server Launcher

Interactive startup script with complete setup flow:
1. Check/install requirements.txt dependencies
2. Password protection setup
3. Vision/OCR engine selection (PaddleOCR or EasyOCR)
4. Document processing engine selection (PyMuPDF or pdfplumber)
5. Start uvicorn server
"""

import getpass
import importlib.util
import subprocess
import sys
import os
from pathlib import Path


def print_banner():
    """Print startup banner."""
    print("\n" + "=" * 60)
    print("🚀 PARALLAX CONNECT SERVER")
    print("=" * 60)


def ask_yes_no(question: str, default: bool = False) -> bool:
    """Ask a yes/no question."""
    suffix = " [Y/n]: " if default else " [y/N]: "
    while True:
        try:
            answer = input(question + suffix).strip().lower()
        except EOFError:
            return default
        if answer == "":
            return default
        if answer in ("y", "yes"):
            return True
        if answer in ("n", "no"):
            return False
        print("Please answer 'y' or 'n'")


def ask_choice(question: str, options: list[tuple[str, str]], default: int = 0) -> str:
    """Ask user to choose from options. Returns the option key."""
    print(f"\n{question}")
    for i, (key, desc) in enumerate(options):
        marker = " (recommended)" if i == default else ""
        print(f"  [{i + 1}] {desc}{marker}")

    while True:
        try:
            answer = input(
                f"Enter choice [1-{len(options)}] (default: {default + 1}): "
            ).strip()
        except EOFError:
            return options[default][0]
        if answer == "":
            return options[default][0]
        try:
            idx = int(answer) - 1
            if 0 <= idx < len(options):
                return options[idx][0]
        except ValueError:
            pass
        print(f"Please enter a number between 1 and {len(options)}")


def install_package(package: str, pip_name: str = None) -> bool:
    """Install a package via pip."""
    pip_name = pip_name or package
    print(f"   📦 Installing {pip_name}...")
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", pip_name, "-q"],
            stdout=subprocess.DEVNULL if not os.getenv("DEBUG_MODE") else None,
        )
        print(f"   ✅ {pip_name} installed!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"   ❌ Failed: {e}")
        return False


# =============================================================================
# STEP 1: Requirements Check
# =============================================================================


def check_requirements() -> bool:
    """Check and install requirements.txt dependencies."""
    print("\n" + "-" * 60)
    print("📦 CHECKING DEPENDENCIES")
    print("-" * 60)

    script_dir = Path(__file__).parent
    req_file = script_dir.parent / "requirements.txt"
    if not req_file.exists():
        req_file = script_dir / "requirements.txt"

    if not req_file.exists():
        print("⚠️  requirements.txt not found, skipping")
        return True

    print(f"Found: {req_file.name}")

    with open(req_file) as f:
        requirements = [
            line.strip() for line in f if line.strip() and not line.startswith("#")
        ]

    missing = []
    for req in requirements:
        pkg_name = req.split("[")[0].split(">=")[0].split("==")[0].replace("-", "_")
        if not importlib.util.find_spec(pkg_name):
            missing.append(req)

    if not missing:
        print("✅ All dependencies installed!")
        return True

    print(f"\n⚠️  Missing: {', '.join(missing)}")
    if not ask_yes_no("Install missing dependencies?", default=True):
        print("❌ Cannot proceed without dependencies.")
        return False

    print("\n📦 Installing...")
    try:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "-r", str(req_file), "-q"]
        )
        print("✅ Dependencies installed!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed: {e}")
        return False


# =============================================================================
# STEP 2: Password Setup
# =============================================================================


def setup_password() -> None:
    """Prompt for optional password protection."""
    print("\n" + "-" * 60)
    print("🔒 PASSWORD PROTECTION")
    print("-" * 60)
    print("Protects server from unauthorized access.")

    if not ask_yes_no("Set a password?", default=False):
        os.environ["SERVER_PASSWORD"] = ""
        print("⚠️  No password. Server is open.")
        return

    while True:
        try:
            password = getpass.getpass("Enter password: ").strip()
            if not password:
                os.environ["SERVER_PASSWORD"] = ""
                print("⚠️  Empty password. Server is open.")
                return
            confirm = getpass.getpass("Confirm password: ").strip()
        except EOFError:
            os.environ["SERVER_PASSWORD"] = ""
            return

        if password == confirm:
            os.environ["SERVER_PASSWORD"] = password
            print("✅ Password enabled!")
            return
        print("❌ Passwords don't match. Try again.")


# =============================================================================
# STEP 3: Vision/OCR Setup
# =============================================================================


def setup_vision() -> tuple[bool, str]:
    """Interactive vision/OCR setup."""
    print("\n" + "-" * 60)
    print("📷 VISION PROCESSING (Images)")
    print("-" * 60)
    print("Server-side OCR extracts text from images.")
    print("\n⚠️  Downloads required:")
    print("   • PaddleOCR: ~300MB (faster, more accurate)")
    print("   • EasyOCR: ~100MB (simpler)")

    if not ask_yes_no("\nEnable server-side OCR?", default=False):
        print("ℹ️  Using mobile Edge OCR only.")
        return False, None

    engine = ask_choice(
        "Select OCR engine:",
        [
            ("paddleocr", "PaddleOCR - Faster & more accurate"),
            ("easyocr", "EasyOCR - Simpler setup"),
        ],
        default=0,
    )

    if engine == "paddleocr":
        print("\n📦 Setting up PaddleOCR...")
        if not importlib.util.find_spec("paddle"):
            if not install_package("paddle", "paddlepaddle"):
                print("⚠️  PaddleOCR failed!")
                if ask_yes_no("Try EasyOCR instead?", default=True):
                    engine = "easyocr"
                else:
                    return False, None
        if engine == "paddleocr" and not importlib.util.find_spec("paddleocr"):
            if not install_package("paddleocr"):
                if ask_yes_no("Try EasyOCR instead?", default=True):
                    engine = "easyocr"
                else:
                    return False, None

    if engine == "easyocr":
        print("\n📦 Setting up EasyOCR...")
        if not importlib.util.find_spec("easyocr"):
            if not install_package("easyocr"):
                print("❌ EasyOCR failed. Vision disabled.")
                return False, None

    print(f"✅ {engine} ready!")
    return True, engine


# =============================================================================
# STEP 4: Document Processing Setup
# =============================================================================


def setup_documents() -> tuple[bool, str]:
    """Interactive document processing setup."""
    print("\n" + "-" * 60)
    print("📄 DOCUMENT PROCESSING (PDFs)")
    print("-" * 60)
    print("Server-side PDF text extraction.")
    print("\n⚠️  Downloads required:")
    print("   • PyMuPDF: ~15MB (fast, accurate)")
    print("   • pdfplumber: ~5MB (handles tables well)")

    if not ask_yes_no("\nEnable server-side document processing?", default=False):
        print("ℹ️  Using mobile document processing only.")
        return False, None

    engine = ask_choice(
        "Select PDF engine:",
        [
            ("pymupdf", "PyMuPDF - Fast & accurate"),
            ("pdfplumber", "pdfplumber - Good for tables"),
        ],
        default=0,
    )

    if engine == "pymupdf":
        print("\n📦 Setting up PyMuPDF...")
        if not importlib.util.find_spec("fitz"):
            if not install_package("fitz", "pymupdf"):
                print("⚠️  PyMuPDF failed!")
                if ask_yes_no("Try pdfplumber instead?", default=True):
                    engine = "pdfplumber"
                else:
                    return False, None

    if engine == "pdfplumber":
        print("\n📦 Setting up pdfplumber...")
        if not importlib.util.find_spec("pdfplumber"):
            if not install_package("pdfplumber"):
                print("❌ pdfplumber failed. Documents disabled.")
                return False, None

    print(f"✅ {engine} ready!")
    return True, engine


# =============================================================================
# MAIN
# =============================================================================


def main():
    """Main entry point."""
    print_banner()

    # Step 1: Check dependencies
    if not check_requirements():
        sys.exit(1)

    # Step 2: Password
    setup_password()

    # Step 3: Vision/OCR
    ocr_enabled, ocr_engine = setup_vision()
    os.environ["OCR_ENABLED"] = "true" if ocr_enabled else "false"
    if ocr_engine:
        os.environ["OCR_ENGINE"] = ocr_engine

    # Step 4: Documents
    doc_enabled, doc_engine = setup_documents()
    os.environ["DOC_ENABLED"] = "true" if doc_enabled else "false"
    if doc_engine:
        os.environ["DOC_ENGINE"] = doc_engine

    # Step 5: Start server
    print("\n" + "=" * 60)
    print("🚀 STARTING SERVER")
    print("=" * 60)
    print(
        f"   🔒 Password: {'Enabled' if os.environ.get('SERVER_PASSWORD') else 'None'}"
    )
    print(f"   📷 OCR: {ocr_engine or 'Disabled'}")
    print(f"   📄 Docs: {doc_engine or 'Disabled'}")
    print()

    import uvicorn

    uvicorn.run(
        "server.app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )


if __name__ == "__main__":
    main()
