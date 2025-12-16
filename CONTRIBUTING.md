# Contributing to Parallax Connect

Thank you for your interest in contributing to **Parallax Connect**! We welcome contributions from the community to help make this project better.

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Getting Started](#-getting-started)
- [How to Contribute](#-how-to-contribute)
- [Development Setup](#-development-setup)
- [Pull Request Guidelines](#-pull-request-guidelines)
- [Coding Standards](#-coding-standards)
- [Reporting Issues](#-reporting-issues)

---

## 📜 Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Please:

- Be respectful and considerate in all interactions
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Accept responsibility for mistakes and learn from them

---

## 🚀 Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally:

   ```bash
   git clone https://github.com/YOUR_USERNAME/parallax-connect-mobile.git
   cd parallax-connect-mobile
   ```

3. **Add upstream remote**:

   ```bash
   git remote add upstream https://github.com/ManishModak/parallax-connect-mobile.git
   ```

---

## 🤝 How to Contribute

### Types of Contributions Welcome

- 🐛 **Bug Fixes** — Found a bug? Fix it and submit a PR
- ✨ **New Features** — Have an idea? Open an issue first to discuss
- 📖 **Documentation** — Help improve READMEs, guides, and comments
- 🧪 **Testing** — Add or improve tests
- 🎨 **UI/UX** — Improve the mobile app design and user experience
- 🔧 **Refactoring** — Clean up code without changing functionality

---

## 💻 Development Setup

### Server (Python)

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Run the server
python run_server.py
```

### Mobile App (Flutter)

```bash
cd app

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Prerequisites

- **Python 3.10+** for the server
- **Flutter 3.9+** for the mobile app
- **Parallax** running locally with a supported GPU

---

## 🔀 Pull Request Guidelines

### Before Submitting

1. **Sync with upstream**:

   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** with clear, atomic commits
4. **Test your changes** thoroughly
5. **Update documentation** if needed

### PR Checklist

- [ ] Code follows the project's coding standards
- [ ] All existing tests pass
- [ ] New features include appropriate tests
- [ ] Documentation is updated (if applicable)
- [ ] Commit messages are clear and descriptive
- [ ] PR description explains the changes and motivation

### Commit Message Format

```
type(scope): short description

Longer description if needed.

Fixes #issue_number
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

---

## 📐 Coding Standards

### Python (Server)

- Follow [PEP 8](https://pep8.org/) style guidelines
- Use type hints where applicable
- Document functions with docstrings
- Keep functions focused and modular

### Dart/Flutter (Mobile App)

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use meaningful variable and function names
- Keep widgets small and composable
- Prefer `const` constructors where possible

### General

- Write self-documenting code with clear naming
- Add comments for complex logic
- Remove debug logs before committing
- Keep files focused on a single responsibility

---

## 🐛 Reporting Issues

### Before Creating an Issue

1. Search existing issues to avoid duplicates
2. Check the [Troubleshooting](README.md#-troubleshooting) section
3. Gather relevant information about your environment

### Creating a Good Issue

Include the following information:

- **Description**: Clear explanation of the problem or suggestion
- **Steps to Reproduce**: For bugs, provide detailed steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: OS, Python version, Flutter version, device info
- **Screenshots/Logs**: Attach relevant visuals or error logs

---

## 💡 Questions?

If you have questions about contributing, feel free to:

- Open a [GitHub Discussion](https://github.com/ManishModak/parallax-connect-mobile/discussions)
- Create an issue with the `question` label

---

<p align="center">
  Thank you for helping make Parallax Connect better! 🙏
</p>
