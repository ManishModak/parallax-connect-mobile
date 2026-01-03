
import unittest
from unittest.mock import patch, MagicMock
from server.utils.security import resolve_safe_url, validate_url, is_ip_allowed

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

    # resolve_safe_url tests (Permissive / Pinning)
    @patch("socket.getaddrinfo")
    def test_resolve_safe_url_public(self, mock_getaddrinfo):
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("93.184.216.34", 80))
        ]
        self.assertEqual(resolve_safe_url("http://example.com"), "93.184.216.34")

    @patch("socket.getaddrinfo")
    def test_resolve_safe_url_private(self, mock_getaddrinfo):
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("127.0.0.1", 80))
        ]
        self.assertIsNone(resolve_safe_url("http://localhost"))

    @patch("socket.getaddrinfo")
    def test_resolve_safe_url_mixed(self, mock_getaddrinfo):
        # Should return the safe IP if available
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("127.0.0.1", 80)),
            (None, None, None, None, ("8.8.8.8", 80))
        ]
        self.assertEqual(resolve_safe_url("http://example.com"), "8.8.8.8")

    # validate_url tests (Strict)
    @patch("socket.getaddrinfo")
    def test_validate_url_public(self, mock_getaddrinfo):
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("93.184.216.34", 80))
        ]
        self.assertTrue(validate_url("http://example.com"))

    @patch("socket.getaddrinfo")
    def test_validate_url_private(self, mock_getaddrinfo):
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("127.0.0.1", 80))
        ]
        self.assertFalse(validate_url("http://localhost"))

    @patch("socket.getaddrinfo")
    def test_validate_url_mixed_fails(self, mock_getaddrinfo):
        # Mixed should FAIL in strict mode (validate_url)
        mock_getaddrinfo.return_value = [
            (None, None, None, None, ("8.8.8.8", 80)),
            (None, None, None, None, ("127.0.0.1", 80))
        ]
        self.assertFalse(validate_url("http://example.com"))

if __name__ == "__main__":
    unittest.main()
