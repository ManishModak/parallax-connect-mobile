import unittest
from server.utils.security import validate_proxy_path
from server.app import app
from fastapi.testclient import TestClient

class TestProxySecurity(unittest.TestCase):
    def test_validate_proxy_path_valid(self):
        """Test valid paths."""
        self.assertEqual(validate_proxy_path("js/app.js"), "js/app.js")
        self.assertEqual(validate_proxy_path("css/style.css"), "css/style.css")
        self.assertEqual(validate_proxy_path("api/v1/status"), "api/v1/status")

    def test_validate_proxy_path_traversal(self):
        """Test simple traversal."""
        with self.assertRaises(ValueError):
            validate_proxy_path("../secret")
        with self.assertRaises(ValueError):
            validate_proxy_path("foo/../../etc/passwd")

    def test_validate_proxy_path_encoded(self):
        """Test encoded traversal."""
        # %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e%2e/secret")
        # %2E%2E -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2E%2E/secret")

    def test_validate_proxy_path_double_encoded(self):
        """Test double encoded traversal."""
        # %252e%252e -> %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%252e%252e/secret")

    def test_validate_proxy_path_triple_encoded(self):
        """Test triple encoded traversal."""
        # %25252e%25252e -> %252e%252e -> %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%25252e%25252e/secret")

    def test_validate_proxy_path_null_byte(self):
        """Test null byte injection."""
        with self.assertRaises(ValueError):
            validate_proxy_path("image.png%00.php")

    def test_validate_proxy_path_backslash(self):
        """Test backslash."""
        with self.assertRaises(ValueError):
            validate_proxy_path("..\\windows")

    def test_validate_proxy_path_leading_slash(self):
        """Test leading slash."""
        with self.assertRaises(ValueError):
            validate_proxy_path("/etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("%2fetc/passwd")

class TestProxyIntegration(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_ui_proxy_block_traversal(self):
        """Test that the endpoint blocks traversal."""
        # Test double encoded
        # %252e%252e -> server sees %2e%2e -> validate_proxy_path decodes to .. -> error
        resp = self.client.get("/ui/%252e%252e/secret")
        self.assertEqual(resp.status_code, 400)
