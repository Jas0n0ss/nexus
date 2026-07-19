#!/usr/bin/env bash
# Apply installable release config on top of a flutter-created android/ tree.
# Usage (from app/): bash packaging/android/apply_release_config.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID="$ROOT/android"
PKG="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$ANDROID/app/src/main" ]; then
  echo "❌ android/ scaffold missing — run flutter create first" >&2
  exit 1
fi

mkdir -p "$ANDROID/keystore"
cp -f "$PKG/keystore/nexus-release.p12" "$ANDROID/keystore/nexus-release.p12"
cp -f "$PKG/key.properties" "$ANDROID/key.properties"

# ── AndroidManifest.xml: permissions, label, VpnService ───────────────────────
MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
python3 - <<'PY' "$MANIFEST"
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# Ensure INTERNET + VPN-related permissions exist before <application>
perms = [
    'android.permission.INTERNET',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_SPECIAL_USE',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.ACCESS_NETWORK_STATE',
]
for p in perms:
    if p not in text:
        text = text.replace(
            "<application",
            f'    <uses-permission android:name="{p}"/>\n    <application',
            1,
        )

# Human-readable app label
text = re.sub(r'android:label="[^"]*"', 'android:label="Nexus"', text, count=1)

service = '''
        <service
            android:name="com.nexusvpn.NexusTunnelService"
            android:exported="false"
            android:permission="android.permission.BIND_VPN_SERVICE"
            android:foregroundServiceType="specialUse">
            <intent-filter>
                <action android:name="android.net.VpnService" />
            </intent-filter>
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="vpn" />
        </service>
'''
if "NexusTunnelService" not in text:
    text = text.replace("</application>", service + "    </application>", 1)

path.write_text(text, encoding="utf-8")
print(f"✅ patched {path}")
PY

# ── app/build.gradle(.kts): release signing (not debug) ───────────────────────
GRADLE_GROOVY="$ANDROID/app/build.gradle"
GRADLE_KTS="$ANDROID/app/build.gradle.kts"

if [ -f "$GRADLE_GROOVY" ]; then
  python3 - <<'PY' "$GRADLE_GROOVY"
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

props_block = '''
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
'''
if "keystoreProperties" not in text:
    # Insert before android {
    text = re.sub(r'\nandroid\s*\{', props_block + "\nandroid {", text, count=1)

signing_block = '''
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
            storeType 'pkcs12'
        }
    }
'''
# Flutter templates already mention signingConfigs.debug — still inject our release config
if "signingConfigs {" not in text and "signingConfigs{" not in text:
    text = re.sub(
        r'(android\s*\{)',
        r'\1' + signing_block,
        text,
        count=1,
    )
elif "storeType 'pkcs12'" not in text and 'storeType = "pkcs12"' not in text:
    # signingConfigs exists but has no release PKCS12 entry — insert before buildTypes
    text = re.sub(
        r'(\n\s*buildTypes\s*\{)',
        signing_block + r'\1',
        text,
        count=1,
    )

# Force release builds to use the release keystore (Flutter defaults to debug)
text = re.sub(
    r'signingConfig\s*=\s*signingConfigs\.debug',
    "signingConfig = signingConfigs.release",
    text,
)
text = re.sub(
    r'signingConfig\s+signingConfigs\.debug',
    "signingConfig signingConfigs.release",
    text,
)

path.write_text(text, encoding="utf-8")
print(f"✅ patched {path}")
PY
elif [ -f "$GRADLE_KTS" ]; then
  python3 - <<'PY' "$GRADLE_KTS"
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if "keystoreProperties" not in text:
    header = '''
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
'''
    text = header + "\n" + text

if 'create("release")' not in text:
    signing = '''
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
            storeType = "pkcs12"
        }
    }
'''
    text = re.sub(r'(android\s*\{)', r'\1' + signing, text, count=1)

text = text.replace(
    "signingConfig = signingConfigs.getByName(\"debug\")",
    "signingConfig = signingConfigs.getByName(\"release\")",
)
text = text.replace(
    "signingConfigs.getByName(\"debug\")",
    "signingConfigs.getByName(\"release\")",
)
path.write_text(text, encoding="utf-8")
print(f"✅ patched {path}")
PY
else
  echo "❌ No app/build.gradle(.kts) found" >&2
  exit 1
fi

# Restore VpnService / MainActivity overlays after flutter create
mkdir -p "$ANDROID/app/src/main/kotlin/com/nexusvpn"

if [ -f "$PKG/VpnService.kt" ]; then
  cp -f "$PKG/VpnService.kt" "$ANDROID/app/src/main/kotlin/com/nexusvpn/VpnService.kt"
  echo "✅ restored VpnService.kt from packaging"
elif [ -f "$ANDROID/app/src/main/kotlin/com/nexusvpn/VpnService.kt" ]; then
  echo "✅ VpnService.kt present"
fi

if [ -f "$PKG/MainActivity.kt" ]; then
  # Prefer packaging MainActivity (MethodChannel bridge); remove default Flutter one if package differs
  find "$ANDROID/app/src/main/kotlin" -name 'MainActivity.kt' -not -path '*/com/nexusvpn/*' -delete 2>/dev/null || true
  cp -f "$PKG/MainActivity.kt" "$ANDROID/app/src/main/kotlin/com/nexusvpn/MainActivity.kt"
  echo "✅ restored MainActivity.kt from packaging"
fi

# Point AndroidManifest at com.nexusvpn.MainActivity when present
MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ] && grep -q 'android:name=".MainActivity"' "$MANIFEST"; then
  sed -i 's/android:name="\.MainActivity"/android:name="com.nexusvpn.MainActivity"/' "$MANIFEST"
  echo "✅ AndroidManifest MainActivity → com.nexusvpn.MainActivity"
fi

echo "✅ Android release config applied (release-signed, installable APK)"
