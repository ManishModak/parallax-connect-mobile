import unittest
import sys
import os
import time

# Add repo root to path
sys.path.append(os.getcwd())

from server.services.web_search import _process_scraped_content

class TestCleaningLogic(unittest.TestCase):
    def test_scoped_cleaning_successful(self):
        print("\nTesting Scoped Cleaning...")
        html = """
        <html>
        <body>
            <div class="sidebar">
                <div class="ad">Ad Sidebar</div>
            </div>
            <article>
                <h1>Title</h1>
                <p>Paragraph 1 with enough content to be valid.</p>
                <div class="ad">Ad Inside Content</div>
                <p>Paragraph 2.</p>
                """ + "<p> filler content to reach length requirement </p>" * 20 + """
            </article>
            <footer>Footer</footer>
        </body>
        </html>
        """

        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Title", result)
        self.assertIn("Paragraph 1", result)
        self.assertNotIn("Ad Inside Content", result) # Should be cleaned from inside article
        self.assertNotIn("Ad Sidebar", result) # Should be ignored as it is outside
        self.assertNotIn("Footer", result) # Should be ignored

    def test_fallback_cleaning(self):
        print("Testing Fallback Cleaning...")
        html = """
        <html>
        <body>
            <div class="ad">Ad Top</div>
            <div>
                <p>Content without container.</p>
                """ + "<p> filler content to reach length requirement </p>" * 20 + """
            </div>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://test.com", 1000, time.time())

        self.assertIn("Content without container", result)
        self.assertNotIn("Ad Top", result) # Should be cleaned in fallback

if __name__ == '__main__':
    unittest.main()
