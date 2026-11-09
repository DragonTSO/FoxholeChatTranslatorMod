# Upstream Audit

Upstream: https://github.com/syncsyncsynchalt/FoxholeChatTranslatorMod

Verified upstream main and local baseline:
`68e3d769ff91fd998a3015330f9ff21568d5377b`.

## Release Status

- Latest official release is `v0.2.2`.
- Locally named `v0.2.3`, `v0.2.4`, and `v0.2.5` packages reused the
  old DLLs. They are not rebuilt releases and do not contain Vietnamese support.
- Do not distribute those packages as fixes for crashes or Vietnamese support.
- ZIP extraction and PowerShell syntax checks do not verify game compatibility.

## Documentation Differences

- Upstream README mentions `install.ps1`, but upstream main contains
  `install.bat`. Its release workflow packages the batch installer.
- Current `src/overlay.cpp` draws translation-language buttons, TTS buttons,
  and a history toggle. It does not draw `assets/radio.png`.
- Absence of a radio picture is not evidence that the mod failed to load.
- The release workflow omits `slang_dict.txt` even though translation code
  reads that dictionary.

## Verification Required

1. Build both DLLs from the modified source using MSVC and the Windows SDK.
2. Test Vietnamese configuration, prompts, glyph coverage, and disabled TTS.
3. Test installation in a disposable directory, including upgrades and failures.
4. Package only the freshly built DLLs, with source revision and SHA-256 hashes.
5. Collect loader/game logs from the actual Foxhole installation before
   claiming that a crash or missing overlay has been fixed.

Missing debug logs alone do not prove anti-cheat blocking: initialization,
permissions, installation path, and DLL dependencies must also be checked.
