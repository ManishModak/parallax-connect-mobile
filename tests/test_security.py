
import unittest
from unittest.mock import patch, MagicMock
from fastapi import HTTPException
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

    def test_validate_proxy_path_safe(self):
        # Safe paths
        self.assertEqual(validate_proxy_path("assets/main.js"), "assets/main.js")
        self.assertEqual(validate_proxy_path("images/logo.png"), "images/logo.png")
        self.assertEqual(validate_proxy_path("api/v1/status"), "api/v1/status")

    def test_validate_proxy_path_traversal(self):
        # Standard traversal
        with self.assertRaises(HTTPException):
            validate_proxy_path("../secret")
        with self.assertRaises(HTTPException):
            validate_proxy_path("foo/../../etc/passwd")

    def test_validate_proxy_path_encoded(self):
        # Encoded traversal
        with self.assertRaises(HTTPException):
            validate_proxy_path("%2e%2e/secret")
        with self.assertRaises(HTTPException):
            validate_proxy_path("..%2fsecret")
        with self.assertRaises(HTTPException):
            validate_proxy_path("%2e%2e%2fsecret")

    def test_validate_proxy_path_double_encoded(self):
        # Double encoded traversal
        with self.assertRaises(HTTPException):
            validate_proxy_path("%252e%252e/secret")
        with self.assertRaises(HTTPException):
            validate_proxy_path("%252e%252e%252fsecret")

    def test_validate_proxy_path_triple_encoded(self):
        # Triple encoded traversal
        with self.assertRaises(HTTPException):
            validate_proxy_path("%25252e%25252e/secret")

    def test_validate_proxy_path_absolute(self):
        # Absolute paths
        with self.assertRaises(HTTPException):
            validate_proxy_path("/etc/passwd")
        with self.assertRaises(HTTPException):
            validate_proxy_path("/secret")

    def test_validate_proxy_path_encoded_absolute(self):
        # Encoded absolute path
        with self.assertRaises(HTTPException):
            validate_proxy_path("%2fetc%2fpasswd")

if __name__ == "__main__":
    unittest.main()
