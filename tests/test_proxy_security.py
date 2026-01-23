
import unittest
from server.utils.security import validate_proxy_path

class TestProxySecurity(unittest.TestCase):
    def test_validate_proxy_path_safe(self):
        """Test safe paths are allowed."""
        self.assertTrue(validate_proxy_path("index.html"))
        self.assertTrue(validate_proxy_path("assets/style.css"))
        self.assertTrue(validate_proxy_path("images/logo.png"))
        self.assertTrue(validate_proxy_path("api/v1/data"))

    def test_validate_proxy_path_traversal(self):
        """Test simple path traversal is blocked."""
        self.assertFalse(validate_proxy_path("../etc/passwd"))
        self.assertFalse(validate_proxy_path(".../secret"))
        self.assertFalse(validate_proxy_path("/etc/shadow"))

    def test_validate_proxy_path_double_encoding(self):
        """Test double encoded traversal is blocked."""
        # %2e%2e -> ..
        # %252e%252e -> %2e%2e -> ..
        self.assertFalse(validate_proxy_path("%2e%2e/etc/passwd"))
        self.assertFalse(validate_proxy_path("%252e%252e/etc/passwd"))
        self.assertFalse(validate_proxy_path("%252E%252E/etc/passwd"))

        # Triple encoding
        self.assertFalse(validate_proxy_path("%25252e%25252e/etc/passwd"))

    def test_validate_proxy_path_special_chars(self):
        """Test null bytes and backslashes are blocked."""
        self.assertFalse(validate_proxy_path(r"..\win\system32"))
        self.assertFalse(validate_proxy_path("image.png\0.exe"))

    def test_validate_proxy_path_recursion_limit(self):
        """Test that deeply nested encoding doesn't crash but is handled."""
        # Just ensure it doesn't hang; logic should probably fail it or pass it if it resolves to safe string
        # But if it resolves to ".." eventually after > 5 passes, it might pass if we stop early.
        # Ideally, we block if it looks suspicious, but here we just test it returns a bool.
        safe_nested = "safe"
        for _ in range(10):
            from urllib.parse import quote
            safe_nested = quote(safe_nested)
        # deeply encoded safe string might be allowed or denied depending on implementation details
        # but function should return.
        self.assertIsInstance(validate_proxy_path(safe_nested), bool)

if __name__ == "__main__":
    unittest.main()
