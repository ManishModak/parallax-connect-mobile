"""
OCR Service supporting multiple OCR engines.

Supports:
- PaddleOCR: Faster, more accurate, 80+ languages (recommended)
- EasyOCR: Simpler, good fallback

Engine is selected at server startup via run_server.py interactive prompt.
"""

import asyncio
import importlib.util
from concurrent.futures import ThreadPoolExecutor
from typing import Optional, Dict, Any, List

from ..logging_setup import get_logger
from ..config import DEBUG_MODE

logger = get_logger(__name__)

_executor = ThreadPoolExecutor(max_workers=2)


class OCRService:
    """
    Server-side OCR supporting multiple backends.

    Provides text extraction from images using either PaddleOCR or EasyOCR.
    Models are downloaded on first use.
    """

    def __init__(
        self,
        engine: str = "easyocr",
        languages: List[str] = None,
        enabled: bool = True,
    ):
        """
        Initialize OCR service.

        Args:
            engine: 'paddleocr' or 'easyocr'
            languages: List of language codes (default: ["en"])
            enabled: Whether OCR is enabled
        """
        self.engine = engine
        self.languages = languages or ["en"]
        self.enabled = enabled
        self._reader = None

        if enabled:
            logger.info(
                f"🔤 OCR Service initialized (engine: {engine}, languages: {self.languages})"
            )
        else:
            logger.info("🔤 OCR Service disabled")

    def _get_reader(self):
        """Lazy-load the OCR reader."""
        if not self.enabled:
            return None

        if self._reader is not None:
            return self._reader

        if self.engine == "paddleocr":
            self._reader = self._init_paddleocr()
        else:
            self._reader = self._init_easyocr()

        return self._reader

    def _init_paddleocr(self):
        """Initialize PaddleOCR."""
        try:
            from paddleocr import PaddleOCR

            logger.info(
                "📥 Loading PaddleOCR models (first-time download if needed)..."
            )

            # Newer PaddleOCR versions removed show_log parameter
            # Try without it first (more compatible), then with it for older versions
            init_kwargs = {
                "use_angle_cls": True,
                "lang": self.languages[0] if self.languages else "en",
            }

            reader = None
            try:
                # First try without show_log (works with newer versions)
                reader = PaddleOCR(**init_kwargs)
            except Exception:
                # If that fails, try with show_log (older versions)
                try:
                    reader = PaddleOCR(show_log=DEBUG_MODE, **init_kwargs)
                except Exception:
                    reader = PaddleOCR(**init_kwargs)

            if reader is None:
                raise RuntimeError("Failed to create PaddleOCR instance")

            logger.info("✅ PaddleOCR models loaded successfully")
            return ("paddleocr", reader)
        except ImportError:
            logger.error(
                "❌ PaddleOCR not installed. Run: pip install paddlepaddle paddleocr"
            )
            return None
        except Exception as e:
            logger.error(f"❌ Failed to initialize PaddleOCR: {e}")
            # Try fallback to EasyOCR
            logger.info("🔄 Falling back to EasyOCR...")
            return self._init_easyocr()

    def _init_easyocr(self):
        """Initialize EasyOCR."""
        import os
        import shutil

        def _cleanup_corrupted_models():
            """Remove corrupted EasyOCR model files."""
            easyocr_dir = os.path.expanduser("~/.EasyOCR/model")
            if os.path.exists(easyocr_dir):
                temp_zip = os.path.join(easyocr_dir, "temp.zip")
                if os.path.exists(temp_zip):
                    try:
                        os.remove(temp_zip)
                        logger.info("🧹 Removed corrupted temp.zip")
                    except Exception:
                        pass

        try:
            import easyocr

            logger.info("📥 Loading EasyOCR models (first-time download if needed)...")

            # Try initialization, cleanup corrupted files on failure and retry once
            for attempt in range(2):
                try:
                    reader = easyocr.Reader(
                        self.languages,
                        gpu=False,
                        verbose=DEBUG_MODE,
                    )
                    logger.info("✅ EasyOCR models loaded successfully")
                    return ("easyocr", reader)
                except Exception as e:
                    if attempt == 0 and (
                        "zip" in str(e).lower()
                        or "temp" in str(e).lower()
                        or "WinError" in str(e)
                    ):
                        logger.warning(
                            f"⚠️ EasyOCR model issue detected, cleaning up: {e}"
                        )
                        _cleanup_corrupted_models()
                        continue
                    raise

        except ImportError:
            logger.error("❌ EasyOCR not installed. Run: pip install easyocr")
            return None
        except Exception as e:
            logger.error(f"❌ Failed to initialize EasyOCR: {e}")
            return None

    def _extract_sync(self, image_data: bytes) -> Dict[str, Any]:
        """Synchronous OCR extraction (runs in thread pool)."""
        reader_tuple = self._get_reader()
        if reader_tuple is None:
            return {"text": "", "confidence": 0.0, "error": "OCR not available"}

        engine_name, reader = reader_tuple

        try:
            if engine_name == "paddleocr":
                return self._extract_paddleocr(reader, image_data)
            else:
                return self._extract_easyocr(reader, image_data)
        except Exception as e:
            logger.error(f"❌ OCR extraction failed: {e}")
            return {"text": "", "confidence": 0.0, "error": str(e)}

    def _extract_paddleocr(self, reader, image_data: bytes) -> Dict[str, Any]:
        """Extract text using PaddleOCR."""
        import numpy as np
        from PIL import Image
        import io

        # Convert bytes to numpy array
        image = Image.open(io.BytesIO(image_data))
        img_array = np.array(image)

        results = reader.ocr(img_array, cls=True)

        texts = []
        total_confidence = 0.0
        count = 0

        if results and results[0]:
            for line in results[0]:
                text = line[1][0]
                confidence = line[1][1]
                texts.append(text)
                total_confidence += confidence
                count += 1

        combined_text = " ".join(texts)
        avg_confidence = total_confidence / count if count > 0 else 0.0

        return {
            "text": combined_text,
            "confidence": round(avg_confidence, 2),
            "segments": count,
            "engine": "paddleocr",
        }

    def _extract_easyocr(self, reader, image_data: bytes) -> Dict[str, Any]:
        """Extract text using EasyOCR."""
        results = reader.readtext(image_data)

        texts = []
        total_confidence = 0.0

        for bbox, text, confidence in results:
            texts.append(text)
            total_confidence += confidence

        combined_text = " ".join(texts)
        avg_confidence = total_confidence / len(results) if results else 0.0

        return {
            "text": combined_text,
            "confidence": round(avg_confidence, 2),
            "segments": len(results),
            "engine": "easyocr",
        }

    async def extract_text(self, image_data: bytes) -> str:
        """
        Extract text from image bytes.

        Args:
            image_data: Raw image bytes (JPEG, PNG, etc.)

        Returns:
            Extracted text string
        """
        if not self.enabled:
            return "[OCR disabled on server]"

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(_executor, self._extract_sync, image_data)
        return result.get("text", "")

    async def analyze_image(self, image_data: bytes) -> Dict[str, Any]:
        """
        Detailed image analysis with OCR.

        Args:
            image_data: Raw image bytes

        Returns:
            Dict with text, confidence, segment count, engine used
        """
        if not self.enabled:
            return {"text": "", "error": "OCR disabled", "enabled": False}

        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(_executor, self._extract_sync, image_data)
        result["enabled"] = True
        return result

    def is_available(self) -> bool:
        """Check if OCR is enabled and engine is installed."""
        if not self.enabled:
            return False

        if self.engine == "paddleocr":
            return importlib.util.find_spec("paddleocr") is not None
        else:
            return importlib.util.find_spec("easyocr") is not None

    def get_engine_name(self) -> str:
        """Get the configured engine name."""
        return self.engine if self.enabled else "disabled"


# Singleton instance
_ocr_service: Optional[OCRService] = None


def get_ocr_service() -> Optional[OCRService]:
    """Get the global OCR service instance."""
    return _ocr_service


def init_ocr_service(
    enabled: bool = True,
    engine: str = "easyocr",
    languages: List[str] = None,
) -> OCRService:
    """Initialize the global OCR service."""
    global _ocr_service
    _ocr_service = OCRService(engine=engine, languages=languages, enabled=enabled)
    return _ocr_service
