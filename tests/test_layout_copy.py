"""Layout.lua (magnetic frames) must stay the same file as Mage Tools Forever's and
Warlock Tools Forever's, but for the AddOn namespace.

Compares against sibling checkouts next to this repository when they exist;
skipped otherwise (as in CI).
"""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SIBLINGS = ("MageToolsForever", "WarlockToolsForever")
# Each copy names its own namespace (and the sibling it was copied from).
NAMESPACE_RE = re.compile(rb"\b(?:DBR|MTF|WTF)\b")


def normalized(path):
    return NAMESPACE_RE.sub(b"NS", path.read_bytes().replace(b"\r\n", b"\n"))


class LayoutCopyTests(unittest.TestCase):
    def test_namespace_is_ours(self):
        text = (ROOT / "Layout.lua").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("local _, DBR = ...\n"))
        self.assertNotRegex(text, r"\b(?:MTF|WTF)\.")

    def test_layout_matches_sibling_addons(self):
        found = [ROOT.parent / name for name in SIBLINGS if (ROOT.parent / name / "Layout.lua").is_file()]
        if not found:
            self.skipTest("no sibling AddOn checkout to compare with")
        ours = normalized(ROOT / "Layout.lua")
        for sibling in found:
            with self.subTest(addon=sibling.name):
                self.assertEqual(ours, normalized(sibling / "Layout.lua"),
                                 f"Layout.lua differs from {sibling.name}'s copy beyond the namespace")


if __name__ == "__main__":
    unittest.main()
