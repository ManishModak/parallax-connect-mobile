
import unittest
import time
from server.services.web_search import _process_scraped_content

class TestWebSearchCleaning(unittest.TestCase):
    def test_scoped_cleaning_article(self):
        html = """
        <html>
        <head><title>Test</title></head>
        <body>
            <div class="sidebar">Sidebar Content</div>
            <nav>Menu</nav>
            <article>
                <h1>Main Title</h1>
                <p>This is the main content.</p>
                <div class="ad">Ad inside article</div>
            </article>
            <footer>Footer</footer>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Main Title", result)
        self.assertIn("This is the main content.", result)
        self.assertNotIn("Sidebar Content", result)
        self.assertNotIn("Menu", result)
        self.assertNotIn("Ad inside article", result)
        self.assertNotIn("Footer", result)

    def test_scoped_cleaning_fallback(self):
        html = """
        <html>
        <body>
            <div class="sidebar">Sidebar Content</div>
            <div class="main-content">
                <p>Content without specific tag.</p>
                <div class="ad">Ad inside content</div>
            </div>
            <footer>Footer</footer>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Content without specific tag.", result)
        self.assertNotIn("Sidebar Content", result)
        self.assertNotIn("Ad inside content", result)
        self.assertNotIn("Footer", result)

    def test_metadata_preservation(self):
        html = """
        <html>
        <head>
            <meta name="author" content="John Doe">
            <meta property="article:published_time" content="2023-01-01T12:00:00Z">
        </head>
        <body>
            <article>Content</article>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())
        self.assertIn("Author: John Doe", result)
        self.assertIn("Published: 2023-01-01", result)

    def test_noisy_article_skipped(self):
        # Scenario: <article> contains only noise. It should be skipped, and fallback (or next selector) should be used.
        # Here we rely on fallback to body if article is skipped.
        # Or if there is another valid container (e.g. main).
        html = """
        <html>
        <body>
            <article>
                <div class="ad">
                    This is a very long ad that takes up a lot of space.
                    It has enough characters to pass the dirty length check.
                    But it is all noise.
                    Repeating to make it long enough.
                    Repeating to make it long enough.
                    Repeating to make it long enough.
                    Repeating to make it long enough.
                    Repeating to make it long enough.
                    Repeating to make it long enough.
                </div>
            </article>
            <main>
                <h1>Real Content</h1>
                <p>This is the actual content we want.</p>
                <p>It also needs to be long enough to be selected.</p>
                <p>Repeating to make it long enough.</p>
                <p>Repeating to make it long enough.</p>
                <p>Repeating to make it long enough.</p>
                <p>Repeating to make it long enough.</p>
                <p>Repeating to make it long enough.</p>
            </main>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        # Article has only ad, so it should be cleaned to empty string.
        # Loop should continue.
        # Main has real content.

        self.assertIn("Real Content", result)
        self.assertIn("This is the actual content we want", result)
        self.assertNotIn("This is a very long ad", result)

if __name__ == '__main__':
    unittest.main()
