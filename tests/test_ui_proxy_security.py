
import unittest
from fastapi import HTTPException
from server.apis.ui_proxy import validate_proxy_path

class TestUIProxySecurity(unittest.TestCase):

    def test_safe_paths(self):
        """Test that normal paths are allowed."""
        safe_paths = [
            "index.html",
            "css/style.css",
            "js/app.js",
            "assets/images/logo.png",
            "api/v1/status"
        ]
        for path in safe_paths:
            try:
                validate_proxy_path(path)
            except HTTPException:
                self.fail(f"Safe path '{path}' was blocked")

    def test_simple_traversal(self):
        """Test that simple traversal is blocked."""
        unsafe_paths = [
            "../etc/passwd",
            "../../secret",
            "/etc/hosts",
            "assets/../../config.py",
            r"..\windows\system32"
        ]
        for path in unsafe_paths:
            with self.assertRaises(HTTPException, msg=f"Failed to block '{path}'"):
                validate_proxy_path(path)

    def test_encoded_traversal(self):
        """Test that encoded traversal is blocked."""
        # %2e%2e -> ..
        path = "%2e%2e/etc/passwd"
        with self.assertRaises(HTTPException):
            validate_proxy_path(path)

        # %2f -> /
        path = "%2fetc/passwd"
        with self.assertRaises(HTTPException):
            validate_proxy_path(path)

    def test_double_encoded_traversal(self):
        """Test that double encoded traversal is blocked."""
        # %252e%252e -> %2e%2e -> ..
        path = "%252e%252e/etc/passwd"
        with self.assertRaises(HTTPException):
            validate_proxy_path(path)

        # %252f -> %2f -> /
        path = "%252fetc/passwd"
        with self.assertRaises(HTTPException):
            validate_proxy_path(path)

    def test_triple_encoded_traversal(self):
        """Test that triple encoded traversal is blocked."""
        # %25252e%25252e -> %252e%252e -> %2e%2e -> ..
        path = "%25252e%25252e/etc/passwd"
        with self.assertRaises(HTTPException):
            validate_proxy_path(path)

if __name__ == "__main__":
    unittest.main()
