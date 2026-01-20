
import unittest
from server.utils.security import validate_proxy_path

class TestProxySecurity(unittest.TestCase):
    def test_valid_paths(self):
        """Test that valid paths are allowed."""
        valid_paths = [
            "assets/image.png",
            "api/v1/status",
            "index.html",
            "css/main.css",
            "js/app.bundle.js",
            "users/123/profile"
        ]
        for path in valid_paths:
            self.assertEqual(validate_proxy_path(path), path)

    def test_path_traversal_attempts(self):
        """Test that path traversal attempts are blocked."""
        invalid_paths = [
            "../etc/passwd",
            "../../secret.txt",
            "..\\windows\\system32",
            "assets/../../config",
        ]
        for path in invalid_paths:
            with self.assertRaisesRegex(ValueError, "Path traversal"):
                validate_proxy_path(path)

    def test_encoded_traversal_attempts(self):
        """Test that URL encoded traversal attempts are blocked."""
        encoded_paths = [
            "%2e%2e/etc/passwd",          # ../etc/passwd
            "%2E%2E/secret",              # ../secret (case insensitive)
            "assets/%2e%2e/config",       # assets/../config
            "%5cwindows",                 # \windows
        ]
        for path in encoded_paths:
            with self.assertRaisesRegex(ValueError, "Path traversal"):
                validate_proxy_path(path)

    def test_double_encoded_traversal_attempts(self):
        """Test that double URL encoded traversal attempts are blocked."""
        double_encoded_paths = [
            "%252e%252e/etc/passwd",      # %2e%2e -> ..
            "%25252e%25252e/secret",      # Triple encoded
            "assets/%252e%252e/config",
        ]
        for path in double_encoded_paths:
            with self.assertRaisesRegex(ValueError, "Path traversal"):
                validate_proxy_path(path)

    def test_null_bytes(self):
        """Test that null bytes are blocked."""
        with self.assertRaisesRegex(ValueError, "Null byte"):
            validate_proxy_path("image.png%00.exe")

    def test_absolute_paths(self):
        """Test that absolute paths are blocked if they start with /."""
        with self.assertRaisesRegex(ValueError, "Path must be relative"):
            validate_proxy_path("/etc/passwd")

if __name__ == "__main__":
    unittest.main()
