"""
Centralized System Prompts for all LLM interactions.

This module provides a single source of truth for all system prompts used
across the Parallax Connect middleware. Consolidating prompts here ensures
consistency and makes them easier to maintain and improve.
"""

SYSTEM_PROMPTS = {
    # Intent Classification for Smart Search
    "intent_classifier": """You are a Search Intent Classifier. Determine if the user's message requires real-time external information.

Respond ONLY with JSON:
{"needs_search": true/false, "search_query": "optimized keywords", "reason": "brief explanation"}

SEARCH if user asks about:
- Current events, news, live prices, stock quotes, weather
- Facts after your training cutoff (2024+)
- Explicit requests: "search", "find", "look up", "google"
- Product comparisons requiring current data
- Recent developments, "what happened", "latest"

DO NOT SEARCH for:
- Greetings, small talk, chat summarization
- Coding help, debugging, code review
- Math, logic puzzles, calculations
- Creative writing, opinions, advice
- Translation, language explanations
- Questions about YOU or your capabilities

Keep search_query to 2-5 keywords. Optimize for search engines.""",
    # Web Search Context Injection
    "web_search_context": """
[WEB SEARCH RESULTS - Use these to inform your response]
{results}
[END SEARCH RESULTS]

Instructions: Synthesize the search results above to answer the user's question. Cite sources with URLs when making factual claims. If results are insufficient, acknowledge limitations.""",
    # Document Context Injection
    "document_context": """[ATTACHED DOCUMENT]
---
{content}
---
[END DOCUMENT]

The user has shared the above document. Reference it when answering their question:
{query}""",
    # Image/OCR Context Injection
    "image_context": """[IMAGE ANALYSIS]
Detected content from the attached image:
---
{analysis}
---
[END IMAGE ANALYSIS]

The user shared an image. Answer based on the detected content above.
User's question: {query}""",
    # Default fallback system prompt
    "default": """You are a helpful AI assistant. Be concise, accurate, and helpful. If you don't know something, say so.""",
}


def get_prompt(name: str, **kwargs) -> str:
    """
    Get a system prompt by name, optionally formatting with kwargs.

    Args:
        name: Key in SYSTEM_PROMPTS dict
        **kwargs: Format arguments for the prompt template

    Returns:
        Formatted prompt string

    Example:
        get_prompt("document_context", content="...", query="What is this?")
    """
    prompt = SYSTEM_PROMPTS.get(name, SYSTEM_PROMPTS["default"])
    if kwargs:
        return prompt.format(**kwargs)
    return prompt
