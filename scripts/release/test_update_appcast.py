import tempfile
import unittest
from pathlib import Path
from xml.dom import minidom

from update_appcast import element_text, update_appcast


BASE_APPCAST = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Image Studio Releases</title>
    <!-- Latest release will be added here by CI/CD -->
    <item><sparkle:shortVersionString>3.0.0</sparkle:shortVersionString></item>
    <item><sparkle:shortVersionString>2.0.0</sparkle:shortVersionString></item>
    <item><sparkle:shortVersionString>1.0.0</sparkle:shortVersionString></item>
  </channel>
</rss>
"""


class UpdateAppcastTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.appcast_path = Path(self.temporary_directory.name) / "appcast.xml"
        self.appcast_path.write_text(BASE_APPCAST)

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def update(self, version: str, notes: str = "<p>Notes</p>") -> None:
        update_appcast(
            self.appcast_path,
            version=version,
            sparkle_version=version.replace(".", ""),
            tag=f"v{version}",
            dmg_url=f"https://example.com/ImageStudio-{version}.dmg",
            file_size="123",
            signature="signature",
            release_date="Sat, 05 Sep 2026 00:00:00 +0000",
            repository="jellydn/imagi",
            release_notes_html=notes,
            max_items=3,
        )

    def versions(self) -> list[str]:
        document = minidom.parse(str(self.appcast_path))
        return [
            element_text(element)
            for element in document.getElementsByTagName("sparkle:shortVersionString")
        ]

    def test_replaces_only_matching_release(self) -> None:
        self.update("2.0.0")

        self.assertEqual(self.versions(), ["2.0.0", "3.0.0", "1.0.0"])

    def test_adds_latest_release_and_trims_oldest(self) -> None:
        self.update("4.0.0")

        self.assertEqual(self.versions(), ["4.0.0", "3.0.0", "2.0.0"])

    def test_preserves_cdata_terminator_in_release_notes(self) -> None:
        self.update("4.0.0", "<pre>value ]]> value</pre>")

        document = minidom.parse(str(self.appcast_path))
        description = document.getElementsByTagName("description")[0]
        self.assertIn("value ]]> value", element_text(description))


if __name__ == "__main__":
    unittest.main()
