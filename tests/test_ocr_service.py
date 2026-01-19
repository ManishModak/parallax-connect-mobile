import unittest
from unittest.mock import MagicMock, patch
import sys
import asyncio
import io

# Mock dependencies
sys.modules["numpy"] = MagicMock()
sys.modules["PIL"] = MagicMock()
sys.modules["paddleocr"] = MagicMock()
sys.modules["easyocr"] = MagicMock()
sys.modules["httpx"] = MagicMock()
sys.modules["fastapi"] = MagicMock()
sys.modules["fastapi.responses"] = MagicMock()
sys.modules["ddgs"] = MagicMock()
sys.modules["bs4"] = MagicMock()
sys.modules["uvicorn"] = MagicMock()
sys.modules["python_multipart"] = MagicMock()
sys.modules["qrcode"] = MagicMock()
sys.modules["pydantic"] = MagicMock()

# Mock internal modules
sys.modules["server.auth"] = MagicMock()
sys.modules["server.config"] = MagicMock()
sys.modules["server.models"] = MagicMock()
sys.modules["server.logging_setup"] = MagicMock()
sys.modules["server.services.http_client"] = MagicMock()
sys.modules["server.utils.error_handler"] = MagicMock()
sys.modules["server.utils.request_validator"] = MagicMock()
sys.modules["server.apis.chat.helpers"] = MagicMock()
sys.modules["server.apis.chat.mock_handlers"] = MagicMock()
sys.modules["server.apis.chat.proxy_handlers"] = MagicMock()
sys.modules["server.apis.chat.openai_compat"] = MagicMock()

from server.services.ocr_service import OCRService

class TestOCROptimization(unittest.TestCase):
    def test_paddleocr_accepts_bytearray(self):
        """Verify that PaddleOCR path handles bytearray via io.BytesIO."""
        # Setup
        service = OCRService(engine="paddleocr", enabled=True)

        # Mock the reader
        mock_reader = MagicMock()
        mock_reader.predict.return_value = {"rec_text": [("extracted text", 0.99)]}
        service._reader = ("paddleocr", mock_reader)

        # Test data: bytearray
        data = bytearray(b"fake_image_data")

        # Ensure the mock for Image works
        mock_image_class = sys.modules["PIL"].Image
        mock_image_class.open.return_value = MagicMock()

        # Execute
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(service.analyze_image(data))
        finally:
            loop.close()

        # Verify
        mock_image_class.open.assert_called()
        args, _ = mock_image_class.open.call_args
        bytes_io_obj = args[0]
        self.assertEqual(bytes_io_obj.getvalue(), data)

    def test_easyocr_accepts_bytearray(self):
        """Verify that EasyOCR path passes bytearray to readtext."""
        service = OCRService(engine="easyocr", enabled=True)
        mock_reader = MagicMock()
        mock_reader.readtext.return_value = []
        service._reader = ("easyocr", mock_reader)

        data = bytearray(b"fake_image_data")

        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            result = loop.run_until_complete(service.analyze_image(data))
        finally:
            loop.close()

        mock_reader.readtext.assert_called_with(data)

    def test_endpoints_import(self):
        """Verify that server.apis.chat.endpoints can be imported (syntax check)."""
        import server.apis.chat.endpoints

if __name__ == "__main__":
    unittest.main()
