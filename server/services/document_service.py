"""
Document Service for server-side PDF/document text extraction.

Supports:
- PyMuPDF (fitz): Fast, accurate, recommended
- pdfplumber: Good alternative, handles tables well

Selected at server startup via run_server.py interactive prompt.
"""

import importlib.util
from typing import Optional, Dict, Any
from pathlib import Path

from ..logging_setup import get_logger

logger = get_logger(__name__)


class DocumentService:
    """
    Server-side document text extraction.

    Extracts text from PDFs using PyMuPDF or pdfplumber.
    """

    def __init__(self, engine: str = "pymupdf", enabled: bool = True):
        """
        Initialize document service.

        Args:
            engine: 'pymupdf' or 'pdfplumber'
            enabled: Whether document processing is enabled
        """
        self.engine = engine
        self.enabled = enabled

        if enabled:
            logger.info(f"📄 Document Service initialized (engine: {engine})")
        else:
            logger.info("📄 Document Service disabled")

    def extract_text(self, file_bytes: bytes, filename: str = "") -> Dict[str, Any]:
        """
        Extract text from document bytes.

        Args:
            file_bytes: Raw file bytes
            filename: Original filename (for extension detection)

        Returns:
            Dict with text, page_count, engine used
        """
        if not self.enabled:
            return {
                "text": "",
                "error": "Document processing disabled",
                "enabled": False,
            }

        ext = Path(filename).suffix.lower() if filename else ".pdf"

        if ext == ".pdf":
            return self._extract_pdf(file_bytes)
        elif ext in (".txt", ".md", ".json", ".xml", ".csv"):
            # Plain text files
            try:
                text = file_bytes.decode("utf-8")
                return {"text": text, "page_count": 1, "engine": "text"}
            except UnicodeDecodeError:
                return {
                    "text": "",
                    "error": "Could not decode text file",
                    "enabled": True,
                }
        else:
            return {
                "text": "",
                "error": f"Unsupported file type: {ext}",
                "enabled": True,
            }

    def _extract_pdf(self, file_bytes: bytes) -> Dict[str, Any]:
        """Extract text from PDF using configured engine."""
        if self.engine == "pymupdf":
            return self._extract_with_pymupdf(file_bytes)
        else:
            return self._extract_with_pdfplumber(file_bytes)

    def _extract_with_pymupdf(self, file_bytes: bytes) -> Dict[str, Any]:
        """Extract text using PyMuPDF (fitz)."""
        try:
            import fitz  # PyMuPDF

            doc = fitz.open(stream=file_bytes, filetype="pdf")
            text_parts = []

            for page in doc:
                text_parts.append(page.get_text())

            doc.close()

            return {
                "text": "\n".join(text_parts),
                "page_count": len(text_parts),
                "engine": "pymupdf",
                "enabled": True,
            }
        except ImportError:
            logger.error("❌ PyMuPDF not installed. Run: pip install pymupdf")
            return {"text": "", "error": "PyMuPDF not installed", "enabled": True}
        except Exception as e:
            logger.error(f"❌ PDF extraction failed: {e}")
            return {"text": "", "error": str(e), "enabled": True}

    def _extract_with_pdfplumber(self, file_bytes: bytes) -> Dict[str, Any]:
        """Extract text using pdfplumber."""
        try:
            import pdfplumber
            import io

            text_parts = []
            with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
                for page in pdf.pages:
                    text = page.extract_text()
                    if text:
                        text_parts.append(text)

            return {
                "text": "\n".join(text_parts),
                "page_count": len(text_parts),
                "engine": "pdfplumber",
                "enabled": True,
            }
        except ImportError:
            logger.error("❌ pdfplumber not installed. Run: pip install pdfplumber")
            return {"text": "", "error": "pdfplumber not installed", "enabled": True}
        except Exception as e:
            logger.error(f"❌ PDF extraction failed: {e}")
            return {"text": "", "error": str(e), "enabled": True}

    def is_available(self) -> bool:
        """Check if document processing is enabled and engine installed."""
        if not self.enabled:
            return False

        if self.engine == "pymupdf":
            return importlib.util.find_spec("fitz") is not None
        else:
            return importlib.util.find_spec("pdfplumber") is not None

    def get_engine_name(self) -> str:
        """Get the configured engine name."""
        return self.engine if self.enabled else "disabled"


# Singleton instance
_doc_service: Optional[DocumentService] = None


def get_document_service() -> Optional[DocumentService]:
    """Get the global document service instance."""
    return _doc_service


def init_document_service(
    enabled: bool = True,
    engine: str = "pymupdf",
) -> DocumentService:
    """Initialize the global document service."""
    global _doc_service
    _doc_service = DocumentService(engine=engine, enabled=enabled)
    return _doc_service
