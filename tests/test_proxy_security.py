
import unittest
from fastapi.testclient import TestClient
from server.app import app

class TestProxySecurity(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_path_traversal_blocked(self):
        """
        Verify that path traversal attempts (simple and encoded) are blocked.
        """
        # 1. Simple encoded traversal (%2e%2e)
        response = self.client.get("/ui/%2e%2e/etc/passwd")
        self.assertEqual(response.status_code, 400, "Should block simple encoded traversal")

        # 2. Triple encoded traversal (%25252e%25252e)
        # Previously bypassed the check. Now should be blocked by recursive decoding.
        response = self.client.get("/ui/%25252e%25252e/etc/passwd")

        if response.status_code == 400:
             print("\n[INFO] Triple encoding correctly BLOCKED by validate_proxy_path.")
        else:
             print(f"\n[INFO] Triple encoding NOT blocked? Status: {response.status_code}")

        self.assertEqual(response.status_code, 400, "Should block triple encoded traversal")

if __name__ == "__main__":
    unittest.main()
