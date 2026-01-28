
import unittest
import time
from server.services.web_search import _process_scraped_content

class TestWebSearchCleaning(unittest.TestCase):
    def test_basic_content_extraction(self):
        html = """
        <html>
            <body>
                <header>Header</header>
                <article>
                    <h1>Title</h1>
                    <p>Content paragraph 1.</p>
                    <p>Content paragraph 2.</p>
                </article>
                <footer>Footer</footer>
            </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Title", result)
        self.assertIn("Content paragraph 1", result)
        self.assertNotIn("Header", result)
        self.assertNotIn("Footer", result)

    def test_noise_removal_inside_content(self):
        html = """
        <html>
            <body>
                <article>
                    <p>Real content.</p>
                    <div class="ad">Buy this!</div>
                    <script>alert('noise')</script>
                </article>
            </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Real content", result)
        self.assertNotIn("Buy this", result)
        self.assertNotIn("alert", result)

    def test_fallback_to_body(self):
        html = """
        <html>
            <body>
                <div>
                    <p>Just some text without an article tag.</p>
                </div>
            </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Just some text", result)

    def test_noise_outside_content_ignored(self):
        # This test checks that we get the content even if there is noise outside.
        # It also verifies that noise outside doesn't end up in the result (which is true for both approaches).
        html = """
        <html>
            <body>
                <div class="sidebar">
                    <p>Sidebar content</p>
                </div>
                <main>
                    <p>Main content.</p>
                </main>
            </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Main content", result)
        self.assertNotIn("Sidebar content", result)

    def test_truncation(self):
        html = """
        <html>
            <body>
                <article>
                    <p>Word1 Word2 Word3 Word4 Word5.</p>
                </article>
            </body>
        </html>
        """
        # Limit to 3 words
        result = _process_scraped_content(html, "http://test.com", 3, time.time())
        # The function splits by words and truncates.
        # "Word1 Word2 Word3 Word4 Word5." -> words: ["Word1", "Word2", "Word3", "Word4", "Word5."]
        # max_words=3 -> "Word1 Word2 Word3"
        # Then it tries to find sentence end. "Word1 Word2 Word3". No sentence end.
        # It adds "..." -> "Word1 Word2 Word3..."

        self.assertIn("Word1", result)
        self.assertTrue(result.endswith("...") or len(result.split()) <= 4)

if __name__ == '__main__':
    unittest.main()
