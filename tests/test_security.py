
import unittest
from unittest.mock import patch, MagicMock
from server.utils.security import validate_url, is_ip_allowed, validate_proxy_path

class TestSecurity(unittest.TestCase):
    def test_is_ip_allowed(self):
        # Public IPs
        self.assertTrue(is_ip_allowed("8.8.8.8"))
        self.assertTrue(is_ip_allowed("1.1.1.1"))

        # Private IPs
        self.assertFalse(is_ip_allowed("127.0.0.1"))
        self.assertFalse(is_ip_allowed("10.0.0.1"))
        self.assertFalse(is_ip_allowed("192.168.1.1"))
        self.assertFalse(is_ip_allowed("172.16.0.1"))
        self.assertFalse(is_ip_allowed("0.0.0.0"))
        self.assertFalse(is_ip_allowed("::1"))
        self.assertFalse(is_ip_allowed("fe80::1"))

    @patch("socket.getaddrinfo")
    def test_validate_url_public(self, mock_getaddrinfo):
        # Simulate public IP resolution
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("93.184.216.34", 80))
        ]
        self.assertTrue(validate_url("http://example.com"))

    @patch("socket.getaddrinfo")
    def test_validate_url_private(self, mock_getaddrinfo):
        # Simulate private IP resolution
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("127.0.0.1", 80))
        ]
        self.assertFalse(validate_url("http://localhost"))

    @patch("socket.getaddrinfo")
    def test_validate_url_rebinding_attempt(self, mock_getaddrinfo):
        # Simulate one public and one private IP (DNS rebinding scenario - naive check)
        # Note: validate_url blocks if ANY IP is private
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("8.8.8.8", 80)),
            (None, None, None, None, ("127.0.0.1", 80))
        ]
        self.assertFalse(validate_url("http://attack.com"))

    def test_validate_proxy_path_valid(self):
        self.assertEqual(validate_proxy_path("static/main.js"), "static/main.js")
        self.assertEqual(validate_proxy_path("api/v1/data"), "api/v1/data")
        self.assertEqual(validate_proxy_path("foo.bar"), "foo.bar")

    def test_validate_proxy_path_traversal(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("..")
        with self.assertRaises(ValueError):
            validate_proxy_path("../etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("foo/../bar")

    def test_validate_proxy_path_encoded(self):
        # %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e%2e")
        # %2E%2E -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%2E%2E")

    def test_validate_proxy_path_double_encoded(self):
        # %252e%252e -> %2e%2e -> ..
        with self.assertRaises(ValueError):
            validate_proxy_path("%252e%252e")

    def test_validate_proxy_path_null_byte(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("foo%00bar")

    def test_validate_proxy_path_backslash(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("foo\\bar")

    def test_validate_proxy_path_absolute(self):
        with self.assertRaises(ValueError):
            validate_proxy_path("/etc/passwd")

if __name__ == "__main__":
    unittest.main()
