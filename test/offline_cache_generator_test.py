from pathlib import Path
import tempfile
import unittest

from tool.generate_offline_cache import generate


class OfflineCacheGeneratorTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.build = Path(directory.name)
        self.required = [
            "index.html", "flutter_bootstrap.js", "main.dart.js",
            "canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm",
            "sqflite_sw.js", "sqlite3.wasm", "assets/FontManifest.json",
            "assets/fonts/fallback/Roboto-Regular.ttf",
        ]
        for name in self.required:
            self.write(name, name)

    def write(self, name, content):
        path = self.build / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def test_includes_all_runtime_assets_and_replaces_flutter_stub(self):
        self.write("flutter_service_worker.js", "self.registration.unregister()")
        self.write("main.dart.wasm", "wasm")
        self.write("main.dart.mjs", "module")
        self.write("canvaskit/skwasm.wasm", "android renderer")
        self.write("assets/extra font.ttf", "font")
        count, _ = generate(self.build)
        worker = (self.build / "flutter_service_worker.js").read_text()
        self.assertEqual(count, len(self.required) + 4)
        self.assertNotIn("unregister()", worker)
        self.assertNotIn("__PRECACHE_RESOURCES__", worker)
        for name in self.required + ["main.dart.wasm", "main.dart.mjs"]:
            self.assertIn(f'"{name}"', worker)
        self.assertIn('"assets/extra%20font.ttf"', worker)

    def test_revision_is_stable_and_changes_when_asset_bytes_change(self):
        first = generate(self.build)
        self.write("CNAME", "example.org")
        self.write(".nojekyll", "")
        self.write("main.dart.js.map", "debug only")
        self.assertEqual(generate(self.build), first)
        self.write("sqlite3.wasm", "new database runtime")
        self.assertNotEqual(generate(self.build)[1], first[1])

    def test_missing_runtime_rejects_build_without_overwriting_previous_worker(self):
        generate(self.build)
        worker = (self.build / "flutter_service_worker.js").read_text()
        (self.build / "sqlite3.wasm").unlink()
        with self.assertRaisesRegex(ValueError, "sqlite3.wasm"):
            generate(self.build)
        self.assertEqual((self.build / "flutter_service_worker.js").read_text(), worker)

    def test_requires_local_font_to_avoid_hidden_cdn_dependency(self):
        (self.build / "assets/fonts/fallback/Roboto-Regular.ttf").unlink()
        with self.assertRaisesRegex(ValueError, "Roboto-Regular.ttf"):
            generate(self.build)


if __name__ == "__main__":
    unittest.main()
