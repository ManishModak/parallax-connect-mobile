
import unittest
from bs4 import BeautifulSoup
import re
from server.services.web_search import NOISE_REGEX, _process_scraped_content

class TestWebSearchOptimization(unittest.TestCase):
    def test_noise_removal_correctness(self):
        # Create HTML with various noise classes and content
        html = """
        <html>
            <body>
                <div class="sidebar-widget">I am a sidebar</div>
                <div class="ad-banner">I am an ad</div>
                <div class="content">I am content</div>
                <div class="article-body">
                    <p>Real content here.</p>
                    <div class="share-buttons">Share this</div>
                </div>
                <div class="random-class">Keep me</div>
                <div class="text-ad">I am a text ad</div>
                <div class="shadow">I am a shadow (should keep as 'shadow' doesn't match 'ad' whole word)</div>
                <div class="menu">Menu items</div>
            </body>
        </html>
        """

        # We can't call _process_scraped_content directly easily because it does more than just cleaning
        # (it fetches, truncates, etc). But we can copy the logic or test the result of _process_scraped_content.
        # Since _process_scraped_content takes url, max_words, etc.

        cleaned_text = _process_scraped_content(html, "http://test.com", 1000, 0)

        # Verify what was removed
        self.assertNotIn("I am a sidebar", cleaned_text)
        self.assertNotIn("I am an ad", cleaned_text)
        self.assertNotIn("Share this", cleaned_text)
        self.assertNotIn("I am a text ad", cleaned_text)
        self.assertNotIn("Menu items", cleaned_text)

        # Verify what was kept
        self.assertIn("I am content", cleaned_text)
        self.assertIn("Real content here", cleaned_text)
        self.assertIn("Keep me", cleaned_text)
        self.assertIn("I am a shadow", cleaned_text)

    def test_regex_matching(self):
        # Verify regex behavior on specific cases
        self.assertTrue(NOISE_REGEX.search("sidebar-widget"))
        self.assertTrue(NOISE_REGEX.search("ad"))
        self.assertTrue(NOISE_REGEX.search("text-ad"))
        self.assertFalse(NOISE_REGEX.search("shadow")) # 'ad' is inside but not word boundary
        self.assertFalse(NOISE_REGEX.search("add"))    # 'ad' is inside
        self.assertTrue(NOISE_REGEX.search("advertisement"))

if __name__ == '__main__':
    unittest.main()
