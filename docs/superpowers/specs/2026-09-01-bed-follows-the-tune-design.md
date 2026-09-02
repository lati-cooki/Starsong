# The bed follows the tune

*2026-09-01. Design for replacing the chord rules in `Sources/Model/Harmony.swift`.*

## The problem

The keepsake's chord bed and the keepsake's melody are in different keys.

The fifty-star spiral opens near the top of the sky and closes at the bottom of
its own rim, and both of those heights land on scale degree 4. That is geometry,
so it holds in every one of the five tunings. The bed treats degree 0 as home.
In Amanda's key, Balinese, the tune opens and closes on G while the bass says A.

Measured on the keepsake as it ships:

| | |
|---|---|
| Melody's first and last pitch class | degree 4, in all five tunings |
| Bed's home root | degree 0, always |
| Bar lines where the melody note is a chord tone | 2 of 7 |
| Bar lines that fall on a melody onset | 2 of 7; the rest are 0.15 s off |
| Final bar | melody holds G; bass plays A and E |

Two further faults come from the same cause, which is that the bed is built from
the bar count rather than from the notes:

- **Harmonic rhythm ignores phrase shape.** Thirty stars go by in about six
  seconds, then the last ten take nine. A chord every 2.4 s regardless is the
  metronome mistake `Music.gaps` already documents for rhythm.
- **Home and away alternate by bar parity, blind to the melody.** Bar four puts
  the melody on degree 1 directly over the home root, a minor second against
  the bass; bars one and five have the melody sitting on degree 0 while the bed
  plays away.

## The decision

The bed follows the tune. The spiral does not move, and nothing in the
keepsake model changes. Harmony is derived from the melody, in four rules.

### 1. Home is where the tune rests

The **tonic** is the pitch class of the melody's last note.

The **home chord** is the fifth dyad rooted on the tonic when `tonic + 7` is a
member of the tuning. Major, minor and hirajoshi have it. Otherwise it is the
**tonic alone**, `[tonic]`, which is bare but unambiguous. In (rests on 8) and
Balinese (rests on 10) take this form. Not an octave: `voiced` folds every tone
into one octave, so `[tonic, tonic + 12]` would come out as the same note
rolled twice, a flam rather than a chord.

Every chord tone is still a member of the tuning, so the safety argument at the
top of `Harmony.swift` stands unchanged. The comment explaining why interval
checking was rejected stays too; it is still the reason.

### 2. Chords change on onsets, at phrase length

A chord may change only on a melody onset. The bed is divided into **spans**:

- The first span opens at the downbeat.
- Walking the onsets in order, an onset opens a new span when the current span
  has run at least `barLength`, **or** at least `barLength / 2` if the gap
  before that onset is a two-pulse gap (`Music.longestGap`), which is where the
  line breathes — **and only if at least `barLength / 2` of the cycle remains
  after that onset.** Otherwise the remaining notes stay in the current span.
  Without this a chord could change on the very last note and ring for a
  single gap; the final chord should already be sounding under the ending.
- The last span runs to `Music.cycleLength`.

`barPulses`, `barLength` and `noteLength` keep their values and their comments.
A bar is now the *target* length of a span rather than a grid.

### 3. Chords are chosen by fit

The **candidates** are every fifth dyad in the tuning (`fifthDyads`) plus the
home chord, deduplicated by pitch-class set.

Within a span, each melody note owns the time from its onset to the next onset
(the last note owns the time to the end of the cycle), clipped to the span. A
chord's **fit** is the total owned time of notes whose pitch class is one of the
chord's tones.

**The note under the chord change comes first.** A chord that holds the note
sounding at the span's start outranks any chord that does not, whatever their
fit. That note is the one the ear checks first; measured on the keepsake, fit
by duration alone put a chord tone under five of nine changes, and holding the
downbeat first puts one under every change the tuning allows. Balinese has no
fifth dyad containing degree 1, so three of its nine changes sit under a note
no safe chord can hold, and that is the tuning's own character, not a fault in
the rule. (Weighting the downbeat by a bar was tried first and is not safe: a
span can run three seconds, so a chord missing the downbeat could still win.)

Among the chords that hold the downbeat, or among all of them when none does,
the chord for a span is the one with the greatest fit. Ties go to the chord
the previous span used, then to home, then to the lower root.

### 4. The cadence is forced

- The **last span is home**, always.
- When there are at least three spans, the **penultimate span** is the
  best-fitting candidate that is not home. Two spans or one are too short to
  leave and return; they take rule 3 with the last span forced home.

`away(in:)` and `chords(bars:in:)` are deleted, not kept alongside.

## What stays

The voice (`Instrument.pluck`), `volume`, `roll`, `noteLength`, `voiced` and
its octave fold, `Voicing`, `bed(under:in:)` as the public shape, and
`sound(under:in:offset:)` as the keepsake model calls it. The `Synth` bed pool
must hold every ping of the bed at once, because `Harmony.sound` schedules the
whole bed in one burst and `Synth` stops a voice when it reuses it; eight
voices, sized by overlap, cancelled the opening chords. It is now 32, and a
test holds the keepsake's bed inside it.

## Interfaces

```swift
enum Harmony {
    static func tonic(of stars: [Star], in tuning: Music.Tuning) -> Int      // pitch class 0..<12
    static func home(for stars: [Star], in tuning: Music.Tuning) -> Chord
    static func candidates(for stars: [Star], in tuning: Music.Tuning) -> [Chord]
    static func spans(under stars: [Star]) -> [Range<Double>]               // seconds from the downbeat
    static func bed(under stars: [Star], in tuning: Music.Tuning) -> [Voicing]
}
```

`Chord` keeps `root` and `tones`; `tones` has two entries for a dyad and one
for a bare tonic. `Voicing.delay` is the span's start. The existing
root-and-fifth test becomes root-and-fifth or tonic-alone.

The melody's pitch class needs a helper, since `Music.pitch` computes it inline
and throws it away: `Music.semitone(forY:in:)` returning semitones above the
tuning root, from which the pitch class is `% 12`.

## Testing

`HarmonyTests` is rewritten around the new rules. Kept as they are: every chord
tone is a tuning member; the bed is voiced on something that decays; quieter
than the melody; sits below the melody; folding keeps every tone in the tuning;
interval class measures both directions; too short to harmonise.

New:

- The tonic is the last note's pitch class, on a hand-built line, in every tuning.
- The final chord contains the final note, in every tuning, on the keepsake.
- With three or more spans the penultimate chord is not home.
- Every chord onset is a melody onset.
- No span is shorter than half a bar (except the lone span of a line whose
  whole cycle is shorter than that), and none but the last is longer than a
  bar plus one two-pulse gap, which is the furthest an onset can be from the
  bar it was waiting for. The last span may run long; it is the cadence.
- Fit picks the chord that covers the melody: a line that sits on one dyad's
  tones for a whole span gets that dyad.
- Every chord change lands on a chord tone whenever the tuning has a
  candidate containing the note under it, on the keepsake, in every tuning.
- A **floor** on the keepsake spiral in its own key, Balinese: six of nine
  chord changes land on a chord tone, held the way `TuningTests` holds the
  tuning distance. Six is the ceiling the safety rule allows there.

`DiagnosticTests` gains a print of the keepsake's tonic, spans, the chord and
melody note at each onset, and the chord-tone count, so the numbers are visible
before anyone moves a threshold.

## Out of scope

Moving the spiral so the tune ends on the tuning root. Thirds. A bed under the
main sky's constellations. Any change to how the melody's pitches or rhythm
are decided.
