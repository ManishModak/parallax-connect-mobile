
import unittest
import time
from server.services.web_search import _process_scraped_content

class TestWebSearchCleaning(unittest.TestCase):
    def test_sidebar_vs_main_content(self):
        """
        Ensures that scoped cleaning correctly prioritizes main content over sidebar content,
        even if sidebar content appears first and is large.
        """
        sidebar_text = "Sidebar Ad " + ("buy " * 60) # > 240 chars
        main_text = "Real Article " + ("content " * 60)

        html = f"""
        <html>
        <body>
            <div class="sidebar">
                <article>
                    <h1>Sidebar Header</h1>
                    <p>{sidebar_text}</p>
                </article>
            </div>
            <main>
                <article>
                    <h1>Real Article Header</h1>
                    <p>{main_text}</p>
                </article>
            </main>
        </body>
        </html>
        """

        start = time.time()
        result = _process_scraped_content(html, "http://test.com", 1000, start)

        self.assertNotIn("Sidebar Header", result, "Sidebar content should not be selected")
        self.assertIn("Real Article Header", result, "Main content should be selected")

    def test_performance_sanity(self):
        """
        Sanity check that processing a large DOM doesn't timeout or take excessively long.
        """
        parts = []
        parts.append('<div class="sidebar">')
        for i in range(5000):
            parts.append(f'<div class="ad">Noise {i}</div>')
        parts.append('</div>')

        parts.append('<main><article>')
        for i in range(100):
            parts.append(f'<p>Content {i}</p>')
        parts.append('</article></main>')

        html = "<html><body>" + "".join(parts) + "</body></html>"

        start = time.time()
        result = _process_scraped_content(html, "http://perf.com", 2000, start)
        duration = time.time() - start

        self.assertIn("Content 0", result)
        # Should be well under 1s for this size (benchmark showed < 0.1s for cleaning + parsing)
        # Allow some buffer for CI environments
        self.assertLess(duration, 2.0, f"Processing took too long: {duration:.4f}s")

if __name__ == "__main__":
    unittest.main()
