# Starsong

## The Xcode project is generated, not authored

`Starsong.xcodeproj/` is produced by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from
`project.yml`, and it is git-ignored. CI regenerates it from scratch on every run. Treat it as
build output.

**Never write project configuration through Xcode.** Anything written into `project.pbxproj` —
by the `UpdateTargetBuildSetting`, `AddInfoPlist`, `AddEntitlement`, `UpdateFileCompilerFlags`,
or `XcodeNewTarget` tools, or by hand in Xcode's Build Settings editor — is destroyed by the
next `xcodegen generate`, and never appears in `git status` because the whole `.xcodeproj` is
ignored. The change looks like it worked, then quietly disappears.

Instead:

| To change | Edit |
|---|---|
| A build setting for one target | that target's `settings.base` in `project.yml` |
| A build setting for everything | the top-level `settings.base` in `project.yml`, or `Config/Starsong.xcconfig` |
| Info.plist keys | `Sources/Resources/Info.plist` directly (the app target sets `GENERATE_INFOPLIST_FILE: NO`) |
| Sources, targets, schemes | `project.yml` |
| Secrets (API keys) | `Config/Secrets.xcconfig`, git-ignored, `#include?`d from `Starsong.xcconfig` |

Then run `xcodegen generate`.

Entitlements deserve a specific warning: adding one through Xcode creates the `.entitlements`
file (which survives regeneration) *and* a `CODE_SIGN_ENTITLEMENTS` build setting (which does
not). The result is an entitlements file that looks correct and does nothing.

## Regenerating resets your Xcode session

`xcodegen generate` recreates `Starsong.xcodeproj/`, and that wipes `xcuserdata/` — where the
active scheme and the active run destination live. Both fall back to defaults. The scheme
itself is generated from the `scheme:` block in `project.yml`, so scheme edits made in Xcode's
UI are discarded as well.

If you change the run destination or the active scheme in order to do something, **put it back
when you are done.** The working default is the physical device, `Lati`.

## Running the tests

`DEVELOPMENT_TEAM` is set project-wide in `project.yml`, so the test bundles inherit it and
`buildForTesting` can sign for a physical device. Running the suite on a simulator (e.g.
`iPhone 17 Pro`) is still the quicker path; either way, **switch the destination back to `Lati`
afterwards**, because regenerating will not do it for you.

## Checking a project.yml change without regenerating

Verifying an edit to `project.yml` normally means running `xcodegen generate`, which resets the
open Xcode session. Pushing instead is usually the better trade: CI regenerates from scratch on
a clean runner and builds and tests both targets, so the change is checked without touching
anyone's machine.

## Code style

Match the surrounding file. The existing tests are XCTest; don't mix Swift Testing into a file
that isn't already using it.
