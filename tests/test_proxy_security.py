
import unittest
from server.utils.security import validate_proxy_path

class TestProxySecurity(unittest.TestCase):
    def test_valid_paths(self):
        # Should not raise exception
        validate_proxy_path("js/main.js")
        validate_proxy_path("css/style.css")
        validate_proxy_path("api/v1/status")
        validate_proxy_path("file_with_underscore.txt")
        validate_proxy_path("file-with-dash.png")

    def test_simple_traversal(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("../etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("..\\windows\\win.ini")
        with self.assertRaises(ValueError):
            validate_proxy_path("foo/../bar")

    def test_encoded_traversal(self):
        # %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e%2e/etc/passwd")

        # %2E%2E -> .. (case insensitive)
        with self.assertRaises(ValueError):
            validate_proxy_path("%2E%2E/etc/passwd")

    def test_double_encoded_traversal(self):
        # %252e%252e -> %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%252e%252e/etc/passwd")

        # %25252e -> %252e -> %2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%25252e%25252e/etc/passwd")

    def test_null_byte(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("image.png%00.php")
        with self.assertRaises(ValueError):
            validate_proxy_path("image.png\0.php")

    def test_absolute_path(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("/etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("//etc/passwd")

        # Encoded absolute path
        # %2f -> /
        with self.assertRaises(ValueError):
            validate_proxy_path("%2fetc/passwd")

    def test_mixed_encoding(self):
        # .%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path(".%2e/etc/passwd")

        # %2e. -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e./etc/passwd")

if __name__ == "__main__":
    unittest.main()
