"""Replace Flutter's retiring service worker with a complete app-shell cache."""

import hashlib
import json
from pathlib import Path
import sys
from urllib.parse import quote


def generate(build_dir: Path) -> tuple[int, str]:
    template = Path(__file__).with_name("offline_service_worker.js").read_text()
    required = [
        "index.html", "flutter_bootstrap.js", "main.dart.js",
        "canvaskit/canvaskit.js", "canvaskit/canvaskit.wasm",
        "sqflite_sw.js", "sqlite3.wasm", "assets/FontManifest.json",
        "assets/fonts/fallback/Roboto-Regular.ttf",
    ]
    for name in required:
        if not (build_dir / name).is_file():
            raise ValueError(f"Missing offline resource: {name}. Build Flutter first.")

    excluded = {"flutter_service_worker.js", "CNAME", ".nojekyll", ".last_build_id"}
    paths = sorted(
        path for path in build_dir.rglob("*")
        if path.is_file() and path.name not in excluded
        and not path.name.endswith((".map", ".symbols"))
    )
    digest = hashlib.sha256(template.encode())
    resources = []
    for path in paths:
        name = path.relative_to(build_dir).as_posix()
        resources.append(quote(name, safe="/"))
        digest.update(name.encode() + b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    revision = digest.hexdigest()[:20]
    worker = template.replace("__BUILD_REVISION__", revision).replace(
        "__PRECACHE_RESOURCES__", json.dumps(resources, ensure_ascii=True),
    )
    (build_dir / "flutter_service_worker.js").write_text(worker)
    return len(resources), revision


if __name__ == "__main__":
    directory = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("build/web")
    count, revision = generate(directory)
    print(f"Offline cache: {count} resources, revision {revision}")
