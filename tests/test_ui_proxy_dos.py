import unittest
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi import Request, HTTPException
from server.apis.ui_proxy import ui_api_proxy

class TestUIProxyDoS(unittest.IsolatedAsyncioTestCase):
    async def test_uses_stream_not_body(self):
        # Mock Request
        request = MagicMock(spec=Request)
        request.query_params = {}
        request.headers = {}
        request.method = "POST"

        # Mock body() to ensure it's NOT called (after fix)
        # For reproduction, we expect it TO be called.
        request.body = AsyncMock(return_value=b"some content")

        # Mock stream() to yield content
        async def mock_stream():
            yield b"chunk1"
            yield b"chunk2"

        request.stream = MagicMock(return_value=mock_stream())

        # Mock dependency
        with patch("server.apis.ui_proxy.check_password", return_value=True), \
             patch("server.apis.ui_proxy.get_async_http_client", new_callable=AsyncMock) as mock_client:

            mock_client.return_value.request.return_value.status_code = 200
            mock_client.return_value.request.return_value.headers = {"content-type": "application/json"}
            mock_client.return_value.request.return_value.content = b"{}"

            # Call endpoint
            await ui_api_proxy("some/path", request, True)

            # Check behavior
            # CURRENT VULNERABLE STATE: request.body() IS called
            # DESIRED SECURE STATE: request.body() is NOT called

            self.assertFalse(request.body.called, "request.body() should NOT be called")
            self.assertTrue(request.stream.called, "request.stream() SHOULD be called")

    async def test_enforces_limit_on_stream(self):
        # This test ensures that if we stream > 1MB, it raises 413
        request = MagicMock(spec=Request)
        request.query_params = {}
        request.headers = {}
        request.method = "POST"
        request.body = AsyncMock(return_value=b"") # Should not be called

        # Create a stream that yields > 1MB
        async def large_stream():
            chunk = b"x" * 1024 * 1024 # 1MB
            yield chunk
            yield b"excess"

        request.stream = MagicMock(return_value=large_stream())

        with patch("server.apis.ui_proxy.check_password", return_value=True), \
             patch("server.apis.ui_proxy.get_async_http_client", new_callable=AsyncMock):

            with self.assertRaises(HTTPException) as cm:
                await ui_api_proxy("some/path", request, True)

            self.assertEqual(cm.exception.status_code, 413)
