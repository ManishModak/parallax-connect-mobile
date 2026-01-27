
import unittest
import time
from bs4 import BeautifulSoup
from server.services.web_search import _clean_element_noise, _process_scraped_content

class TestWebSearchCleaning(unittest.TestCase):
    def test_clean_element_noise_tags(self):
        html = "<div><p>Content</p><script>var x=1;</script><style>.css{}</style></div>"
        soup = BeautifulSoup(html, "lxml")
        div = soup.div
        _clean_element_noise(div)
        self.assertIsNone(div.script)
        self.assertIsNone(div.style)
        self.assertIsNotNone(div.p)
        self.assertEqual(div.get_text(strip=True), "Content")

    def test_clean_element_noise_classes(self):
        html = "<div><p>Content</p><div class='ad'>Ad</div><div class='sidebar-widget'>Sidebar</div></div>"
        soup = BeautifulSoup(html, "lxml")
        div = soup.div
        _clean_element_noise(div)
        self.assertIsNone(div.find(class_='ad'))
        self.assertIsNone(div.find(class_='sidebar-widget'))
        self.assertIsNotNone(div.p)
        self.assertEqual(div.get_text(strip=True), "Content")

    def test_clean_element_nested(self):
        html = """
        <main>
            <article>
                <h1>Title</h1>
                <div class="content">
                    <p>Real text.</p>
                    <div class="ad-container">
                        <span>Buy this!</span>
                    </div>
                </div>
            </article>
            <div class="sidebar">
                <p>Sidebar link</p>
            </div>
        </main>
        """
        soup = BeautifulSoup(html, "lxml")
        main = soup.main
        _clean_element_noise(main)

        self.assertIsNone(main.find(class_="sidebar"))
        self.assertIsNone(main.find(class_="ad-container"))
        self.assertIsNotNone(main.find("article"))
        self.assertIn("Real text.", main.get_text())
        self.assertNotIn("Buy this!", main.get_text())
        self.assertNotIn("Sidebar link", main.get_text())

    def test_process_scraped_content_scoped(self):
        # This tests the full flow including selection
        html = """
        <html>
        <body>
            <div class="ad-banner">Top Ad</div>
            <main>
                <article>
                    <p>This is the main article content. It is long enough to be selected.</p>
                    <p>Filler text to make it longer than 200 chars. """ + ("bla " * 50) + """</p>
                    <div class="ad-box">Article Ad</div>
                </article>
            </main>
            <footer class="footer">Footer</footer>
        </body>
        </html>
        """
        # We assume _process_scraped_content selects 'article' or 'main'
        result = _process_scraped_content(html, "http://example.com", 1000, time.time())

        self.assertIn("main article content", result)
        self.assertNotIn("Top Ad", result) # Should be outside selection or cleaned if fallback
        self.assertNotIn("Article Ad", result) # Should be cleaned from inside
        self.assertNotIn("Footer", result) # Should be outside selection

    def test_process_scraped_content_fallback(self):
        # Case where no selector matches, falls back to body
        html = """
        <html>
        <body>
            <div class="weird-content">
                <p>This is the only content. It is long enough. """ + ("bla " * 50) + """</p>
                <div class="ad">Internal Ad</div>
            </div>
            <div class="sidebar">Sidebar</div>
        </body>
        </html>
        """
        result = _process_scraped_content(html, "http://example.com", 1000, time.time())

        self.assertIn("only content", result)
        self.assertNotIn("Internal Ad", result) # cleaned from body
        self.assertNotIn("Sidebar", result) # cleaned from body
