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

## Regenerating is cheap; run it

`xcodegen generate` rewrites `project.pbxproj` inside the existing `Starsong.xcodeproj/` rather
than replacing the directory, so `xcuserdata/` survives and the active scheme and run
destination are left alone. Measured: same `UserInterfaceState.xcuserstate` byte-for-byte, new
pbxproj inode, destination still `Lati`. There is no reason to avoid regenerating, and it is the
only way to see a `project.yml` edit take effect — CI can confirm the spec is well-formed, but
it builds simulator-only, so it cannot check anything about device signing.

The *scheme* is a different matter: it is generated from the `scheme:` block in `project.yml`,
so scheme edits made in Xcode's UI are discarded on the next generate.

If you change the run destination or the active scheme in order to do something, **put it back
when you are done** — nothing else will. The working default is the physical device, `Lati`.

## Running the tests

`DEVELOPMENT_TEAM` is set project-wide in `project.yml`, so both test bundles inherit it and
`buildForTesting` signs for a physical device. Verified against `Lati` after a regenerate.
Running the suite on a simulator (e.g. `iPhone 17 Pro`) is still the quicker path; either way,
switch the destination back to `Lati` afterwards.

## Code style

Match the surrounding file. The existing tests are XCTest; don't mix Swift Testing into a file
that isn't already using it.
