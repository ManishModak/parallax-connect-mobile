
import unittest
from unittest.mock import patch, MagicMock, AsyncMock
import sys

from fastapi.responses import HTMLResponse

# We cannot easily avoid importing ui_proxy if we want to test it,
# but we can do it inside the test method or setup if we want to control imports more strictly.
# However, standard practice is to import at top level or setup.
# The issue with sys.modules pollution is valid.
# Instead of patching sys.modules globally, we should rely on standard mocking
# or ensure we clean up. But unittest doesn't easily support unimporting.

# A better approach is to not mock sys.modules but mock the dependencies where they are used.
# server.apis.ui_proxy imports:
# from ..auth import check_password
# from ..services.http_client import get_async_http_client
#
# We can mock these in `server.apis.ui_proxy` namespace using patch.

class TestUIProxySecurity(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        # We need to ensure server.apis.ui_proxy is imported with our mocks if it's not already.
        # But since we can't easily unload modules, we just patch the imported symbols.
        pass

    @patch('server.apis.ui_proxy.get_async_http_client', new_callable=AsyncMock)
    @patch('server.apis.ui_proxy.DEBUG_MODE', False)
    async def test_ui_index_error_sanitized(self, mock_get_client):
        from server.apis import ui_proxy

        # Setup mock to raise exception
        mock_client = AsyncMock()
        mock_client.get.side_effect = Exception("Internal Secret Info")
        mock_get_client.return_value = mock_client

        # Call the function
        response = await ui_proxy.ui_index(True)

        # Verify response
        self.assertIsInstance(response, HTMLResponse)
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("Internal Secret Info", response.body.decode())
        self.assertIn("An unexpected error occurred", response.body.decode())

    @patch('server.apis.ui_proxy.get_async_http_client', new_callable=AsyncMock)
    @patch('server.apis.ui_proxy.DEBUG_MODE', True)
    async def test_ui_index_error_exposed_debug(self, mock_get_client):
        from server.apis import ui_proxy

        # Setup mock to raise exception
        mock_client = AsyncMock()
        mock_client.get.side_effect = Exception("Internal Secret Info")
        mock_get_client.return_value = mock_client

        # Call the function
        response = await ui_proxy.ui_index(True)

        # Verify response
        self.assertIsInstance(response, HTMLResponse)
        self.assertEqual(response.status_code, 503)
        self.assertIn("Internal Secret Info", response.body.decode())

    @patch('server.apis.ui_proxy.get_async_http_client', new_callable=AsyncMock)
    @patch('server.apis.ui_proxy.DEBUG_MODE', False)
    async def test_ui_proxy_error_sanitized(self, mock_get_client):
        from server.apis import ui_proxy

        # Setup mock to raise exception
        mock_client = AsyncMock()
        mock_client.get.side_effect = Exception("Internal Secret Info")
        mock_get_client.return_value = mock_client

        # Call the function
        request = MagicMock()
        request.query_params = ""
        response = await ui_proxy.ui_proxy("some/path", request, True)

        # Verify response
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("Internal Secret Info", response.body.decode())
        self.assertIn("An unexpected error occurred", response.body.decode())

    @patch('server.apis.ui_proxy.get_async_http_client', new_callable=AsyncMock)
    @patch('server.apis.ui_proxy.DEBUG_MODE', False)
    async def test_ui_api_proxy_error_sanitized(self, mock_get_client):
        from server.apis import ui_proxy

        # Setup mock to raise exception
        mock_client = AsyncMock()
        # ui_api_proxy uses client.request
        mock_client.request.side_effect = Exception("Internal Secret Info")
        mock_get_client.return_value = mock_client

        # Call the function
        request = MagicMock()
        request.query_params = ""
        request.method = "GET"
        request.body = AsyncMock(return_value=b"")
        request.headers = {}

        response = await ui_proxy.ui_api_proxy("api/path", request, True)

        # Verify response
        self.assertEqual(response.status_code, 503)
        self.assertNotIn("Internal Secret Info", response.body.decode())
        self.assertIn("An unexpected error occurred", response.body.decode())

if __name__ == "__main__":
    unittest.main()
