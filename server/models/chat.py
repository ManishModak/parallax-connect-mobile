"""Chat request/response models."""

from typing import List, Optional
from pydantic import BaseModel, model_validator


class ChatRequest(BaseModel):
    """
    Chat request model with support for advanced AI sampling parameters.

    PARALLAX SUPPORT STATUS:
    ========================
    Currently WORKING: max_tokens, temperature, top_p, top_k
    NOT YET IMPLEMENTED: repetition_penalty, presence_penalty, frequency_penalty, stop
    """

    # Required
    # Required (one of prompt or messages)
    prompt: Optional[str] = None
    system_prompt: Optional[str] = None
    model: Optional[str] = None

    # Conversation history for multi-turn chat
    messages: Optional[List[dict]] = None

    @model_validator(mode="after")
    def check_prompt_or_messages(self):
        if not self.prompt and not self.messages:
            raise ValueError("Either prompt or messages must be provided")
        return self

    # Basic parameters (supported)
    max_tokens: int = 8192
    temperature: float = 0.7
    top_p: float = 0.9
    top_k: int = -1

    # Repetition controls (not yet supported)
    repetition_penalty: float = 1.0
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0

    # Output controls (not yet supported)
    stop: List[str] = []

    # Web Search
    web_search_enabled: bool = False
    web_search_depth: str = "normal"  # normal, deep, deeper
