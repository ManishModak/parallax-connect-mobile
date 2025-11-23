"""
Sampling parameters of each request
"""

from typing import List, Optional, Union


class SamplingParams:
    """Sampling parameter class for a single request"""

    def __init__(
        self,
        max_new_tokens: int = 128,
        min_new_tokens: int = 0,
        temperature: float = 1.0,
        top_p: float = 1.0,
        min_p: float = 0.0,
        top_k: int = -1,
        stop_token_ids: Optional[List[int]] = None,
        ignore_eos: bool = False,
        stop_strs: Optional[Union[str, List[str]]] = None,
        repetition_penalty: float = 1.0,
        presence_penalty: float = 0.0,
        frequency_penalty: float = 0.0,
        json_schema: Optional[str] = None,
    ) -> None:
        self.max_new_tokens = max_new_tokens
        self.min_new_tokens = min_new_tokens
        self.temperature = temperature
        self.top_p = top_p
        self.min_p = min_p
        self.top_k = top_k
        if stop_token_ids:
            self.stop_token_ids = set(stop_token_ids)
        else:
            self.stop_token_ids = None
        self.ignore_eos = ignore_eos
        self.stop_strs = stop_strs
        self.repetition_penalty = repetition_penalty
        self.presence_penalty = presence_penalty
        self.frequency_penalty = frequency_penalty
        self.json_schema = json_schema

        # Some special cases
        if self.temperature == 0.0:
            # greedy sampling
            self.temperature = 1.0
            self.top_k = 1

    def verify(self):
        """Basic verifications for the sampling parameters"""
        if self.temperature < 0.0:
            raise ValueError(f"temperature must be non-negetive, got {self.temperature}.")
        if not 0.0 < self.top_p <= 1.0:
            raise ValueError(f"top_p must be in (0, 1], got {self.top_p}.")
        if not 0.0 < self.min_p <= 1.0:
            raise ValueError(f"min_p must be in (0, 1], got {self.min_p}.")
        if not -2.0 <= self.frequency_penalty <= 2.0:
            raise ValueError(f"frequency_penalty must be in [-2, 2], got {self.frequency_penalty}.")
        if not -2.0 <= self.presence_penalty <= 2.0:
            raise ValueError(f"presence_penalty must be in [-2, 2], got {self.presence_penalty}.")
        if not 0.0 <= self.repetition_penalty <= 2.0:
            raise ValueError(
                f"repetition_penalty must be in [0, 2], got {self.repetition_penalty}."
            )
