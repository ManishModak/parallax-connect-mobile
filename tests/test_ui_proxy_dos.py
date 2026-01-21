
import unittest
from unittest.mock import MagicMock, patch, AsyncMock
from fastapi.testclient import TestClient
from fastapi import HTTPException
from server.app import app
from server.auth import check_password

class TestUIProxyDoS(unittest.TestCase):
    def setUp(self):
        # Override dependency to bypass authentication
        app.dependency_overrides[check_password] = lambda: True
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides = {}

    @patch("server.apis.ui_proxy.get_async_http_client")
    def test_proxy_small_body(self, mock_get_client):
        # Setup mock client
        mock_client_instance = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.content = b"Success"
        mock_response.headers = {"content-type": "text/plain"}
        mock_client_instance.request.return_value = mock_response
        mock_get_client.return_value = mock_client_instance

        # Send small payload
        response = self.client.post("/ui-api/test", content="small payload")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.content, b"Success")

    @patch("server.apis.ui_proxy.get_async_http_client")
    def test_proxy_large_body(self, mock_get_client):
        # Send large payload > 1MB
        # 1MB = 1000000 bytes approx (code uses 1_000_000)
        large_payload = "a" * 1_000_001

        response = self.client.post("/ui-api/test", content=large_payload)

        self.assertEqual(response.status_code, 413)
        self.assertIn("Request body too large", response.text)
