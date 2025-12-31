
import asyncio
import unittest
from unittest.mock import patch, MagicMock, AsyncMock
from fastapi import FastAPI, Depends, Request
from fastapi.testclient import TestClient
from server.apis.ui_proxy import router as ui_router
from server.auth import check_password

# Override check_password dependency to bypass auth
async def mock_check_password():
    return True

app = FastAPI()
app.include_router(ui_router)
app.dependency_overrides[check_password] = mock_check_password

class TestUIProxySecurity(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    @patch("server.apis.ui_proxy.get_async_http_client", new_callable=AsyncMock)
    def test_error_leakage_ui_proxy(self, mock_get_client):
        # The mock_get_client is an AsyncMock, so awaiting it returns its return_value.
        # We want the *client* to raise an exception when .get() is called.
        mock_client_instance = MagicMock()
        mock_client_instance.get.side_effect = Exception("SECRET_INTERNAL_IP: 10.0.0.1 connection failed")

        # When get_async_http_client() is awaited, it returns mock_client_instance
        mock_get_client.return_value = mock_client_instance

        response = self.client.get("/ui/some/path")

        # VERIFICATION: The response should NOT contain the secret
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("SECRET_INTERNAL_IP", response.text)
        self.assertIn("An unexpected error occurred", response.text)
        print("\n[VERIFIED] Secret IP correctly hidden in response.")

    @patch("server.apis.ui_proxy.get_async_http_client", new_callable=AsyncMock)
    def test_error_leakage_ui_index(self, mock_get_client):
        # Simulate an exception
        mock_client_instance = MagicMock()
        mock_client_instance.get.side_effect = Exception("SECRET_DATABASE_PATH: /etc/passwd denied")

        mock_get_client.return_value = mock_client_instance

        response = self.client.get("/ui/")

        # VERIFICATION: The response should NOT contain the secret
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("SECRET_DATABASE_PATH", response.text)
        self.assertIn("Connection failed", response.text)
        print("[VERIFIED] Secret path correctly hidden in UI index.")

if __name__ == "__main__":
    unittest.main()
