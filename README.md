# Starsong for iOS

[![Tests](https://github.com/lati-cooki/Starsong/actions/workflows/tests.yml/badge.svg)](https://github.com/lati-cooki/Starsong/actions/workflows/tests.yml)

Tap or drag across stars to draw a constellation. Each star sings a note — higher
stars sing higher, and stars that sit close together tumble out quickly — and
Claude will name the figure you drew and tell its story. Keep the ones you like;
the sky they were drawn on comes back with them. Or pick a real constellation and
hear what Orion sounds like.

It also holds a keepsake: **Fifty**, a birthday present built out of the same
sky — fifty stars wound into a spiral, one for every year of a life, tuned to a
key her own name picks. See below.

Native SwiftUI. iOS 17+, iPhone and iPad.

## Build and run

The Xcode project is generated from `project.yml`, so it never has to be
committed or merged:

```bash
brew install xcodegen && xcodegen generate && open Starsong.xcodeproj
```

Then pick a simulator or your device and hit Run. Audio is much nicer on
hardware than in the simulator.

Command line, if you prefer:

```bash
xcodegen generate && xcodebuild -project Starsong.xcodeproj -scheme Starsong -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

CI runs the same thing on every push — see `.github/workflows/tests.yml`. It
picks whatever iPhone simulator the runner happens to have rather than naming
one, since that is the usual way these workflows rot.

## Naming constellations

"Name it" calls the Claude API. Without a key the app still works — it falls
back to a local story — so this step is optional. The person button in the title
bar shows at a glance whether a key is installed.

**Bring your own key.** Open Profile and paste one. It is checked before it is
stored, by asking for one short myth, so a key that will not work says so
immediately instead of turning into a silent fallback later. It is kept in the
device Keychain (`whenUnlockedThisDeviceOnly`), never written to the sky log or
a shared constellation, and can be removed from the same screen.

**Or build one in**, which is handy for a checkout you keep going back to:

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Put your key in that file (`ANTHROPIC_API_KEY = sk-ant-...`); it is git-ignored
and feeds `Info.plist` through the xcconfig. Don't quote the value or add a
trailing comment — xcconfig treats `//` as the start of a comment.

A key entered in Profile wins over one built in — it was chosen more recently
and it is the one you can change without rebuilding. Removing it falls back to
the built-in key, if there is one.

Either way the key sits on the device and the device talks to the API directly.
That is fine for something you run yourself. **Anything you ship to other people
should call your own server instead**, so no key travels: an app binary is not a
secret, and a key inside one can be extracted.

The request uses Claude Opus 5 with [structured
outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs),
so the name and myth arrive as schema-checked JSON rather than prose to be
regex'd. Server-side fallback is enabled, and a refusal or a network failure
lands on the local story instead of an error.

The app icon is generated rather than checked in by hand — edit the drawing and
re-run it:

```bash
swift Tools/make-icon.swift
```

## How it fits together

| | |
|---|---|
| `Sources/Model/Star.swift` | Stars, pulses, shooting stars — all positions are 0–1 fractions of the sky, so rotating the device keeps a constellation intact |
| `Sources/Model/Music.swift` | Five pentatonic tunings, and the rhythm a shape implies |
| `Sources/Model/Atlas.swift` | Eight real constellations, by catalogue position |
| `Sources/Model/SkyModel.swift` | The one piece of mutable state — sky, constellation, playback, naming |
| `Sources/Model/SavedSky.swift` | A kept constellation: a seed, a star count, and the indices you connected |
| `Sources/Model/SkyLog.swift` | The kept skies, as JSON on disk |
| `Sources/Audio/Instrument.swift` | The five voices. Every waveform is synthesised — there are no samples |
| `Sources/Audio/Synth.swift` | `AVAudioEngine`, the pool of players, and the cache of rendered notes |
| `Sources/Naming/Namer.swift` | The Claude call |
| `Sources/Fifty/Keepsake.swift` | **The only file with anything personal in it**: a name, a birth year, two messages, fifty lines |
| `Sources/Fifty/NameSong.swift` | A name, turned into a melody — and into the key the keepsake is played in |
| `Sources/Fifty/FiftySky.swift` | The spiral: where each year sits, and what that does to the tune |
| `Sources/Fifty/KeepsakeModel.swift` | Which year is showing, what has been read, and playback |
| `Sources/Views/SkyCanvas.swift` | Drawing. A pure function of the state above plus the current time |
| `Sources/Views/SkyLogView.swift` | The kept skies, with share and delete |
| `Tests/StarsongTests` | 189 tests over the tunings, the rhythm, the haptics, the atlas projection, the sky, hit testing, star navigation, layering, the effect clock, persistence and its migration, the Claude response parsing, and the keepsake |
| `Tests/StarsongUITests` | 10 tests over the accessibility tree, the drawing gesture, and the keepsake, through the real UI |

Effects are **time-parametric**: a shooting star knows where it started, how
fast it moves, and when it was born, so its position is a function of the clock
rather than an accumulation of per-frame steps. Nothing mutates state during a
draw pass, and motion looks the same at 60 Hz and 120 Hz. Playback leans on the
same property — pressing Play schedules every pulse into the future in one go.

Because the generator is seeded, **a whole night sky costs about 370 bytes** —
the seed, how many stars it made, and which of them you connected. Keeping a
constellation stores that; reopening it replays the generator and every field
star lands back where it was. The star count is saved with the entry rather than
recomputed, so a sky kept on a phone reopens intact on a tablet.

Entries are validated on load: an index pointing past the end of its sky would
crash the renderer, so incoherent entries are dropped rather than trusted.

## Voices

Five, chosen per line, so a piano melody can run over a plucked one. There are
no samples in the bundle — nothing here is a recording — and synthesis lands
unevenly, so the names are as honest as they can be:

- **Chime** — what the app started with, and still the default.
- **Pluck** — Karplus-Strong: a burst of noise trapped in a loop one wavelength
  long, low-passed a little each lap so the high frequencies die first, which is
  what a real string does. The one that sounds like the thing it is named after.
- **Piano** — a struck string with stretched partials. Nearer an electric piano
  than a grand.
- **Brass** — slow to speak, then blooms and holds, with a little vibrato.
  Trumpet-*ish*.
- **Bell** — partials that don't line up into a harmonic series.

Karplus-Strong takes its pitch from the length of the delay line, and the line
only holds so many samples of history: `line[index]` is the *oldest* and every
step forward is newer, so interpolating toward the next slot **shortens** the
delay. Getting that backwards made every note sharp, and worse the higher it
went — 74 cents at the top of the sky. `InstrumentTests` measures the
fundamental of the rendered buffer by autocorrelation and asserts it lands
within 12 cents, with the peak interpolated, because one integer lag is 68 cents
wide up there and a whole-bin answer could not have caught it.

There is also a test that **fails if any two voices measure too alike**, on
brightness and decay. Five tunings once shipped that were nearly the same scale
because they were picked by ear; timbres get measured.

## Layers

Press Play and the constellation **loops** rather than playing once. Draw while
it is looping and you start a **new line** over the top — up to three — each in
its own colour, each looping on **its own cycle**. Lines of different lengths
drift against each other instead of marching in step, so two constellations
become one piece of music rather than two takes of the same one. Everything is
pentatonic, so drifting lines can't collide into a wrong note.

There is no button for adding a layer. Drawing over something that is already
playing is the gesture, once per take: the first star you touch opens the line,
the rest extend it. Stop and play again to start another.

Undo works while the loop runs — it takes the last star off the line you are
drawing, and an empty line disappears, handing you back the one below.

## Shape is melody, and shape is also rhythm

A constellation's pitches come from how high its stars sit. Its **rhythm** comes
from how far apart they are — but the first attempt at this shipped a metronome,
and it is worth saying why, because the mistake is easy to repeat.

Mapping distance straight onto time sounds obviously right and does not work.
Measured on drawn lines, every gap came out within a few percent of every other:

    tight cluster   0.18 0.18 0.18     spread x1.02
    typical drag    0.26 0.26 0.27     spread x1.04

Tempo varied between constellations, so reasoning about it felt convincing, but
inside any one line there was nothing to hear. Two fixes: gaps are now **note
values** — half, one, or two pulses — because a rhythm needs discrete categories
and a continuum just jitters; and each reach is judged against *that line's own*
range rather than an absolute scale, so a cramped constellation swings as much as
a sprawling one. A line drawn with even spacing still ticks steadily, which is
honest — it is an even line.

    Orion           0.60 0.30 0.60 0.60 0.15 0.15 0.60   spread x4.00
    drawn by drag   0.15 0.30 0.15 0.60 0.60 0.15

The shared pulse also means layered lines lock to one tempo while running to
different lengths — polymeter rather than drift.

Each night is tuned by its own seed. The scales were **chosen by search, not by
ear**, because ear picked badly twice: the first set had pairs differing in 2
notes out of 15 across the whole sky, which is not a different mood, it is the
same one with a wobble. The five that remain have a worst pair differing in 6 of
15, and `TuningTests` holds that floor. The current one is printed under the
wordmark like a key signature.

`SoundDiagnostics` is not a test suite so much as a set of measurements — it
prints the tuning distances, the gap patterns for a range of shapes, and what
twenty simulated finger-drags actually produce. Run it before changing any of
these numbers.

## Real constellations

Eight of them, in `Atlas.swift`, stored as J2000 catalogue coordinates for their
named stars and projected onto the sky with a gnomonic (tangent-plane) projection
about each figure's own centre — the same construction a star chart uses for a
small patch of sky, so straight lines stay straight and the shape you know stays
the shape you know. East is drawn to the left, as it is when you look up.
Magnitudes are approximate and only set how large a star is drawn.

Starsong draws one continuous line, so each figure is stored as a *walk*: the
order to visit its stars, doubling back through a junction where the traditional
figure branches. A repeated star is a repeated note, which is a perfectly good
thing for a melody to do.

Picking one lays it over a fresh field of invented stars, already drawn, so you
can play it, keep it, or add to it. `AtlasTests` renders every figure to a
contact sheet — a wrong coordinate is obvious in a picture and invisible in a
number — and asserts that Orion's belt is still collinear after projection.

## Fifty

A birthday present, and the reason the `Sources/Fifty` folder exists. One screen,
nothing to navigate: a name, fifty stars, and a card that says what a year held.
Touch a star and it sings the note it sits at and shows you its year. Press play
and the whole life goes past in order, the card following along.

**Everything personal lives in one file.** `Sources/Fifty/Keepsake.swift` holds a
name, the year she was born, two messages and fifty lines — one per year — and
nothing else in the app has to be edited to make the keepsake somebody else's. A
year left blank is still a star and still sings; it just shows its number, so it
can be filled in later. Set `opensOnLaunch` to `true` in the same file and the
app opens straight into it rather than into Starsong, which is the difference
between a room inside your app and an app that is hers. It ships `false` so the
tests still find the night sky where they expect it.

**The stars are a spiral, not a row.** Fifty stars across a phone would be eight
points apart and read as a dotted line. Wound out from the middle they are
sixteen points apart at the closest, and the shape says the thing the list is
for. Two musical properties then fall out of the geometry rather than being
bolted on: height is pitch, so the melody rises and falls once per turn and
widens as it goes; and `Music.gaps` reads rhythm from how far apart stars sit, so
the early years — packed near the middle — come quickly and the later ones are
given room. The whole fifty runs about fifteen seconds.

Year one was at the exact centre in the first draft, and the opening decade came
out five points apart: a smudge rather than ten stars. The spiral now starts a
quarter of the way out, which costs nothing.

**Her name is the key.** Letters become notes by the rule the rest of the app
already uses — height is pitch — mapped in alphabetical order, A at the bottom of
the band and each letter one note up. The band wraps after eleven letters, and
the wrap is the point: stretching A-to-Z across the whole sky instead put M and N
an octave apart, which turns most names into a siren. Wrapped, letters that are
neighbours sound like neighbours, and AMANDA comes out as C-E-C-G-A-C, a phrase
that steps. The name also picks the scale — through a written-out FNV hash rather
than `hashValue`, which is seeded per process and would have tuned the keepsake
to a different key on every launch — and wavers the spiral's radius, measured
against the name's own average rather than the middle of the scale. Against the
scale, AMANDA sings low enough that every one of its numbers came out negative
and the waver was a uniform shrink with nothing of her name left in it.

**Without seeing it**, the sky is one adjustable element that walks the years in
order, sounding and reading each as it arrives — the same shape the main sky
takes, for the same reason. Fifty separate elements would technically expose
every year and nobody would swipe through fifty dots to find 1996. A year with
nothing written for it still says so, because silence would leave you swiping
past a star that just sang without ever hearing which one it was.

## Playing it without seeing it

The sky is a `Canvas`, which is a single opaque rectangle as far as VoiceOver is
concerned. Exposing seventy stars as seventy elements would pass an audit and be
useless — nobody swipes through seventy dots to find a note.

Instead the sky is **one adjustable element**. Swiping up and down walks the
stars **in pitch order, lowest to highest**, sounding each one as it arrives, so
the sky can be scanned by ear; double tap adds the current star to the line. The
ordering is the part that matters: swiping up moves up the sky *and* up the
scale, so the gesture and the instrument agree.

The same three moves are also named actions in the Actions rotor — "Next star,
higher", "Previous star, lower", "Add this star" — because the adjustable gesture
is only useful if you think to try it, and a named action can be found by
reading. Adding a star posts an announcement naming the note, since focus stays
on the sky and a value nobody is listening to would go unheard.

Where the navigation is sitting is **drawn**, as a dashed ring. That is for
someone with low vision or using Switch Control, and it is also how the feature
gets tested.

Reduce Motion holds the sky still — no twinkle, no shooting stars. Pulses stay:
they are brief feedback for something you just did, not ambient movement.

**What is and isn't verified.** `StarNavigationTests` covers the ordering, the
cursor, the announcements, and the note names; `CursorRenderingTests` renders the
ring and the still sky and compares them. The UI tests confirm the sky is present
in the accessibility tree, labelled, and says how to begin, and that every
control is named. Reduce Motion is verified end to end on a simulator: with it
on, two screenshots seconds apart are byte-identical; with it off, they differ.

**The adjustable gesture has never been driven under VoiceOver, and it cannot be
here.** XCUITest reads the accessibility *tree* but cannot invoke accessibility
*actions* — `tap()` sends a real touch, and only VoiceOver turns a double tap
into an activation; `adjust` drives real sliders only. And VoiceOver is not
present in the iOS Simulator at all — Settings → Accessibility has no VoiceOver
row, so it cannot be switched on there by any means.

Verifying it needs a physical device:

1. Settings → Accessibility → VoiceOver, on. (Set the Accessibility Shortcut
   first, so a triple-click of the side button gets you back out.)
2. Open Starsong and single-tap the sky. It should say "Night sky", then the
   number of stars and how to begin.
3. Swipe up and down with one finger. Each swipe should move a note up or down
   the scale, sound it, and say its name and where it is.
4. Double tap. It should say which note you added and how many stars are on the
   line, and the dashed ring should be sitting on that star.
5. Swipe up with three fingers, or use the Actions rotor, to find "Next star,
   higher", "Previous star, lower", and "Add this star".

## What changed from the browser version

- `Canvas` + `TimelineView` replaces `<canvas>` + `requestAnimationFrame`.
- `AVAudioEngine` generates the same triangle+sine ping in-process; no Web Audio.
- Haptic tick on each star via `.sensoryFeedback`.
- Dragging draws a constellation in one stroke, not just tap-by-tap.
- Constellations can be kept, reopened, and shared as a star card.
- Rhythm comes from the spacing of the stars; each night has its own tuning.
- Eight real constellations can be picked from a list and played.
- The sky can be scanned by ear and drawn on without seeing it.
- Constellations loop, and up to three can play at once.
