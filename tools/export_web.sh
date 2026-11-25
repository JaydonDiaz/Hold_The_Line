#!/bin/bash
# Exports the web build for GitHub Pages ("Web (Pages)" preset) into build/pages, then
# makes a new version take over at once on players' phones and browsers.
#   tools/export_web.sh
# The Godot binary can be set with GODOT=/path/to/Godot.
#
# Why the patch: the web build keeps itself for offline play (a service worker). Godot's
# own worker, once a newer build is out, downloads it but keeps serving the old one until
# every tab (or home-screen app) running the game is closed, which on a phone is rarely:
# players kept seeing the old version for days. Patched, the new worker takes over as
# soon as it's installed, and a page still running an older version reloads into the
# new one. (The page itself also asks a waiting worker to take over: export_presets.cfg,
# the Pages preset's head_include.) Copy build/pages/* to Hold_The_Line_Game/docs to publish.

set -e
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
rm -rf build/pages
mkdir -p build/pages
"$GODOT" --headless --path . --export-release "Web (Pages)" build/pages/index.html
python3 -I - build/pages/index.service.worker.js <<'EOF'
import sys
path = sys.argv[1]
s = open(path).read()
install = "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));"
activate_old = "\t\tfunction (keys) {\n\t\t\t// Remove old caches.\n\t\t\treturn Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));\n\t\t}\n\t).then(function () {"
activate_new = "\t\tfunction (keys) {\n\t\t\t// Remove old caches (and remember whether there were any: an update, not a first visit).\n\t\t\tconst old = keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME);\n\t\t\tself.wasUpdate = old.length > 0;\n\t\t\treturn Promise.all(old.map((key) => caches.delete(key)));\n\t\t}\n\t).then(function () {"
preload = "\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n\t}));"
preload_new = ("\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();\n"
	"\t}).then(function () {\n"
	"\t\t// Hold the Line: take over now, and reload pages still running an older version.\n"
	"\t\tif (!self.wasUpdate) return Promise.resolve();\n"
	"\t\treturn self.clients.claim().then(() => self.clients.matchAll({ type: 'window' })).then((all) => all.forEach((c) => c.navigate(c.url)));\n"
	"\t}));")
for old, new in [(install, install[:-2] + ".then(() => self.skipWaiting()));"), (activate_old, activate_new), (preload, preload_new)]:
	if s.count(old) != 1:
		sys.exit("export_web.sh: Godot's service worker changed; the update patch no longer fits (" + old.strip()[:50] + "...)")
	s = s.replace(old, new)
open(path, "w").write(s)
print("patched " + path)
EOF
