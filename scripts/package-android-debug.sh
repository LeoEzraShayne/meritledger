#!/usr/bin/env bash
set -euo pipefail

site_dir="$(cd "$(dirname "$0")/.." && pwd)"
android_dir="${ANDROID_PROJECT_DIR:-$(dirname "$site_dir")/merit-ledger-android}"
build_date="$(TZ=Asia/Tokyo date +%F)"
apk_name="merit-ledger-${build_date}.apk"

# Use Android Studio's bundled JDK when JAVA_HOME is not set on macOS.
if [[ -z "${JAVA_HOME:-}" && -d '/Applications/Android Studio.app/Contents/jbr/Contents/Home' ]]; then
    export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
fi
(cd "$android_dir" && ./gradlew :app:assembleDebug --console=plain "$@")
mkdir -p "$site_dir/downloads"
cp "$android_dir/app/build/outputs/apk/debug/app-debug.apk" "$site_dir/downloads/$apk_name"

python3 - "$site_dir" "$apk_name" <<'PY'
from pathlib import Path
import re
import sys
root, apk_name = Path(sys.argv[1]), sys.argv[2]
for relative in ('download.html', 'zh/download.html', 'ja/download.html'):
    page = root / relative
    content = page.read_text()
    content, count = re.subn(r'merit-ledger-\d{4}-\d{2}-\d{2}\.apk', apk_name, content)
    if count != 2:
        raise SystemExit(f'Expected one APK link with a download filename in {page}, found {count} references')
    page.write_text(content)
PY
# Pages has a 25 MiB file limit; APKs are hosted as GitHub Release assets.
printf '/downloads/%s https://github.com/LeoEzraShayne/meritledger/releases/download/android-debug-%s/%s 302\n' \
    "$apk_name" "$build_date" "$apk_name" > "$site_dir/_redirects"
printf 'Ready: %s\n' "$site_dir/downloads/$apk_name"
