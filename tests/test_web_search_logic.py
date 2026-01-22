
import unittest
import time
from bs4 import BeautifulSoup
# Mocking dependencies if necessary
from server.services.web_search import _process_scraped_content

class TestWebSearchLogic(unittest.TestCase):
    def test_process_scraped_content_basic(self):
        html = """
        <html>
        <head><title>Test</title></head>
        <body>
            <div class="sidebar">Ads here</div>
            <article>
                <h1>Main Content</h1>
                <p>This is the real content that we want to extract.</p>
                <div class="ad">Ad inside article</div>
                <p>More content.</p>
            </article>
            <footer>Footer here</footer>
        </body>
        </html>
        """
        long_content = "This is the real content that we want to extract. " * 10
        html = html.replace("This is the real content that we want to extract.", long_content)

        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Main Content", result)
        self.assertIn("real content", result)
        self.assertNotIn("Ads here", result)
        self.assertNotIn("Footer here", result)
        self.assertNotIn("Ad inside article", result)

    def test_process_scraped_content_fallback(self):
        # No article tag, just body
        html = """
        <html>
        <body>
            <div class="sidebar">Sidebar Content</div>
            <p>Content paragraph 1.</p>
            <p>Content paragraph 2.</p>
            <div class="ad">Ad</div>
        </body>
        </html>
        """
        long_content = "Content paragraph. " * 20
        html = html.replace("Content paragraph 1.", long_content)

        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Content paragraph", result)
        self.assertNotIn("Ad", result)
        self.assertNotIn("Sidebar Content", result)

    def test_noise_removal_scoped(self):
        html = """
        <html>
        <body>
            <div class="sidebar">
                <article>
                    <p>Sidebar article (short).</p>
                </article>
            </div>
            <main>
                <article>
                    <h1>Real Article</h1>
                    <p>Real content.</p>
                </article>
            </main>
        </body>
        </html>
        """
        long_content = "Real content. " * 30
        html = html.replace("Real content.", long_content)

        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Real Article", result)
        self.assertNotIn("Sidebar article", result)

    def test_candidate_is_noise(self):
        # Test case where the candidate itself matches noise criteria
        html = """
        <html>
        <body>
            <article class="sidebar">
                <h1>Sidebar Article</h1>
                <p>This should be ignored.</p>
            </article>
            <article>
                <h1>Real Article</h1>
                <p>This is the real content.</p>
            </article>
        </body>
        </html>
        """
        long_content = "This is the real content. " * 30
        html = html.replace("This is the real content.", long_content)

        # Make sidebar content also long so it passes length check if not filtered by _is_noise
        long_sidebar = "This should be ignored. " * 30
        html = html.replace("This should be ignored.", long_sidebar)

        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Real Article", result)
        self.assertNotIn("Sidebar Article", result)

if __name__ == "__main__":
    unittest.main()
