
import unittest
from unittest.mock import patch, MagicMock
from server.utils.security import validate_url, is_ip_allowed

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

    def test_validate_proxy_path(self):
        from server.utils.security import validate_proxy_path

        # Valid paths
        self.assertEqual(validate_proxy_path("assets/style.css"), "assets/style.css")
        self.assertEqual(validate_proxy_path("api/v1/user"), "api/v1/user")

        # Traversal attempts
        with self.assertRaises(ValueError):
            validate_proxy_path("..")
        with self.assertRaises(ValueError):
            validate_proxy_path("../etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("foo/../bar")

        # Encoded traversal
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e%2e")
        with self.assertRaises(ValueError):
            validate_proxy_path("%2e%2e/etc/passwd")

        # Double encoded traversal
        with self.assertRaises(ValueError):
            validate_proxy_path("%252e%252e")
        with self.assertRaises(ValueError):
            validate_proxy_path("%252e%252e/etc/passwd")

        # Triple encoded
        with self.assertRaises(ValueError):
            validate_proxy_path("%25252e%25252e")

        # Absolute paths
        with self.assertRaises(ValueError):
            validate_proxy_path("/etc/passwd")
        with self.assertRaises(ValueError):
            validate_proxy_path("%2fetc%2fpasswd")  # /etc/passwd

        # Backslashes
        with self.assertRaises(ValueError):
            validate_proxy_path("C:\\Windows")
        with self.assertRaises(ValueError):
            validate_proxy_path("%5c")

if __name__ == "__main__":
    unittest.main()
