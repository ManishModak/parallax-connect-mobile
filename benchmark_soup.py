
import time
import re
from bs4 import BeautifulSoup
import random

# Setup
NOISE_CLASS_PATTERNS = [
    "ad", "ads", "advert", "banner", "sidebar", "comment", "share", "social", "related", "menu"
]

# Old Regex (aggressive)
OLD_NOISE_REGEX = re.compile("|".join(map(re.escape, NOISE_CLASS_PATTERNS)))

# New Regex (safe)
NEW_NOISE_REGEX = re.compile(r"\b(" + "|".join(map(re.escape, NOISE_CLASS_PATTERNS)) + r")\b", re.IGNORECASE)

# Generate HTML
html_parts = []
classes_pool = ["content", "text", "body", "main", "article", "wrapper", "container"]
noise_pool = NOISE_CLASS_PATTERNS + ["header-ad", "ad-box", "social-links", "share-btn"]
safe_pool = ["shadow", "thread", "loading", "read-more", "gradient"]

for i in range(10000):
    if i % 10 == 0:
        cls = random.choice(noise_pool) # Expected to remove (1000 items)
    elif i % 7 == 0:
        cls = random.choice(safe_pool) # Safe but tricky words (approx 1400 items)
    else:
        cls = random.choice(classes_pool) # Safe

    cls_list = [cls, random.choice(classes_pool)]
    cls_str = " ".join(cls_list)
    html_parts.append(f'<div class="{cls_str}">Item {i}</div>')

html_content = "<html><body>" + "".join(html_parts) + "</body></html>"

def run_manual_loop_original(html, regex):
    soup = BeautifulSoup(html, "lxml")
    start = time.time()
    elements_to_remove = []
    for el in soup.find_all(class_=True):
        class_val = el.get("class")
        if not class_val:
            continue
        if isinstance(class_val, list):
            classes = " ".join(class_val).lower()
        else:
            classes = str(class_val).lower()

        if regex.search(classes):
            elements_to_remove.append(el)

    count = len(elements_to_remove)
    for el in elements_to_remove:
        el.decompose()

    end = time.time()
    return end - start, count

def run_manual_loop_optimized(html, regex):
    soup = BeautifulSoup(html, "lxml")
    start = time.time()
    elements_to_remove = []
    for el in soup.find_all(class_=True):
        class_val = el.get("class")
        if not class_val:
            continue
        # Optimization: Don't lower(), use regex IGNORECASE
        if isinstance(class_val, list):
            classes = " ".join(class_val)
        else:
            classes = str(class_val)

        if regex.search(classes):
            elements_to_remove.append(el)

    count = len(elements_to_remove)
    for el in elements_to_remove:
        el.decompose()

    end = time.time()
    return end - start, count

print("Benchmarking...")

# Run Old Original
t, c = run_manual_loop_original(html_content, OLD_NOISE_REGEX)
print(f"Old Regex + Original Loop: {t:.4f}s, Removed: {c}")

# Run New Original
t, c = run_manual_loop_original(html_content, NEW_NOISE_REGEX)
print(f"New Regex + Original Loop: {t:.4f}s, Removed: {c}")

# Run New Optimized (No .lower())
t, c = run_manual_loop_optimized(html_content, NEW_NOISE_REGEX)
print(f"New Regex + Optimized Loop: {t:.4f}s, Removed: {c}")
