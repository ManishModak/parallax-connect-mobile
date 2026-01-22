import unittest
from server.utils.security import validate_proxy_path

class TestProxySecurity(unittest.TestCase):
    def test_validate_proxy_path_valid(self):
        self.assertTrue(validate_proxy_path("valid/path"))
        self.assertTrue(validate_proxy_path("index.html"))
        self.assertTrue(validate_proxy_path("static/css/style.css"))
        self.assertTrue(validate_proxy_path("foo-bar_baz"))

    def test_validate_proxy_path_traversal(self):
        self.assertFalse(validate_proxy_path("../etc/passwd"))
        self.assertFalse(validate_proxy_path(".."))
        self.assertFalse(validate_proxy_path("foo/../bar"))
        self.assertFalse(validate_proxy_path("foo/../../bar"))

    def test_validate_proxy_path_absolute(self):
        self.assertFalse(validate_proxy_path("/etc/passwd"))
        self.assertFalse(validate_proxy_path("/index.html"))

    def test_validate_proxy_path_backslash(self):
        self.assertFalse(validate_proxy_path("win\\path"))
        self.assertFalse(validate_proxy_path("\\etc\\passwd"))

    def test_validate_proxy_path_encoded(self):
        # %2e%2e is ..
        self.assertFalse(validate_proxy_path("%2e%2e/etc/passwd"))
        self.assertFalse(validate_proxy_path("%2E%2E/etc/passwd"))
        self.assertFalse(validate_proxy_path("foo/%2e%2e/bar"))

    def test_validate_proxy_path_double_encoded(self):
        # %252e%252e is %2e%2e which is ..
        self.assertFalse(validate_proxy_path("%252e%252e/etc/passwd"))
        self.assertFalse(validate_proxy_path("%252E%252E/etc/passwd"))
        # %252f is %2f is /
        self.assertFalse(validate_proxy_path("%252fetc/passwd"))

    def test_validate_proxy_path_triple_encoded(self):
        # %25252e%25252e -> %252e%252e -> %2e%2e -> ..
        self.assertFalse(validate_proxy_path("%25252e%25252e/etc/passwd"))

    def test_validate_proxy_path_null_byte(self):
        self.assertFalse(validate_proxy_path("valid/path\0"))
        self.assertFalse(validate_proxy_path("valid%00path"))

    def test_validate_proxy_path_utf8_normalization(self):
        # Ensure we don't crash on utf8, though traversal is usually ascii
        self.assertTrue(validate_proxy_path("café/babe"))
