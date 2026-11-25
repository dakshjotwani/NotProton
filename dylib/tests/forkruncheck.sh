#!/bin/sh
# steamplay-mac fork: the custom-runner block in the run script, against a fake runner.
# Loads only the block between the fork's markers, so it checks the functions themselves;
# that the script calls them is checked by the hook count at the end.
# shellcheck disable=SC2034,SC2154
set -e
SRC="${1:-$(dirname "$0")/../feats/compat_run.sh}"
[ -f "$SRC" ] || { echo "forkruncheck: $SRC not present, skipped"; exit 0; }

block=$(sed -n '/^# >>> steamplay-mac fork/,/^# <<< steamplay-mac fork/p' "$SRC")
[ -n "$block" ] || { echo "FAIL: no steamplay-mac fork block in $SRC"; exit 1; }
eval "$block"

fails=0
ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n         want [%s]\n         got  [%s]\n' "$1" "$2" "$3"; fails=$((fails + 1)); }
is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log="$tmp/run.log"
np_support="$tmp/support"
np_defaults_file="$tmp/none.env"
np_from_defaults() { return 1; }
show_alert() { alert="$1"; }
alert_safe() { printf '%s' "$1"; }

echo "== kind and root =="
np_build=crossover-26.3 np_display=""
np_custom_detect
is "a CrossOver build stays crossover" crossover "$np_runner_kind"
is "and keeps upstream's display" "" "$np_display"
CX_ROOT=/cx np_variant=v1
np_custom_root
is "CrossOver keeps its root" /cx "$CX_ROOT"
is "and its variant" v1 "$np_variant"
np_custom_missing_alert && bad "CrossOver's alert is left to upstream" 1 0 || ok "CrossOver's alert is left to upstream"
np_custom_verify_runner && bad "CrossOver's runner check is left to upstream" 1 0 || ok "CrossOver's runner check is left to upstream"

np_build=wine-steamplay-mac np_display=""
np_custom_detect
is "wine-<name> is a custom runner" custom "$np_runner_kind"
is "named after the runner" "Wine (steamplay-mac)" "$np_display"
np_custom_root
is "rooted in runners/<build>" "$np_support/runners/wine-steamplay-mac" "$CX_ROOT"
is "with no variant" "" "$np_variant"

R="$CX_ROOT"
mkdir -p "$R/lib/wine/x86_64-windows" "$R/lib/wine/i386-windows" "$R/lib/wine/x86_64-unix" \
  "$R/share/steamplay" "$R/lib/renderers/dxmt" "$R/lib/renderers/d3dmetal" "$R/lib/external"
printf '{"kind": "wine", "msync": true, "wine": "wine-11.0"}\n' > "$R/runner.json"

echo "== environment =="
CX_APPLEGPTK_LIBD3DSHARED_PATH=/cx/libd3dshared.dylib
np_custom_runner_env
is "the runner's lib/ goes on the fallback path" "$R/lib:/usr/local/lib:/usr/lib" "$DYLD_FALLBACK_LIBRARY_PATH"
is "and into env -i" "DYLD_FALLBACK_LIBRARY_PATH=$R/lib:/usr/local/lib:/usr/lib" "$np_runner_env"
is "CrossOver's libd3dshared is dropped" "" "${CX_APPLEGPTK_LIBD3DSHARED_PATH-}"
unset -v DYLD_FALLBACK_LIBRARY_PATH

mkdir -p "$np_support"
printf '%s\n' 'MTL_HUD_ENABLED=1' 'DXMT_LOG=1' 'PATH=/evil' 'bad-key=1' 'NOTPROTON_X=2' > "$np_support/global.env"
verb=waitforexitandrun np_defaulted="" NOTPROTON_X=own
np_custom_global_env
is "global.env exports allowed keys" 1 "${MTL_HUD_ENABLED-}"
is "and leaves other keys out" "" "$(env | grep '^PATH=/evil' || true)"
is "a key already set wins" own "$NOTPROTON_X"
is "and records what it set" "MTL_HUD_ENABLED=1 DXMT_LOG=1" "$np_defaulted"
unset -v MTL_HUD_ENABLED DXMT_LOG

WINEMSYNC=""
np_custom_msync_default
is "runner.json msync:true turns msync on" 1 "$WINEMSYNC"
WINEMSYNC=0
np_custom_msync_default
is "a game's own WINEMSYNC wins" 0 "$WINEMSYNC"

app_id=292030 NOTPROTON_HIDE_WINE=""
is "The Witcher 3 hides Wine's exports" '"HideWineExports"="Y"' "$(np_custom_settings_lines | sed -n 2p | tr -d '\r')"
app_id=1 NOTPROTON_HIDE_WINE=1
is "NOTPROTON_HIDE_WINE=1 hides them for any game" '"HideWineExports"="Y"' "$(np_custom_settings_lines | sed -n 2p | tr -d '\r')"
app_id=1 NOTPROTON_HIDE_WINE=""
is "other games show them" '"HideWineExports"=-' "$(np_custom_settings_lines | sed -n 2p | tr -d '\r')"

echo "== bridge =="
bridge_src="$tmp/bridge" wine_unix="$R/lib/wine/x86_64-unix"
is "no runner copy falls back to the app's" "$bridge_src/steam.exe" "$(bridge_file_src steam.exe)"
: > "$R/share/steamplay/steam.exe"
: > "$R/lib/wine/x86_64-unix/lsteamclient.so"
is "the runner's steam.exe is staged" "$R/share/steamplay/steam.exe" "$(bridge_file_src steam.exe)"
is "lsteamclient.so comes from the unix arch" "$R/lib/wine/x86_64-unix/lsteamclient.so" "$(np_custom_bridge_src lsteamclient.so)"
is "steamclient64.dll stays the app's" "$bridge_src/steamclient64.dll" "$(bridge_file_src steamclient64.dll)"
: > "$log"
np_custom_verify_runner
is "a runner missing lsteamclient.dll is logged" 2 "$(grep -c 'lsteamclient.dll' "$log")"

echo "== graphics =="
WINEPREFIX="$tmp/prefix" STEAM_COMPAT_INSTALL_PATH="$tmp/nogame"
CX_GRAPHICS_BACKEND=dxmt NOTPROTON_D3DMETAL4=0
np_custom_graphics /game.exe
is "CX_GRAPHICS_BACKEND=dxmt" dxmt "$CX_ACTIVE_GRAPHICS_BACKEND"
is "puts dxmt ahead of Wine's DLLs" "$R/lib/renderers/dxmt" "$WINEDLLPATH_PREPEND"
CX_GRAPHICS_BACKEND=dxvk
np_custom_graphics /game.exe
is "a renderer the runner lacks falls back" wined3d "$CX_ACTIVE_GRAPHICS_BACKEND"
CX_GRAPHICS_BACKEND=d3dmetal
np_custom_graphics /game.exe
is "d3dmetal" d3dmetal "$CX_ACTIVE_GRAPHICS_BACKEND"
is "uses the runner's libd3dshared" "$R/lib/external/libd3dshared.dylib" "$CX_APPLEGPTK_LIBD3DSHARED_PATH"
CX_GRAPHICS_BACKEND=""
np_custom_graphics /game.exe
is "auto with nothing to scan is wined3d" wined3d "$CX_ACTIVE_GRAPHICS_BACKEND"
CX_GRAPHICS_BACKEND=d3dmetal NOTPROTON_D3DMETAL4=1
np_custom_graphics /game.exe
is "D3DMetal 4 without its files stays on D3DMetal 3" "$R/lib/renderers/d3dmetal" "$WINEDLLPATH_PREPEND"
np_runner_kind=crossover WINEDLLPATH_PREPEND=untouched
np_custom_graphics /game.exe
is "a CrossOver build is left alone" untouched "$WINEDLLPATH_PREPEND"

echo "== the script calls into the block =="
for fn in np_custom_detect np_custom_root np_custom_runner_env np_custom_global_env \
          np_custom_settings_lines np_custom_missing_alert np_custom_msync_default \
          np_custom_verify_runner np_custom_bridge_src np_custom_graphics np_custom_hud \
          np_aion2_compat; do
  n=$(sed '/^# >>> steamplay-mac fork/,/^# <<< steamplay-mac fork/d' "$SRC" | grep -c "$fn" || true)
  if [ "$n" -ge 1 ]; then ok "$fn is called"; else bad "$fn is called" ">=1" "$n"; fi
done

if [ "$fails" -ne 0 ]; then echo "==> forkruncheck: $fails failed"; exit 1; fi
echo "==> forkruncheck: the custom-runner block behaves, and the script calls all of it"
