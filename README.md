# NotProton

NotProton enables the Steam Play experience from Linux Steam in the macOS Steam client.

This is done by forcibly enabling the Steam Play functionality in macOS Steam (which is
present and inert) as well as by porting some components of Valve's Proton to macOS.

This tool is intended to be used with the stable Steam Client (version 1794424036) as well as the beta Steam Client (version 1792626604) paired with **CrossOver 26.3 or CrossOver [Preview](https://www.codeweavers.com/preview)
20260821 / 20261006 / 20261015**, with more supported versions to come.

**Tuxera NTFS is not supported. Tuxera has a bad bug that causes corruption. I've reported the bug to them. If you need NTFS, Paragon NTFS may work better, but I have not tested it. I will be implementing a work around for this (horrible) bug soon.**

Supporting specifically CrossOver is a design goal of this project. Better support for modifying CrossOver (using custom builds of DXMT/patched D3DMetal/MacGameVideoFix) will come in a future update, but support for alternatives to CrossOver itself is not planned.

Both the FEX and the Rosetta versions are supported. I recommend using the FEX version of the 
Preview 20261006, as it includes both the FEX version as well as the Rosetta one. 

I further recommend going into Steam Settings - Compatibility and selecting the Rosetta version as your default compatibility tool. You can select FEX on a per game basis by right clicking a game in Steam, going into Properties - Compatibility and selecting FEX there.

If a game has a native macOS version as well as a Windows one, Steam will download the macOS version. To override this behavior, right click on the game, select Properties, select Compatibility. Enable 'Force the use of a specific Steam Play compatibility tool'. Select whichever version of CrossOver you want to do use. That will make Steam download the Windows version. Unchecking the 'Force the use...' box or selecting 'No Compatibility Tool' in the drop down list will revert to the macOS version of the game, with the specifics there varying based on your Steam version.

**Valve Anti-Cheat is not supported.** Proton itself does not support VAC in Valve titles; Valve ships native Linux ports instead. VAC titles will launch in Insecure Mode and will not allow matchmaking. 

**This project now has a brew cask.** For brew users, you can install via ``brew install --cask notprotonnot/notproton/notproton``

Please read NOTICE for license information.

Please open issue reports with any issues. PRs are welcome and encouraged.

There are many people who worked on similar ideas, similar projects. I did not base NotProton on their work, but I still want to 
give thanks to the people who came before me:

[Nat Brown](https://github.com/natbro) made [Kaon](https://github.com/natbro/kaon), which is similar in goals to NotProton.

mont127's [Neutron](https://github.com/mont127/Neutron) is also a similar idea, but implemented differently. 

[Gio](https://github.com/giodotblue) was working enabling Steam Play inside of Steam on macOS prior to the release of NotProton itself. 
I would have done things differently had I been aware of that. 

Thanks to everyone who has positively contributed to macOS gaming. 

Developer Notes:

As far as the source structure goes, the macOS app itself is located in the ```app``` folder. The core logic is in ```dylib```.
```lsteamclient``` is a macOS port of Valve's lsteamclient. ```steam-shim```is a port of Valve's
steam-helper from Proton 9.0. ntdll-patch patches the copy of CrossOver that the app
makes/places in the ```~/Library/Application Support/notproton/runners/``` folder so that
lsteamclient is loaded.

## Custom Wine runners (this fork)

Besides the CrossOver builds the app sets up, `notproton.dylib` registers any Wine you put in
`~/Library/Application Support/notproton/runners/wine-<name>/` as its own Steam compatibility
tool, `notproton-wine-<name>`. The app does not manage these folders: it neither lists nor
prunes them. Restart Steam after adding or removing one.

A runner folder is a Wine install tree plus a `runner.json`:

```
runners/wine-<name>/
  runner.json                      {"kind": "wine", "display_name": "...", "msync": true, "wine": "wine-11.0"}
  bin/wineserver
  lib/wine/x86_64-unix/wine        (and ntdll.so etc.; x86_64 Wine, run under Rosetta)
  lib/wine/x86_64-windows/  lib/wine/i386-windows/
  share/wine/wine.inf
  lib/*.dylib                      optional: on DYLD_FALLBACK_LIBRARY_PATH for Wine's unix side
  lib/renderers/{d3dmetal,d3dmetal4,dxmt,dxvk}/   optional DLL overlays, see below
  lib/external/libd3dshared.dylib  optional: D3DMetal 3 (lib/external/d3dmetal4/ for 4)
  lib/wine/*/lsteamclient.{dll,so}, share/steamplay/steam.exe   optional Steam bridge
```

- `display_name` is the name Steam shows (default `Wine (<name>)`). `"msync": true` turns
  msync on by default, for a wineserver that has it.
- Steam features need Wine's ntdll to route `steamclient(64).dll` to the builtin
  `lsteamclient` (Valve's Proton patches). NotProton's binary ntdll patch is CrossOver only,
  so a custom runner has to carry that in its source. When the runner ships its own
  `lsteamclient` and `steam.exe`, those are staged into the prefix instead of the app's.
- Graphics: `CX_GRAPHICS_BACKEND` (the panel's setting) picks `d3dmetal`, `d3dmetal4`, `dxmt`,
  `dxvk` or `wined3d`; unset, the game's PE imports decide (Direct3D 12 → D3DMetal,
  10/11 → DXMT, else wined3d, using the `pe-d3d` helper in the support folder). The chosen
  renderer's folder goes in front through `WINEDLLPATH_PREPEND`, which the Wine needs to
  support (Highball's `ntdll-winedllpath-prepend`). A renderer the runner lacks falls back to
  wined3d.
- Runner variants are CrossOver only and are ignored for a custom runner.

[steamplay-mac](https://github.com/Drustburn/steamplay-mac) builds such a runner from the
CrossOver 26.3 sources.
