
import unittest
import asyncio
from unittest.mock import MagicMock, AsyncMock, patch
from fastapi import Request, HTTPException
from fastapi.testclient import TestClient

from server.apis.ui_proxy import ui_api_proxy

class TestUIProxyDoS(unittest.IsolatedAsyncioTestCase):
    async def test_large_body_dos_protection(self):
        """
        Verify that the handler raises 413 immediately when the body size exceeds the limit,
        without reading the entire potentially huge stream.
        """

        # Mock Request object
        mock_request = MagicMock(spec=Request)
        mock_request.method = "POST"
        mock_request.query_params = ""
        mock_request.headers = {}

        # Mock request.stream() to yield chunks
        # We simulate a stream that is larger than 1MB
        # Let's say we send 2 chunks of 600KB
        chunk_size = 600_000
        large_chunk = b"a" * chunk_size

        async def mock_stream_iterator():
            yield large_chunk
            yield large_chunk # Total 1.2MB
            yield large_chunk # Total 1.8MB

        mock_request.stream = MagicMock(return_value=mock_stream_iterator())

        # Mock body() to ensure it is NOT called
        mock_request.body = AsyncMock(side_effect=Exception("Should not call body()!"))

        # We need to mock get_async_http_client too so it doesn't actually make network calls
        with patch("server.apis.ui_proxy.get_async_http_client") as mock_get_client:
            mock_client = AsyncMock()
            mock_get_client.return_value = mock_client

            # Now we expect 413 to be RAISED, not caught and turned into 503
            try:
                await ui_api_proxy(path="some/api", request=mock_request, _=True)
            except HTTPException as e:
                self.assertEqual(e.status_code, 413)
                self.assertEqual(e.detail, "Request body too large (>1MB)")
            except Exception as e:
                self.fail(f"Raised unexpected exception: {e}")
            else:
                self.fail("Did not raise HTTPException(413)")

    async def test_small_body_pass(self):
        """
        Verify that a small body passes through correctly.
        """
        mock_request = MagicMock(spec=Request)
        mock_request.method = "POST"
        mock_request.query_params = ""
        mock_request.headers = {}

        small_chunk = b"small payload"
        async def mock_stream_iterator():
            yield small_chunk

        mock_request.stream = MagicMock(return_value=mock_stream_iterator())
        mock_request.body = AsyncMock(side_effect=Exception("Should not call body()!"))

        with patch("server.apis.ui_proxy.get_async_http_client") as mock_get_client:
            mock_client = AsyncMock()
            mock_get_client.return_value = mock_client
            # Mock the client response
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.content = b"OK"
            mock_response.headers = {"content-type": "application/json"}
            mock_client.request.return_value = mock_response

            response = await ui_api_proxy(path="test", request=mock_request, _=True)
            self.assertEqual(response.status_code, 200)

            # Verify that client.request was called with the correct content
            mock_client.request.assert_called_once()
            call_args = mock_client.request.call_args
            self.assertEqual(call_args.kwargs['content'], small_chunk)

if __name__ == "__main__":
    unittest.main()
