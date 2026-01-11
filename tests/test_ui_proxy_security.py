import unittest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi.testclient import TestClient
from server.app import app
from server.auth import check_password

# Override dependency to bypass auth
app.dependency_overrides[check_password] = lambda: True

class TestUIProxySecurity(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    @patch("server.apis.ui_proxy.get_async_http_client")
    def test_path_traversal_double_encoded(self, mock_get_client):
        """Test double encoded path traversal '%252e%252e'"""
        mock_client_instance = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.text = "SECRET_FILE_CONTENT"
        mock_response.headers = {"content-type": "text/html"}
        mock_client_instance.get.return_value = mock_response
        mock_get_client.return_value = mock_client_instance

        # We want to send %252e%252e which decodes to %2e%2e
        # If the app is vulnerable, it sees %2e%2e (no "..") and forwards it.
        # This checks that our validation catches hidden traversal attempts.
        response = self.client.get("/ui/%252e%252e/etc/passwd")

        self.assertEqual(response.status_code, 400, "Should block double-encoded traversal")
