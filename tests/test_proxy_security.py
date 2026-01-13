
import unittest
from fastapi.testclient import TestClient
from server.app import app
from server.auth import check_password

# Override dependency to bypass auth
app.dependency_overrides[check_password] = lambda: True

class TestProxySecurity(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_path_traversal_attempts(self):
        """
        Test various path traversal attempts against the UI proxy.
        Should return 400 Bad Request if blocked.
        """
        attempts = [
            # "/ui/../etc/passwd",  <-- Client normalizes this to /etc/passwd (404), so it doesn't hit proxy
            "/ui/%2e%2e/etc/passwd",
            "/ui/%252e%252e/etc/passwd", # Double encoded
            "/ui/%25252e%25252e/etc/passwd", # Triple encoded
            "/ui/..%2fetc/passwd",
            "/ui/%2e%2e%2fetc/passwd"
        ]

        for path in attempts:
            with self.subTest(path=path):
                response = self.client.get(path)
                self.assertEqual(
                    response.status_code,
                    400,
                    f"Path {path} was not blocked! Status: {response.status_code}"
                )
                self.assertIn("Invalid path", response.text)

if __name__ == "__main__":
    unittest.main()
