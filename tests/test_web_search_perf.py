
import unittest
from server.services.web_search import _process_scraped_content

class TestWebSearchPerf(unittest.TestCase):
    def test_truncation_logic(self):
        # Create a text with 20 words
        text = "word " * 20
        max_words = 10

        # We need to mock logging or just ensure it doesn't crash
        # Since _process_scraped_content parses HTML, we need valid HTML
        html = f"<html><body><p>{text}</p></body></html>"

        final_text = _process_scraped_content(html, "http://test.com", max_words, 0.0)

        # We expect around 10 words.
        # The logic adds "..." if it can't find sentence boundary.
        self.assertTrue("word" in final_text)

        self.assertLess(len(final_text.split()), 20)

    def test_truncation_with_sentence_boundary(self):
        # Text with sentence boundary
        s1 = "This is sentence one. "
        s2 = "This is sentence two. "
        text = (s1 + s2) * 10

        html = f"<html><body><p>{text}</p></body></html>"

        # s1 has 4 words. s2 has 4 words.
        # If max_words = 5. It gets "This is sentence one. This"
        # Then finds boundary at "one."

        max_words = 5
        final_text = _process_scraped_content(html, "http://test.com", max_words, 0.0)

        # Should be "This is sentence one."
        self.assertIn("This is sentence one.", final_text)
        self.assertNotIn("This is sentence two.", final_text)

    def test_maxsplit_behavior(self):
        # Verify correctness of logic with maxsplit
        text = "a " * 100
        max_words = 50
        html = f"<html><body><p>{text}</p></body></html>"

        final_text = _process_scraped_content(html, "http://test.com", max_words, 0.0)

        # Logic:
        # words = text.split(maxsplit=max_words) -> list of length 51 (50 words + remainder)
        # words[:max_words] -> list of length 50
        # " ".join(...) -> string with 50 words
        # + "..." -> still roughly 50 words (since "..." is appended to last word or separated by space)
        # The function joins with " ", so "word..." counts as 1 word or "word ..." counts as 2.
        # But split() by default splits by whitespace. "word..." is one token.

        self.assertEqual(len(final_text.split()), 50)

if __name__ == "__main__":
    unittest.main()
