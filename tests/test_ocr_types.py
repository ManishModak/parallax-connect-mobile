
import unittest
from unittest.mock import MagicMock, patch
import io
from server.services.ocr_service import OCRService, init_ocr_service

class TestOCRTypes(unittest.TestCase):
    def setUp(self):
        self.mock_paddle = MagicMock()
        self.mock_easy = MagicMock()

    @patch('server.services.ocr_service.OCRService._init_paddleocr')
    def test_paddle_bytearray(self, mock_init):
        # Setup mock
        mock_reader = MagicMock()
        # Mocking what _init_paddleocr returns: (engine_name, reader_instance)
        mock_init.return_value = ("paddleocr", mock_reader)

        # Setup service
        service = OCRService(engine="paddleocr", enabled=True)

        # Setup bytearray input
        data = bytearray(b"fake image data")

        # Mock PIL and numpy inside _extract_paddleocr using patch
        with patch('PIL.Image.open') as mock_open, \
             patch('numpy.array') as mock_array:

            # Setup PIL mock to return something that numpy can use
            mock_image = MagicMock()
            mock_open.return_value = mock_image

            # Setup reader result
            mock_reader.ocr.return_value = [[("text", 0.9)]]

            # Execute
            result = service._extract_sync(data)

            # Verify
            self.assertEqual(result["engine"], "paddleocr")
            # Verify BytesIO was called with bytearray (implicitly via Image.open)
            # Since Image.open is mocked, we check what it was called with
            args, _ = mock_open.call_args
            # args[0] should be a BytesIO object
            self.assertIsInstance(args[0], io.BytesIO)
            # Check the content of BytesIO
            self.assertEqual(args[0].getvalue(), b"fake image data")

    @patch('server.services.ocr_service.OCRService._init_easyocr')
    def test_easyocr_bytearray(self, mock_init):
        # Setup mock
        mock_reader = MagicMock()
        mock_init.return_value = ("easyocr", mock_reader)

        # Setup service
        service = OCRService(engine="easyocr", enabled=True)

        # Setup bytearray input
        data = bytearray(b"fake image data")

        # Setup reader result
        mock_reader.readtext.return_value = [([], "text", 0.9)]

        # Execute
        result = service._extract_sync(data)

        # Verify
        self.assertEqual(result["engine"], "easyocr")
        # Verify readtext was called with bytearray
        mock_reader.readtext.assert_called_once_with(data)

if __name__ == '__main__':
    unittest.main()
