# Bed Follows the Tune Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the keepsake's bar-counted chord bed with one derived from the melody: home is where the tune rests, chords change on melody onsets at phrase length, and each chord is chosen by how well it fits the notes under it.

**Architecture:** All rules live in `Sources/Model/Harmony.swift` as pure static functions over `[Star]` and `Music.Tuning`, feeding the existing `bed(under:in:)` / `sound(under:in:offset:)` pair that `KeepsakeModel` already calls. `Music` gains one helper, `semitone(forY:in:)`, so harmony can read a star's pitch class. The old `chords(bars:in:)`, `away(in:)` and `tonic(in:)` are deleted in Task 5, not kept alongside.

**Tech Stack:** Swift, XCTest, XcodeGen. Tests run on an iOS simulator via `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-09-01-bed-follows-the-tune-design.md`

## Global Constraints

- The Xcode project is generated. Never edit `Starsong.xcodeproj`; edit `project.yml` if anything structural changes (nothing here does). Run `xcodegen generate` before the first build.
- CI fails on any compiler **warning** in `Sources/` or `Tests/` (see `.github/workflows/tests.yml` line 73). Keep the build warning-free.
- Tests are XCTest. Match the surrounding file's style: doc comments that say *why*, `for tuning in Music.tunings` loops with `tuning.name` in the assertion message.
- Every chord tone must be a member of the melody's tuning (the safety rule at the top of `Harmony.swift`). No thirds. No notes from outside the tuning.
- `barPulses = 8`, `barLength = Music.pulse * 8 = 2.4 s`, `noteLength = 1.3`, `roll = 0.07`, `volume = 0.05`, `voice = .pluck` are unchanged.
- Work on a branch: `git checkout -b bed-follows-the-tune` from `main` before Task 1. Commit at the end of each task with the trailer lines shown in Task 1.

**Running one test class** (the command every "run" step below refers to as RUN, substituting the class):

```bash
xcodegen generate > /dev/null && xcodebuild test -project Starsong.xcodeproj -scheme Starsong \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:StarsongTests/HarmonyTests 2>&1 \
  | grep -E "Test Case .* (passed|failed)|error:|(Sources|Tests)/.*warning:|\*\* TEST"
```

Several simulators are named "iPhone 17 Pro"; xcodebuild warns and picks one. That warning is fine. A `Test Case ... failed` line or an `error:` line is not.

**Melody pitch classes used by the tests.** A star at height `y` sings scale degree `d = Int((1 - y) * 14 + 0.5)`, so `y = 1 - d / 14` puts a star exactly on degree `d`. Degree `d` is semitone `tuning.degrees[d % 5] + 12 * (d / 5)` above the root, and its pitch class is that mod 12. The fifth dyads per tuning, as `(root, fifth)` pitch classes, are:

| Tuning | degrees | fifth dyads |
|---|---|---|
| major | 0 2 4 7 9 | (0,7) (2,9) (7,2) (9,4) |
| minor | 0 3 5 7 10 | (0,7) (3,10) (5,0) (10,5) |
| hirajoshi | 0 2 3 7 8 | (0,7) (7,2) (8,3) |
| in | 0 1 5 7 8 | (0,7) (1,8) (5,0) |
| balinese | 0 1 3 7 10 | (0,7) (3,10) |

---

### Task 1: `Music.semitone(forY:in:)`

**Files:**
- Modify: `Sources/Model/Music.swift` (the `pitch(forY:in:)` and `noteName(forY:in:)` functions, around lines 48–68)
- Test: `Tests/StarsongTests/MusicTests.swift`

**Interfaces:**
- Produces: `static func Music.semitone(forY y: CGFloat, in tuning: Tuning = Music.default) -> Int` — semitones above the tuning's root (220 Hz), `0...34`. Pitch class is `% 12`.

- [ ] **Step 1: Branch**

```bash
git checkout -b bed-follows-the-tune
```

- [ ] **Step 2: Write the failing tests**

Add to `final class MusicTests` in `Tests/StarsongTests/MusicTests.swift`:

```swift
    /// The pitch a star sings, as a number the harmony can reason about. The
    /// bottom of the sky is the root; the top is two octaves and four degrees
    /// up, which is 24 semitones plus the tuning's highest degree.
    func testSemitoneCountsUpFromTheRoot() {
        for tuning in Music.tunings {
            XCTAssertEqual(Music.semitone(forY: 1, in: tuning), 0, tuning.name)
            XCTAssertEqual(Music.semitone(forY: 0, in: tuning),
                           24 + tuning.degrees[4], tuning.name)
            // Degree 5 is the root an octave up, in every tuning.
            XCTAssertEqual(Music.semitone(forY: 1 - 5.0 / 14, in: tuning), 12, tuning.name)
        }
    }

    /// `pitch` and `noteName` already computed this on their own; they have to
    /// agree with the helper, or the bed will harmonise a note the star is not
    /// singing.
    func testSemitoneAgreesWithPitch() {
        for tuning in Music.tunings {
            for degree in 0...Music.range {
                let y = 1 - CGFloat(degree) / CGFloat(Music.range)
                let expected = Music.rootFrequency
                    * pow(2, Double(Music.semitone(forY: y, in: tuning)) / 12)
                XCTAssertEqual(Music.pitch(forY: y, in: tuning), expected,
                               accuracy: 1e-6, "\(tuning.name) degree \(degree)")
            }
        }
    }
```

- [ ] **Step 3: Run to verify they fail**

RUN with `-only-testing:StarsongTests/MusicTests`.
Expected: a compile `error:` — `type 'Music' has no member 'semitone'`.

- [ ] **Step 4: Implement, and make `pitch` and `noteName` use it**

In `Sources/Model/Music.swift`, replace the existing `pitch(forY:in:)` with:

```swift
    /// Semitones above the root — the pitch a star sings, as a number the
    /// harmony can reason about. The pitch class is this mod 12.
    static func semitone(forY y: CGFloat, in tuning: Tuning = Music.default) -> Int {
        let degree = degree(forY: y)
        let octave = degree / tuning.degrees.count
        return octave * 12 + tuning.degrees[degree % tuning.degrees.count]
    }

    static func pitch(forY y: CGFloat, in tuning: Tuning = Music.default) -> Double {
        rootFrequency * pow(2, Double(semitone(forY: y, in: tuning)) / 12)
    }
```

And replace the body of `noteName(forY:in:)` with:

```swift
    static func noteName(forY y: CGFloat, in tuning: Tuning = Music.default) -> String {
        let midi = 57 + semitone(forY: y, in: tuning)
        return "\(noteNames[midi % 12]) \(midi / 12 - 1)"
    }
```

- [ ] **Step 5: Run to verify they pass**

RUN with `-only-testing:StarsongTests/MusicTests`, then with `-only-testing:StarsongTests/RhythmTests` and `-only-testing:StarsongTests/StarNavigationTests` (the two that exercise `pitch` and `noteName` most).
Expected: every `Test Case` line says `passed`; no `error:` or `warning:` lines.

- [ ] **Step 6: Commit**

```bash
git add Sources/Model/Music.swift Tests/StarsongTests/MusicTests.swift
git commit -m "Expose a star's semitone so harmony can read its pitch class

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 2: Home is where the tune rests

**Files:**
- Modify: `Sources/Model/Harmony.swift` — add a `// MARK: - Home` section after `fifthDyads(in:)`; leave the old `tonic(in:)` and `away(in:)` in place until Task 5
- Test: `Tests/StarsongTests/HarmonyTests.swift`

**Interfaces:**
- Consumes: `Music.semitone(forY:in:)` from Task 1; existing `Harmony.Chord`, `Harmony.fifthDyads(in:)`, `Harmony.voiced(_:)`.
- Produces:
  - `static func tonic(of stars: [Star], in tuning: Music.Tuning) -> Int` — pitch class `0..<12` of the last star; `0` for an empty line.
  - `static func home(for stars: [Star], in tuning: Music.Tuning) -> Chord` — `Chord(root: t, tones: [t, t + 7])` when `(t + 7) % 12` is a tuning degree, else `Chord(root: t, tones: [t])`.
  - `static func candidates(for stars: [Star], in tuning: Music.Tuning) -> [Chord]` — home first, then every fifth dyad whose folded pitch-class set is new.

- [ ] **Step 1: Write the failing tests**

Add a helper and a new section to `HarmonyTests` (put the helper next to the existing `star` and `line` helpers at the top of the class):

```swift
    /// A star sitting exactly on scale degree `degree`, `0...14`.
    func star(atDegree degree: Int, x: CGFloat = 0.5) -> Star {
        star(x, 1 - CGFloat(degree) / CGFloat(Music.range))
    }

    /// A line that walks the given degrees left to right, evenly spaced.
    func line(degrees: [Int]) -> [Star] {
        degrees.enumerated().map { i, d in
            star(atDegree: d, x: 0.1 + CGFloat(i) * 0.8 / CGFloat(max(degrees.count - 1, 1)))
        }
    }
```

Then, in place of the old `testHomeIsTheTonicAndItsFifthInEveryTuning` (delete it), add:

```swift
    // MARK: - Home

    /// The tonic is wherever the tune rests, not degree 0 of the tuning. The
    /// keepsake's spiral closes on degree 4 in every key, and a bed that called
    /// degree 0 home was in a different key from the tune it sat under.
    func testTheTonicIsTheLastNotesPitchClass() {
        for tuning in Music.tunings {
            for degree in 0...Music.range {
                let stars = line(degrees: [0, 3, degree])
                let expected = Music.semitone(forY: stars.last!.y, in: tuning) % 12
                XCTAssertEqual(Harmony.tonic(of: stars, in: tuning), expected,
                               "\(tuning.name) degree \(degree)")
            }
        }
        XCTAssertEqual(Harmony.tonic(of: [], in: Music.default), 0)
    }

    /// Home is the tonic and its fifth when the tuning has that fifth, and the
    /// tonic alone when it does not — bare, but unambiguous. Never an octave:
    /// `voiced` folds every tone into one octave, so `[t, t + 12]` would come
    /// out as the same note rolled twice.
    func testHomeIsRootedOnTheTonic() {
        for tuning in Music.tunings {
            let members = Set(tuning.degrees)
            for degree in 0...Music.range {
                let stars = line(degrees: [2, degree])
                let home = Harmony.home(for: stars, in: tuning)
                let tonic = Harmony.tonic(of: stars, in: tuning)
                XCTAssertEqual(home.root, tonic, tuning.name)
                XCTAssertEqual(home.tones.first, tonic, tuning.name)
                if members.contains((tonic + 7) % 12) {
                    XCTAssertEqual(home.tones, [tonic, tonic + 7], "\(tuning.name) has the fifth")
                } else {
                    XCTAssertEqual(home.tones, [tonic], "\(tuning.name) lacks the fifth")
                }
                XCTAssertEqual(Set(Harmony.voiced(home)).count, home.tones.count,
                               "\(tuning.name): a tone is doubled")
            }
        }
    }

    /// The keepsake rests on degree 4. Three tunings have its fifth; In and
    /// Balinese do not, and take the bare tonic.
    func testWhichTuningsGiveTheKeepsakeAFifth() {
        let expected = ["major": 2, "minor": 2, "hirajoshi": 2, "in": 1, "balinese": 1]
        for tuning in Music.tunings {
            let home = Harmony.home(for: FiftySky.stars(), in: tuning)
            XCTAssertEqual(home.tones.count, expected[tuning.id], tuning.name)
        }
    }

    /// Home first, then every fifth dyad, with nothing listed twice: when home
    /// *is* one of the fifth dyads it must not appear again as a competitor.
    func testCandidatesAreHomeAndEveryFifthDyadOnce() {
        for tuning in Music.tunings {
            for degree in 0...Music.range {
                let stars = line(degrees: [1, degree])
                let candidates = Harmony.candidates(for: stars, in: tuning)
                let home = Harmony.home(for: stars, in: tuning)
                XCTAssertEqual(candidates.first, home, tuning.name)
                let sets = candidates.map { Set(Harmony.voiced($0)) }
                XCTAssertEqual(Set(sets).count, sets.count, "\(tuning.name): a chord is listed twice")
                for dyad in Harmony.fifthDyads(in: tuning) {
                    XCTAssertTrue(sets.contains(Set(Harmony.voiced(dyad))),
                                  "\(tuning.name): dyad on \(dyad.root) is missing")
                }
            }
        }
    }
```

- [ ] **Step 2: Run to verify they fail**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: compile `error:` lines — `tonic(of:in:)`, `home(for:in:)`, `candidates(for:in:)` have no such members.

- [ ] **Step 3: Implement**

In `Sources/Model/Harmony.swift`, directly after `fifthDyads(in:)`, add:

```swift
    // MARK: - Home

    /// The pitch class the tune rests on: its last note.
    ///
    /// Not degree 0 of the tuning. The keepsake's spiral opens near the top of
    /// the sky and closes at the bottom of its own rim, and both of those land
    /// on degree 4 in every key — so a bed that called degree 0 home was in a
    /// different key from the melody it sat under. Where a tune ends is what
    /// the ear takes for its key, and the bass has to agree.
    static func tonic(of stars: [Star], in tuning: Music.Tuning) -> Int {
        guard let last = stars.last else { return 0 }
        return Music.semitone(forY: last.y, in: tuning) % 12
    }

    /// The tonic and its fifth, when the tuning has that fifth; otherwise the
    /// tonic alone. Bare, but it cannot be mistaken for anything else, and it
    /// keeps the safety rule: no note from outside the tuning.
    ///
    /// Not an octave. `voiced` folds every tone into one octave, so `[t, t+12]`
    /// would come out as the same note rolled twice — a flam, not a chord.
    static func home(for stars: [Star], in tuning: Music.Tuning) -> Chord {
        let tonic = tonic(of: stars, in: tuning)
        guard Set(tuning.degrees).contains((tonic + 7) % 12) else {
            return Chord(root: tonic, tones: [tonic])
        }
        return Chord(root: tonic, tones: [tonic, tonic + 7])
    }

    /// Everything the bed may play under this line: home, then every fifth
    /// dyad in the tuning. Home comes first so that a tie on fit falls to it.
    /// Deduplicated by folded pitch-class set, because home is usually one of
    /// the dyads already and must not compete with itself.
    static func candidates(for stars: [Star], in tuning: Music.Tuning) -> [Chord] {
        let home = home(for: stars, in: tuning)
        var seen: Set<Set<Int>> = [Set(voiced(home))]
        var chords = [home]
        for dyad in fifthDyads(in: tuning) where seen.insert(Set(voiced(dyad))).inserted {
            chords.append(dyad)
        }
        return chords
    }
```

- [ ] **Step 4: Run to verify they pass**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: the four new tests pass; every pre-existing test still passes (the old API is still present).

- [ ] **Step 5: Commit**

```bash
git add Sources/Model/Harmony.swift Tests/StarsongTests/HarmonyTests.swift
git commit -m "Harmony: home is the note the tune rests on

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 3: Spans

**Files:**
- Modify: `Sources/Model/Harmony.swift` — add a `// MARK: - Spans` section after the Home section
- Test: `Tests/StarsongTests/HarmonyTests.swift`

**Interfaces:**
- Consumes: `Music.schedule(for:)`, `Music.gaps(between:)`, `Music.cycleLength(for:)`, `Music.longestGap`, `Harmony.barLength`.
- Produces: `static func spans(under stars: [Star]) -> [Range<Double>]` — consecutive, seconds from the downbeat, the first starting at `0`, the last ending at `Music.cycleLength(for: stars)`; empty for fewer than two stars. An onset opens a span only if at least `barLength / 2` of the cycle remains after it.

- [ ] **Step 1: Write the failing tests**

Add to `HarmonyTests`:

```swift
    // MARK: - Spans

    /// A chord may change only where a note starts. A grid of bars drifted a
    /// sixteenth off the melody after the first bar, because the line moves in
    /// half-pulses and bars in whole ones.
    func testEverySpanOpensOnAMelodyOnset() {
        for count in 2...16 {
            let stars = line(count)
            let onsets = Music.schedule(for: stars)
            for span in Harmony.spans(under: stars) {
                XCTAssertTrue(onsets.contains { abs($0 - span.lowerBound) < 1e-9 },
                              "\(count) notes: a span opens at \(span.lowerBound), between notes")
            }
        }
    }

    /// Spans tile the cycle: the first opens on the downbeat, each one starts
    /// where the last ended, and the last runs to the end of the cycle, so the
    /// arrival is still sounding through the rest at the loop seam.
    func testSpansTileTheCycle() {
        for count in 2...16 {
            let stars = line(count)
            let spans = Harmony.spans(under: stars)
            XCTAssertEqual(spans.first?.lowerBound, 0, "\(count) notes")
            XCTAssertEqual(spans.last?.upperBound ?? -1, Music.cycleLength(for: stars),
                           accuracy: 1e-9, "\(count) notes")
            for (a, b) in zip(spans, spans.dropFirst()) {
                XCTAssertEqual(a.upperBound, b.lowerBound, accuracy: 1e-9, "\(count) notes: a gap between spans")
                XCTAssertLessThan(a.lowerBound, a.upperBound, "\(count) notes: an empty span")
            }
        }
    }

    /// A span runs about a bar: never shorter than half of one, and — except
    /// the last, which is the cadence and may run long — never longer than a
    /// bar plus the two-pulse gap an onset can sit past the bar it was
    /// waiting for. The one exception is a line whose whole cycle is shorter
    /// than half a bar: two notes make a 0.9 s cycle and get one short span.
    func testSpansRunAboutABar() {
        for count in 2...16 {
            let stars = line(count)
            let spans = Harmony.spans(under: stars)
            let wholeCycleIsShort = spans.count == 1
                && Music.cycleLength(for: stars) < Harmony.barLength / 2
            for (i, span) in spans.enumerated() {
                let length = span.upperBound - span.lowerBound
                if !wholeCycleIsShort {
                    XCTAssertGreaterThanOrEqual(length + 1e-9, Harmony.barLength / 2,
                                                "\(count) notes: span \(i) is too short")
                }
                if i < spans.count - 1 {
                    XCTAssertLessThanOrEqual(length - 1e-9, Harmony.barLength + Music.longestGap,
                                             "\(count) notes: span \(i) is too long")
                }
            }
        }
    }

    /// A steady line has no breaths in it, so its spans are whole bars snapped
    /// to the pulse: eight notes at one pulse each is exactly a bar.
    func testASteadyLineGetsWholeBars() {
        let stars = line(degrees: Array(repeating: [3, 5], count: 12).flatMap { $0 })   // 24 notes, even spacing
        XCTAssertEqual(Music.gaps(between: stars).dropFirst().min(), Music.pulse, "not a steady line")
        let spans = Harmony.spans(under: stars)
        for span in spans.dropLast() {
            XCTAssertEqual(span.upperBound - span.lowerBound, Harmony.barLength, accuracy: 1e-9)
        }
    }

    /// A breath — a two-pulse gap — lets a chord change early, but only once
    /// the span has run half a bar; a breath after a quarter of a bar is just
    /// a long note.
    func testABreathOpensASpanAfterHalfABar() {
        // Reaches: three short, one long (a breath), then short. Positions
        // chosen so the gaps come out as pulse/2, pulse/2, pulse/2, 2*pulse.
        let stars = [star(0.10, 0.5), star(0.15, 0.5), star(0.20, 0.5), star(0.25, 0.5),
                     star(0.65, 0.5), star(0.70, 0.5), star(0.75, 0.5), star(0.80, 0.5),
                     star(0.85, 0.5), star(0.90, 0.5), star(0.95, 0.5)]
        let gaps = Music.gaps(between: stars)
        XCTAssertEqual(gaps[4], Music.longestGap, accuracy: 1e-9, "the fourth reach should be a breath")
        let onsets = Music.schedule(for: stars)
        let spans = Harmony.spans(under: stars)
        // The breath lands at onsets[4] = 0.15 * 3 + 0.6 = 1.05 s, which is
        // less than half a bar (1.2 s) into the first span, so it must NOT open
        // a span there.
        XCTAssertFalse(spans.contains { abs($0.lowerBound - onsets[4]) < 1e-9 },
                       "a breath before half a bar opened a span")

        // Nine tight notes then the breath: it lands at 8 * 0.15 + 0.6 =
        // 1.8 s, past half a bar and short of a whole one, so it must open a
        // span there and nowhere earlier. Six notes follow it so that more
        // than half a bar of cycle remains after the breath.
        let later = (0..<9).map { star(0.10 + CGFloat($0) * 0.03, 0.5) }
            + (0..<6).map { star(0.70 + CGFloat($0) * 0.03, 0.5) }
        let laterOnsets = Music.schedule(for: later)
        XCTAssertEqual(Music.gaps(between: later)[9], Music.longestGap, accuracy: 1e-9)
        XCTAssertEqual(Harmony.spans(under: later).map(\.lowerBound), [0, laterOnsets[9]])
    }

    /// A chord does not change on the very last note to ring for a single
    /// gap: an onset opens a span only if half a bar of the cycle remains
    /// after it. Nine steady notes at one pulse each reach a bar on the
    /// ninth, but only 0.6 s of cycle is left there, so it stays one span.
    func testNoSpanOpensWithLessThanHalfABarLeft() {
        let stars = line(degrees: Array(repeating: 0, count: 9))
        XCTAssertEqual(Music.gaps(between: stars)[8], Music.pulse, accuracy: 1e-9, "not a steady line")
        XCTAssertEqual(Music.schedule(for: stars)[8], Harmony.barLength, accuracy: 1e-9, "ninth note should land on the bar")
        XCTAssertEqual(Harmony.spans(under: stars).count, 1)
        // Two more notes and there is room: the span opens on the ninth.
        let longer = line(degrees: Array(repeating: 0, count: 13))
        XCTAssertEqual(Harmony.spans(under: longer).map(\.lowerBound), [0, Harmony.barLength])
    }
```

- [ ] **Step 2: Run to verify they fail**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: compile `error:` — no member `spans(under:)`.

- [ ] **Step 3: Implement**

Add to `Harmony.swift` after the Home section:

```swift
    // MARK: - Spans

    /// Where the chords change. Each span is a stretch of the cycle, in
    /// seconds from the downbeat, that one chord covers.
    ///
    /// A chord may change only on a melody onset — a grid of bars drifted a
    /// sixteenth off the line after the first bar, because the melody moves
    /// in half-pulses and bars in whole ones. Walking the onsets, one opens a
    /// new span once the current span has run a bar, or half a bar if the
    /// onset sits after a two-pulse gap, which is where the line breathes. So
    /// the bar is the *target* length of a span, not a grid, and the harmonic
    /// rhythm follows the phrase shape: the keepsake's packed early years get
    /// bar-length spans and its spaced-out late years get shorter ones.
    ///
    /// An onset opens a span only if half a bar of the cycle remains after
    /// it; otherwise the rest of the line stays in the current span. Without
    /// that, a chord could change on the very last note and ring for a single
    /// gap, when the final chord should already be sounding under the ending.
    ///
    /// The last span runs to the end of the cycle, through the rest at the
    /// loop seam, so the arrival is still sounding when the line comes round.
    static func spans(under stars: [Star]) -> [Range<Double>] {
        guard stars.count >= 2 else { return [] }
        let onsets = Music.schedule(for: stars)
        let gaps = Music.gaps(between: stars)
        let cycle = Music.cycleLength(for: stars)
        var openings = [0.0]
        for i in 1..<onsets.count {
            guard cycle - onsets[i] >= barLength / 2 - 1e-9 else { break }
            let running = onsets[i] - openings.last!
            let breath = gaps[i] >= Music.longestGap - 1e-9
            if running >= barLength - 1e-9 || (breath && running >= barLength / 2 - 1e-9) {
                openings.append(onsets[i])
            }
        }
        let ends = openings.dropFirst() + [cycle]
        return zip(openings, ends).map { $0..<$1 }
    }
```

- [ ] **Step 4: Run to verify they pass**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: all pass. If `testABreathOpensASpanAfterHalfABar` fails on its `gaps[4]` precondition rather than on the span assertion, the star positions do not produce the intended note values; fix the positions (the reaches must be three equal short ones, one at least 8× longer, then equal short ones) rather than the rule.

- [ ] **Step 5: Commit**

```bash
git add Sources/Model/Harmony.swift Tests/StarsongTests/HarmonyTests.swift
git commit -m "Harmony: chords change on melody onsets, at phrase length

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 4: Chords chosen by fit, with a forced cadence

**Files:**
- Modify: `Sources/Model/Harmony.swift` — add a `// MARK: - Fit` section after Spans
- Test: `Tests/StarsongTests/HarmonyTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `static func fit(of chord: Chord, in span: Range<Double>, under stars: [Star], in tuning: Music.Tuning) -> Double` — seconds of the span owned by chord-tone notes.
  - `static func pitchClass(at time: Double, under stars: [Star], in tuning: Music.Tuning) -> Int` — pitch class of the note sounding at `time` (the last onset at or before it).
  - `static func chords(under stars: [Star], in tuning: Music.Tuning) -> [Chord]` — one per span, same count and order as `spans(under:)`.

- [ ] **Step 1: Write the failing tests**

Add to `HarmonyTests`:

```swift
    // MARK: - Fit

    /// Fit is the time a chord's tones are sounding inside a span. A span
    /// entirely on the root, under major's (0, 7), is worth the whole span;
    /// under (2, 9) it is worth nothing.
    func testFitCountsChordToneTime() {
        let major = Music.tunings[0]
        let stars = line(degrees: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])   // steady, all on the root
        let span = Harmony.spans(under: stars)[0]
        let onRoot = Harmony.Chord(root: 0, tones: [0, 7])
        let offRoot = Harmony.Chord(root: 2, tones: [2, 9])
        let length = span.upperBound - span.lowerBound
        XCTAssertEqual(Harmony.fit(of: onRoot, in: span, under: stars, in: major),
                       length, accuracy: 1e-9)
        XCTAssertEqual(Harmony.fit(of: offRoot, in: span, under: stars, in: major), 0, accuracy: 1e-9)
    }

    /// A line that sits on degrees 1 and 3 — pitch classes 2 and 7 in major —
    /// is covered entirely by the dyad (7, 2) and only half by (0, 7) or
    /// (2, 9). Fit has to pick the one that covers it.
    func testFitPicksTheChordThatCoversTheMelody() {
        let major = Music.tunings[0]
        let stars = line(degrees: Array(repeating: [1, 3], count: 12).flatMap { $0 })
        let chords = Harmony.chords(under: stars, in: major)
        XCTAssertGreaterThanOrEqual(chords.count, 3, "need a free span before the cadence")
        XCTAssertEqual(chords[0].root, 7, "first span should be the dyad covering both notes")
    }

    /// The note under a chord change is the one the ear checks first, so a
    /// chord that holds it outranks any that does not. By duration alone the
    /// keepsake put a chord tone under five of nine changes; downbeat first
    /// puts one under every change the tuning allows. So: wherever *some*
    /// candidate contains the note at a span's start, the chosen chord must.
    func testAChordChangeLandsOnAChordToneWheneverItCan() {
        for tuning in Music.tunings {
            for stars in [FiftySky.stars(), line(9), line(16), line(degrees: [4, 8, 1, 6, 12, 3, 9, 2, 7, 0, 5, 11])] {
                let onsets = Music.schedule(for: stars)
                let spans = Harmony.spans(under: stars)
                let chords = Harmony.chords(under: stars, in: tuning)
                let candidates = Harmony.candidates(for: stars, in: tuning)
                XCTAssertEqual(chords.count, spans.count, tuning.name)
                for (i, (span, chord)) in zip(spans, chords).enumerated() where i < spans.count - 1 {
                    let note = onsets.firstIndex { abs($0 - span.lowerBound) < 1e-9 }!
                    let pc = Music.semitone(forY: stars[note].y, in: tuning) % 12
                    let pool = i == spans.count - 2
                        ? candidates.filter { $0 != Harmony.home(for: stars, in: tuning) }
                        : candidates
                    let possible = pool.contains { Harmony.voiced($0).contains(pc) }
                    if possible {
                        XCTAssertTrue(Harmony.voiced(chord).contains(pc),
                                      "\(tuning.name): span \(i) opens on \(pc) under \(chord.tones)")
                    }
                }
            }
        }
    }

    // MARK: - Cadence

    /// The point of the exercise. Whatever the melody, the last chord is home
    /// and it contains the note the tune rests on, so a loop seam sounds like
    /// a return rather than a join.
    func testEveryProgressionEndsAtHomeUnderTheLastNote() {
        for tuning in Music.tunings {
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                let chords = Harmony.chords(under: stars, in: tuning)
                XCTAssertEqual(chords.last, Harmony.home(for: stars, in: tuning),
                               "\(tuning.name), \(stars.count) notes did not come home")
                XCTAssertTrue(Harmony.voiced(chords.last!).contains(Harmony.tonic(of: stars, in: tuning)),
                              "\(tuning.name): the last chord does not hold the last note")
            }
        }
    }

    /// With three or more spans, the chord before the last is not home, so the
    /// ending is a real leaving and returning rather than a coin toss. Two
    /// spans or one are too short to have a journey in them.
    func testTheChordBeforeTheLastIsAway() {
        for tuning in Music.tunings {
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                let chords = Harmony.chords(under: stars, in: tuning)
                guard chords.count >= 3 else { continue }
                XCTAssertNotEqual(chords[chords.count - 2], Harmony.home(for: stars, in: tuning),
                                  "\(tuning.name), \(stars.count) notes: no cadence")
            }
        }
    }

    /// Ties fall to the chord already sounding, so a span that is indifferent
    /// does not change chord for the sake of it.
    func testTiesStayOnThePreviousChord() {
        let major = Music.tunings[0]
        // Degree 2 is pitch class 4, which only the dyad (9, 4) holds; degree
        // 3 is 7, held by (0, 7) and (7, 2). A span entirely on degree 3 after
        // one on degree 2: (0,7) and (7,2) tie, neither is the previous chord
        // (9,4), and home is (root of the last note) — make the last note
        // degree 1 (pc 2) so home is (2, 9) and is not in the tie either.
        // Then the lower root, 0, wins. (The second span is the penultimate
        // one, so home is excluded from its pool anyway.)
        let stars = line(degrees: Array(repeating: 2, count: 8) + Array(repeating: 3, count: 8)
                                  + Array(repeating: 2, count: 8) + [1])
        let chords = Harmony.chords(under: stars, in: major)
        XCTAssertEqual(chords.count, 3)
        XCTAssertEqual(chords[0].root, 9)
        XCTAssertEqual(chords[1].root, 0, "tie between (0,7) and (7,2) should go to the lower root")
    }
```

- [ ] **Step 2: Run to verify they fail**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: compile `error:` — no members `fit(of:in:under:in:)`, `pitchClass(at:under:in:)` and `chords(under:in:)`.

- [ ] **Step 3: Implement**

Add to `Harmony.swift` after the Spans section:

```swift
    // MARK: - Fit

    /// How well a chord suits a span: the time, in seconds, that notes of the
    /// chord's pitch classes are sounding inside it. Each melody note owns the
    /// time from its onset to the next (the last, to the end of the cycle).
    ///
    static func fit(of chord: Chord, in span: Range<Double>,
                    under stars: [Star], in tuning: Music.Tuning) -> Double {
        let tones = Set(voiced(chord))
        let onsets = Music.schedule(for: stars)
        let cycle = Music.cycleLength(for: stars)
        var covered = 0.0
        for (i, star) in stars.enumerated() {
            let from = onsets[i]
            let to = i + 1 < onsets.count ? onsets[i + 1] : cycle
            let overlap = min(to, span.upperBound) - max(from, span.lowerBound)
            guard overlap > 0, tones.contains(Music.semitone(forY: star.y, in: tuning) % 12) else { continue }
            covered += overlap
        }
        return covered
    }

    /// The pitch class of the note sounding at `time`: the last one to have
    /// started. Used for the note under a chord change.
    static func pitchClass(at time: Double, under stars: [Star], in tuning: Music.Tuning) -> Int {
        let onsets = Music.schedule(for: stars)
        let sounding = onsets.lastIndex { $0 <= time + 1e-9 } ?? 0
        return Music.semitone(forY: stars[sounding].y, in: tuning) % 12
    }

    /// One chord per span, chosen by fit, with the cadence forced.
    ///
    /// The last span is home, always. With three or more spans the one before
    /// it is the best-fitting chord that is *not* home, so the ending is a real
    /// leaving and returning. Two spans or one are too short for a journey and
    /// take fit alone, with the last still forced home.
    ///
    /// A chord that holds the note under the change outranks any that does
    /// not, whatever their fit: that note is the one the ear checks first, and
    /// by duration alone the keepsake put a chord tone under five of nine
    /// changes where downbeat-first puts one under every change the tuning
    /// allows. Weighting the downbeat by a bar instead was tried and is not
    /// safe — a span can run three seconds, so a chord missing the downbeat
    /// could still win on coverage.
    ///
    /// Then fit. Ties go to the chord already sounding, then to home, then to
    /// the lower root — in that order, as the tuple compares.
    static func chords(under stars: [Star], in tuning: Music.Tuning) -> [Chord] {
        let spans = spans(under: stars)
        let home = home(for: stars, in: tuning)
        let candidates = candidates(for: stars, in: tuning)
        var chosen: [Chord] = []
        for (index, span) in spans.enumerated() {
            if index == spans.count - 1 { chosen.append(home); continue }
            let cadence = spans.count >= 3 && index == spans.count - 2
            let pool = cadence ? candidates.filter { $0 != home } : candidates
            let underneath = pitchClass(at: span.lowerBound, under: stars, in: tuning)
            func rank(_ chord: Chord) -> (Int, Double, Int, Int, Int) {
                (voiced(chord).contains(underneath) ? 1 : 0,
                 fit(of: chord, in: span, under: stars, in: tuning),
                 chord == chosen.last ? 1 : 0,
                 chord == home ? 1 : 0,
                 -chord.root)
            }
            chosen.append(pool.max { rank($0) < rank($1) } ?? home)
        }
        return chosen
    }
```

- [ ] **Step 4: Run to verify they pass**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: all pass. If `testTiesStayOnThePreviousChord` fails on the span count or `chords[0].root`, check the boundaries with a `print(Harmony.spans(under: stars))` — the line's reaches alternate short and long, so its gaps are 0.15 s within a run and 0.6 s at each change of degree, and the spans open at 0, 1.65 and 3.30 s.

- [ ] **Step 5: Commit**

```bash
git add Sources/Model/Harmony.swift Tests/StarsongTests/HarmonyTests.swift
git commit -m "Harmony: choose each chord by fit, force the cadence

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 5: Wire the bed to the new rules and delete the old ones

**Files:**
- Modify: `Sources/Model/Harmony.swift` — `bed(under:in:)`; delete `tonic(in:)`, `away(in:)`, `chords(bars:in:)`; update the type's header comment and the `barPulses` comment
- Modify: `Sources/Audio/Synth.swift:32` (a stale comment)
- Test: `Tests/StarsongTests/HarmonyTests.swift` — rewrite the tests that used the deleted API

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces: `bed(under:in:)` unchanged in signature — `[Voicing]` with `delay = span.lowerBound`, `duration = noteLength`. `sound(under:in:offset:)` unchanged.

- [ ] **Step 1: Rewrite the tests that depend on the old API**

In `HarmonyTests`, **delete** these tests outright: `testEveryTuningHasSomewhereToGo`, `testProgressionsStartAtHomeToo`, `testShortMelodiesDroneAndLongerOnesMove`, `testChordsLandOneToABarInOrder`, `testTheAwayChordIsTheOneThatTravelsFurthest`, and the old `testEveryProgressionEndsAtHome` (Task 4 replaced it).

**Replace** `testEveryChordToneIsAMemberOfItsTuning` with:

```swift
    /// The whole reason the bed cannot sour a melody: every note it plays is a
    /// degree of the same tuning the melody is drawing from, so it can only
    /// sound notes the line could already have sung. Checked against the two
    /// octaves the dyads are allowed to reach across, on drawn lines and on
    /// the keepsake.
    func testEveryChordToneIsAMemberOfItsTuning() {
        for tuning in Music.tunings {
            let members = Set(tuning.degrees + tuning.degrees.map { $0 + 12 })
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                for chord in Harmony.chords(under: stars, in: tuning) {
                    for tone in chord.tones {
                        XCTAssertTrue(members.contains(tone),
                                      "\(tuning.name): \(tone) is not in \(tuning.degrees)")
                    }
                }
            }
        }
    }
```

**Replace** `testEveryChordIsARootAndAFifth` with:

```swift
    /// Root and fifth, never a third — the five tunings disagree about whether
    /// they are major or minor and a third would pick a side. The one other
    /// shape allowed is the bare tonic, for a tuning without the tonic's fifth.
    func testEveryChordIsARootAndAFifthOrTheTonicAlone() {
        for tuning in Music.tunings {
            for chord in Harmony.fifthDyads(in: tuning) {
                XCTAssertEqual(chord.tones.count, 2, tuning.name)
                XCTAssertEqual(chord.tones[0], chord.root, tuning.name)
                XCTAssertEqual(chord.tones[1] - chord.tones[0], 7, tuning.name)
            }
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                for chord in Harmony.chords(under: stars, in: tuning) {
                    XCTAssertEqual(chord.tones.first, chord.root, tuning.name)
                    switch chord.tones.count {
                    case 1: XCTAssertEqual(chord, Harmony.home(for: stars, in: tuning),
                                           "\(tuning.name): only home may be a bare note")
                    case 2: XCTAssertEqual(chord.tones[1] - chord.tones[0], 7, tuning.name)
                    default: XCTFail("\(tuning.name): \(chord.tones) is not a dyad")
                    }
                }
            }
        }
    }
```

**Replace** `testTheBedCoversTheWholeCycle` with:

```swift
    /// The bed has one chord per span and the spans tile the cycle, so the
    /// arrival is still sounding through the rest at the loop seam.
    func testTheBedCoversTheWholeCycle() {
        for tuning in Music.tunings {
            for count in 2...12 {
                let notes = line(count)
                let bed = Harmony.bed(under: notes, in: tuning)
                let spans = Harmony.spans(under: notes)
                XCTAssertEqual(bed.count, spans.count, "\(tuning.name), \(count) notes")
                XCTAssertEqual(bed.first?.delay, 0, "\(tuning.name), \(count) notes: no downbeat chord")
                for (voicing, span) in zip(bed, spans) {
                    XCTAssertEqual(voicing.delay, span.lowerBound, accuracy: 1e-9, tuning.name)
                    XCTAssertEqual(voicing.duration, Harmony.noteLength, tuning.name)
                }
            }
        }
    }
```

**Replace** `testChordsDieInsideTheirOwnBar` with:

```swift
    /// A chord is gone before the next bar. Overlapping them is what turned the
    /// first attempt into a drone — see `Harmony.noteLength`. A span opened
    /// early by a breath is half a bar, so a plucked tail can still be dying
    /// as the next chord lands; that is a string ringing on, not a pad.
    func testChordsDieInsideABar() {
        let bed = Harmony.bed(under: line(16), in: Music.default)
        XCTAssertGreaterThan(bed.count, 1, "need at least two spans to compare")
        for voicing in bed {
            XCTAssertLessThan(voicing.duration + Harmony.roll, Harmony.barLength,
                              "a chord is still sounding when the next bar lands")
        }
    }
```

**Replace** `testTheBedSitsBelowTheMelody` with:

```swift
    /// The bed sits below the melody rather than inside it. The lowest note a
    /// line can sing is the root at 220 Hz, so every tone actually sounded has
    /// to come out under that — which is what `voiced` is for, and it is not
    /// true of the unfolded dyads.
    func testTheBedSitsBelowTheMelody() {
        for tuning in Music.tunings {
            for stars in (2...16).map(line) + [FiftySky.stars()] {
                for chord in Harmony.chords(under: stars, in: tuning) {
                    for tone in Harmony.voiced(chord) {
                        XCTAssertLessThan(Harmony.frequency(semitonesAboveRoot: tone),
                                          Music.rootFrequency,
                                          "\(tuning.name): tone \(tone) is up in the melody")
                    }
                }
            }
        }
    }
```

**Replace** `testAFifthThatRunsHighBecomesTheFourthBelow` with:

```swift
    /// Folding a fifth that runs high turns it into the fourth below — the same
    /// pair of notes. Hirajoshi's dyad on 7 is the case that needs it.
    func testAFifthThatRunsHighBecomesTheFourthBelow() {
        let hirajoshi = Music.tunings.first { $0.id == "hirajoshi" }!
        let onSeven = Harmony.fifthDyads(in: hirajoshi).first { $0.root == 7 }!
        XCTAssertEqual(onSeven.tones, [7, 14])
        XCTAssertEqual(Harmony.voiced(onSeven), [7, 2])
    }
```

Leave `testTheBedIsVoicedOnSomethingThatDecays`, `testTheBedIsQuieterThanTheMelody`, `testTooShortToHarmonise`, `testFoldingKeepsEveryToneInTheTuning` and `testIntervalClassMeasuresBothDirections` exactly as they are.

- [ ] **Step 2: Run to verify the suite fails to compile only because of the old API**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: it still compiles and passes — the old functions are still present. This step confirms the rewritten tests are valid against the new API before the old one goes.

- [ ] **Step 3: Rewire `bed` and delete the old rules**

In `Harmony.swift`:

Delete `tonic(in:)`, `away(in:)` and `chords(bars:in:)` and their doc comments (the block between `fifthDyads` and `// MARK: - Pitch` that Task 2 did not add).

Replace `bed(under:in:)` with:

```swift
    /// One voicing per span, with the chord fit chose for it.
    static func bed(under stars: [Star], in tuning: Music.Tuning) -> [Voicing] {
        zip(spans(under: stars), chords(under: stars, in: tuning)).map { span, chord in
            Voicing(chord: chord, delay: span.lowerBound, duration: noteLength)
        }
    }
```

Replace the `barPulses` doc comment's first paragraph so it reads:

```swift
    /// The target length of a span, in pulses.
    ///
    /// `Music.pulse` is the shortest thing a melody subdivides to, so it reads
    /// as an eighth rather than a beat — at 0.3s that is about 100bpm, and eight
    /// of them is one bar of four. A chord every 2.4s is slow enough to be heard
    /// as harmony; changing every bar of *two* was tried on paper and is fast
    /// enough that the bed starts sounding like a second melody competing with
    /// the line. Not a grid: chords change on melody onsets, and `spans` uses
    /// this as the length to wait for.
    static let barPulses = 8
```

Replace the type's header comment (everything from `/// The chords under a melody.` down to `enum Harmony {`) with:

```swift
/// The chords under a melody, derived from the melody.
///
/// Every one of `Music.tunings` is pentatonic, which is why anything you draw
/// sounds lovely: there is no wrong note to land on. It is also why nothing you
/// draw sounds *finished*. A single line has nothing to be consonant or
/// dissonant against, so no note in it is ever an arrival — the melody is pretty
/// and it wanders. This puts something underneath it rather than changing the
/// line above, so `Music` still decides every pitch a star sings.
///
/// **Every chord tone is a member of the line's own tuning.** That is the whole
/// safety argument, and it is a stronger one than checking intervals: a bed
/// built only from scale members cannot introduce a note the melody could not
/// already have played, in any tuning, ever.
///
/// Checking intervals is what the first attempt did — reject a chord tone
/// sitting a semitone from any scale degree — and it rejected the plain
/// tonic-and-fifth drone in three tunings of five. The reason is worth keeping,
/// because it is not what it looks like: those three are exactly the tunings
/// that contain a semitone pair *of their own* (hirajoshi has 2-3 and 7-8, `in`
/// has 0-1 and 7-8, balinese has 0-1). What the rule flagged was each scale's
/// own character, which the melody is already free to play, not anything the
/// bed was doing to it.
///
/// **The bed follows the tune.** The second attempt built the bed from the bar
/// count — home on degree 0, home and away alternating by bar parity, a chord
/// every 2.4s regardless — and it was in a different key from the melody it
/// sat under: the keepsake rests on degree 4 in every tuning, and the bass
/// insisted on 0. Four rules replace that. Home is where the tune rests
/// (`tonic`, `home`). Chords change only on melody onsets, at about a bar
/// (`spans`). Each is chosen by how much of the melody it covers, with the note
/// under the change held first (`fit`, `chords`). And the cadence is forced:
/// the last chord is home and the one before it is not (`chords`).
enum Harmony {
```

In `Sources/Audio/Synth.swift` line 32, change the stale comment `chords change once a bar and ring \`Harmony.ring\`` to `chords change about once a bar and ring \`Harmony.noteLength\``.

- [ ] **Step 4: Run to verify everything passes**

RUN with `-only-testing:StarsongTests/HarmonyTests`.
Expected: all pass, no `error:`, no `warning:` lines from `Sources/` or `Tests/`. Then `grep -rn 'away(in\|chords(bars\|tonic(in' Sources Tests` must print nothing.

- [ ] **Step 5: Commit**

```bash
git add Sources/Model/Harmony.swift Sources/Audio/Synth.swift Tests/StarsongTests/HarmonyTests.swift
git commit -m "Harmony: the bed follows the tune; delete the bar-counted rules

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 6: The keepsake floor and the diagnostic print

**Files:**
- Test: `Tests/StarsongTests/HarmonyTests.swift` (the floor)
- Test: `Tests/StarsongTests/DiagnosticTests.swift` (the print, in `final class SoundDiagnostics`)

**Interfaces:**
- Consumes: everything above; `Keepsake.tuning`, `FiftySky.stars()`.

- [ ] **Step 1: Write the floor test**

Add to `HarmonyTests`:

```swift
    // MARK: - The keepsake

    /// Held the way `TuningTests` holds the tuning distance, so the fit cannot
    /// regress by eyeball. In the keepsake's own key, Balinese, six of nine
    /// chord changes land on a chord tone. Six is the ceiling: the other three
    /// open on degree 1, and Balinese has no fifth dyad containing it — that is
    /// the tuning's own character, not something the bed can fix without
    /// breaking the safety rule. Measured 2026-09-01; the bar-counted bed
    /// managed two of seven.
    func testTheKeepsakeLandsOnChordTonesWhereItsKeyAllows() {
        let stars = FiftySky.stars()
        let tuning = Keepsake.tuning
        XCTAssertEqual(tuning.id, "balinese", "the keepsake changed key; re-measure this floor")
        let onsets = Music.schedule(for: stars)
        let spans = Harmony.spans(under: stars)
        let chords = Harmony.chords(under: stars, in: tuning)
        var landed = 0
        for (span, chord) in zip(spans, chords) {
            let note = onsets.firstIndex { abs($0 - span.lowerBound) < 1e-9 }!
            let pc = Music.semitone(forY: stars[note].y, in: tuning) % 12
            if Harmony.voiced(chord).contains(pc) { landed += 1 }
        }
        XCTAssertEqual(spans.count, 9, "the keepsake's span count changed; re-measure this floor")
        XCTAssertGreaterThanOrEqual(landed, 6, "\(landed) of \(spans.count) chord changes land on a chord tone")
    }
```

- [ ] **Step 2: Run it**

RUN with `-only-testing:StarsongTests/HarmonyTests/testTheKeepsakeLandsOnChordTonesWhereItsKeyAllows`.
Expected: PASS with exactly 9 spans and 6 landed. If `landed` is higher than 6, raise the floor to the measured number. If it is lower, or the span count is not 9, stop: the implementation differs from the design's measurement, and the difference has to be understood before the floor is set.

- [ ] **Step 3: Write the diagnostic**

Add to `final class SoundDiagnostics` in `DiagnosticTests.swift`:

```swift
    /// What the bed actually does under the keepsake, in every key: home,
    /// where the chords change, what each lands under, and how many land on a
    /// chord tone. Read this before moving `Harmony.barPulses` or the fit rule.
    func testHowWellDoesTheBedFitTheKeepsake() {
        let stars = FiftySky.stars()
        let onsets = Music.schedule(for: stars)
        let spans = Harmony.spans(under: stars)
        print("BED-FIT  \(spans.count) spans over \(String(format: "%.2f", Music.cycleLength(for: stars)))s")
        print("  span lengths: " + spans.map { String(format: "%.2f", $0.upperBound - $0.lowerBound) }.joined(separator: " "))
        for tuning in Music.tunings {
            let chords = Harmony.chords(under: stars, in: tuning)
            var landed = 0
            var rows: [String] = []
            for (span, chord) in zip(spans, chords) {
                let note = onsets.firstIndex { abs($0 - span.lowerBound) < 1e-9 }!
                let pc = Music.semitone(forY: stars[note].y, in: tuning) % 12
                let tone = Harmony.voiced(chord).contains(pc)
                if tone { landed += 1 }
                rows.append(String(format: "    %5.2f  %@ under %d %@",
                                   span.lowerBound, "\(chord.tones)" as NSString, pc, tone ? "✓" : "✗"))
            }
            print(String(format: "  %-18@ tonic %d  home %@  %d of %d changes on a chord tone%@",
                         tuning.name as NSString,
                         Harmony.tonic(of: stars, in: tuning),
                         "\(Harmony.home(for: stars, in: tuning).tones)" as NSString,
                         landed, spans.count,
                         tuning.id == Keepsake.tuning.id ? "   <- her key" : ""))
            rows.forEach { print($0) }
        }
    }
```

- [ ] **Step 4: Run it and read the print**

RUN with `-only-testing:StarsongTests/SoundDiagnostics/testHowWellDoesTheBedFitTheKeepsake`, but replace the trailing `grep` with `grep -A 60 'BED-FIT'`.
Expected: nine spans; major, minor, hirajoshi and In at 9 of 9; Balinese at 6 of 9 with every ✗ under pitch class 1; Balinese's tonic 10 and home `[10]`. Anything else means the implementation drifted from the probe the design was measured with — investigate before continuing.

- [ ] **Step 5: Commit**

```bash
git add Tests/StarsongTests/HarmonyTests.swift Tests/StarsongTests/DiagnosticTests.swift
git commit -m "Hold the keepsake's chord-tone floor, and print the bed's fit

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP"
```

---

### Task 7: Whole suite, on a phone if one is there

**Files:** none new.

- [ ] **Step 1: Run every unit test**

```bash
xcodegen generate > /dev/null && xcodebuild test -project Starsong.xcodeproj -scheme Starsong \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:StarsongTests 2>&1 \
  | grep -E "Test Case .* failed|error:|(Sources|Tests)/.*warning:|\*\* TEST|Executed"
```

Expected: an `Executed N tests, with 0 failures` line, `** TEST SUCCEEDED **`, no `failed`, `error:` or `warning:` lines.

- [ ] **Step 2: Listen, if the device `Lati` is plugged in**

Open the keepsake on the device and press Play. What to listen for: the bass should agree with the note the tune opens and closes on, the last chord should sound like an arrival, and the late years should not sound like a second tune competing with the first. If the late years *do* sound busy — a chord every 1.2 s under one note every 0.6 s — note it in the PR; the fix is a spec change (the half-bar breath rule), not a tweak here. Put the run destination back to `Lati` afterwards if it was changed.

- [ ] **Step 3: Open the PR**

```bash
git push -u origin bed-follows-the-tune
gh pr create --title "The chord bed follows the tune" --body "$(cat <<'BODY'
The keepsake's bed and its melody were in different keys: the spiral rests on
scale degree 4 in every tuning, and the bed called degree 0 home. Harmony is
now derived from the melody — home is the note the tune rests on, chords change
only on melody onsets at about a bar, each is chosen by how much of the melody
it covers, holding the note under the change first, and the cadence is
forced. Every chord tone is still a member of the tuning.

Measured on the keepsake: chord changes landing on a chord tone go from 2 of 7
to 6 of 9 in her key (the ceiling the safety rule allows in Balinese) and 9 of 9
in the other four. A floor test holds the 6, and a diagnostic prints the fit.

Spec: docs/superpowers/specs/2026-09-01-bed-follows-the-tune-design.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01RYU61ajNbMucqFWMXJkaAP
BODY
)"
```
