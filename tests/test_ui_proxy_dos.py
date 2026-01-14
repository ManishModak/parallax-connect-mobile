import unittest
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi.testclient import TestClient
from server.app import app
from server.auth import check_password

class TestUIProxyDoS(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        # Override auth
        app.dependency_overrides[check_password] = lambda: True

    def tearDown(self):
        app.dependency_overrides = {}

    @patch("server.apis.ui_proxy.get_async_http_client")
    def test_large_body_dos(self, mock_get_client):
        # Setup mock client
        mock_client_instance = AsyncMock()
        mock_get_client.return_value = mock_client_instance

        # Create a large payload (1.5MB)
        # We use a string for simplicity
        large_payload = "a" * (1024 * 1024 + 500)

        response = self.client.post("/ui-api/test", content=large_payload)

        self.assertEqual(response.status_code, 413)
        self.assertIn("Request body too large", response.text)

    @patch("server.apis.ui_proxy.get_async_http_client")
    def test_normal_body_ok(self, mock_get_client):
        # Setup mock client response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.headers = {"content-type": "application/json"}
        mock_response.content = b'{"ok": true}'

        # Setup mock client
        mock_client_instance = AsyncMock()
        mock_client_instance.request.return_value = mock_response
        mock_get_client.return_value = mock_client_instance

        payload = "small"

        response = self.client.post("/ui-api/test", content=payload)

        self.assertEqual(response.status_code, 200)

if __name__ == "__main__":
    unittest.main()
