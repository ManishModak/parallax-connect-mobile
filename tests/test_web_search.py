
import unittest
import time
from server.services.web_search import _process_scraped_content

class TestWebSearchPerformance(unittest.TestCase):
    def setUp(self):
        self.html = self._generate_large_html()

    def _generate_large_html(self):
        html = ["<html><head>"]
        # Add noise in head
        for i in range(100):
            html.append(f"<script>console.log('script {i}');</script>")
            html.append(f"<style>.style-{i} {{ color: red; }}</style>")
        html.append("</head><body>")

        # Header noise
        html.append("<header>" + "<div>Menu Item</div>" * 100 + "</header>")

        # Sidebar (outside main)
        html.append('<div class="sidebar">')
        for i in range(1000):
            html.append(f'<div class="widget item-{i}">Sidebar Widget {i}</div>')
        html.append('</div>')

        # Main Content
        html.append('<main id="content">')
        html.append('<h1>Main Article</h1>')
        for i in range(500):
            html.append(f'<p class="text-paragraph">This is paragraph {i} of the main content.</p>')
            # Some noise inside main that SHOULD be removed
            if i % 10 == 0:
                html.append(f'<div class="ad-banner">Ad {i}</div>')
        html.append('</main>')

        # Footer noise
        html.append("<footer>" + "<div>Footer Link</div>" * 100 + "</footer>")

        html.append("</body></html>")
        return "".join(html)

    def test_performance_and_correctness(self):
        start_time = time.time()
        # Mock scrape_start as current time
        result = _process_scraped_content(self.html, "http://test.com", 2000, start_time)
        duration = time.time() - start_time

        print(f"\nProcessing time: {duration:.4f}s")

        # Verification
        self.assertIn("Main Article", result)
        self.assertIn("This is paragraph 0", result)
        self.assertNotIn("Sidebar Widget", result)  # Should be ignored (outside main)
        self.assertNotIn("Ad 0", result)            # Should be removed (inside main)
        self.assertNotIn("script 0", result)        # Global tag removal

        # Ensure performance is reasonable (local environment dependent, but < 2s for this size is good)
        # The previous benchmark showed ~1.6s for optimized vs 2.5s for unoptimized.
        self.assertLess(duration, 3.0)

if __name__ == "__main__":
    unittest.main()
