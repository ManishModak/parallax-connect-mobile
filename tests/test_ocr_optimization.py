import unittest
from unittest.mock import MagicMock, patch
import asyncio
from server.services.ocr_service import OCRService

class TestOCROptimization(unittest.TestCase):
    def test_ocr_service_accepts_bytearray_paddle(self):
        """Test that OCRService accepts bytearray and passes it to PaddleOCR handler."""
        # Mock dependencies
        with patch('server.services.ocr_service.OCRService._get_reader') as mock_get_reader:
            # Mock reader
            mock_reader = MagicMock()
            mock_get_reader.return_value = ("paddleocr", mock_reader)

            # Create service
            service = OCRService(enabled=True, engine="paddleocr")

            # Create bytearray image data
            image_data = bytearray(b"fake image data")

            # Mock _extract_paddleocr to avoid actual OCR logic and import issues
            with patch.object(service, '_extract_paddleocr') as mock_extract:
                mock_extract.return_value = {"text": "test", "confidence": 1.0}

                # Call synchronous method directly to avoid async complexity in this unit test
                result = service._extract_sync(image_data)

                # Verify result
                self.assertEqual(result["text"], "test")

                # Verify _extract_paddleocr was called with bytearray
                mock_extract.assert_called_once()
                args, _ = mock_extract.call_args
                self.assertIsInstance(args[1], bytearray)

    def test_ocr_service_accepts_bytearray_easyocr(self):
         """Test that OCRService accepts bytearray and passes it to EasyOCR reader."""
         with patch('server.services.ocr_service.OCRService._get_reader') as mock_get_reader:
            mock_reader = MagicMock()
            mock_get_reader.return_value = ("easyocr", mock_reader)

            service = OCRService(enabled=True, engine="easyocr")
            image_data = bytearray(b"fake image data")

            # Mock reader.readtext
            mock_reader.readtext.return_value = []

            # Call synchronous method
            service._extract_sync(image_data)

            # Verify readtext called with bytearray
            # This implicitly tests _extract_easyocr logic too (which just calls readtext)
            mock_reader.readtext.assert_called_once_with(image_data)
            args, _ = mock_reader.readtext.call_args
            self.assertIsInstance(args[0], bytearray)

if __name__ == "__main__":
    unittest.main()
