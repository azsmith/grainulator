# Third-Party Notices

Grainulator incorporates code from the following open-source projects.
Their original license terms apply to their respective portions of this software.

---

## Mutable Instruments — Plaits, Rings, stmlib

**License:** MIT
**Copyright:** 2012-2017 Emilie Gillet
**Source:** https://github.com/pichenettes/eurorack, https://github.com/pichenettes/stmlib
**Location in project:** `Source/Audio/Synthesis/Plaits/`, `Source/Audio/Synthesis/Rings/`

The Plaits and Rings synthesis engines and supporting stmlib library were
created by Emilie Gillet for Mutable Instruments. This project adapts the
original embedded firmware code for use as a desktop audio engine.

See `LICENSE-MUTABLE-INSTRUMENTS.txt` for the full license text.

---

## Mutable Instruments — Marbles (Design Inspiration)

**License:** MIT
**Copyright:** 2015-2018 Emilie Gillet
**Source:** https://github.com/pichenettes/eurorack (marbles/)
**Location in project:** `Source/Application/ScrambleEngine.swift`, `Source/Application/ScrambleManager.swift`

The Scramble probabilistic sequencer is inspired by the design and concepts of
Mutable Instruments Marbles by Emilie Gillet. The implementation is original
Swift code — no firmware source code from the Marbles module was used. Concepts
adapted include: probabilistic gate generation with complementary outputs,
Deja Vu pattern memory with variable loop length, distribution shaping (Spread),
probability skew (Bias), and the three-output note generator with control modes.

---

## DaisySP — Drum Synthesis

**License:** MIT
**Copyright:** 2020 Electrosmith, Corp.; portions by Emilie Gillet
**Source:** https://github.com/electro-smith/DaisySP
**Location in project:** `Source/Audio/Synthesis/DaisyDrums/DaisySP/`

Drum synthesis models (AnalogBassDrum, SynthBassDrum, SynthSnareDrum, HiHat)
and SVF filter ported from DaisySP, which itself incorporates work from
Mutable Instruments.

---

## OSCKit

**License:** MIT
**Copyright:** 2023 Steffan Andrews
**Source:** https://github.com/orchetect/OSCKit
**Location in project:** Swift Package dependency

Open Sound Control (OSC) protocol library for Swift. Includes transitive
dependencies:
- **SwiftASCII** — MIT, Copyright 2021 Steffan Andrews (https://github.com/orchetect/swift-ascii)
- **CocoaAsyncSocket** — Public Domain or BSD, Copyright 2017 Deusty, LLC

---

## TinySoundFont (tsf.h)

**License:** MIT
**Copyright:** 2017-2025 Bernhard Schelling
**Source:** https://github.com/schellingb/TinySoundFont
**Location in project:** `Source/Audio/Synthesis/SoundFont/tsf.h`

SoundFont 2 synthesis library. Based on SFZero by Steve Folta
(Copyright 2012, https://github.com/stevefolta/SFZero).

---

## dr_wav (dr_wav.h)

**License:** Public Domain or MIT-0 (choose either)
**Author:** David Reid
**Source:** https://github.com/mackron/dr_libs
**Location in project:** `Source/Audio/Synthesis/SoundFont/dr_wav.h`

Single-file WAV audio loader/decoder.

---

## Moog Ladder Filter Collection

The `Source/Audio/Synthesis/Granular/MoogLadders/` directory contains multiple
implementations of the Moog ladder filter topology, each with its own license:

### HuovilainenModel.h
**License:** LGPL v2.1 (based on CSound5 implementation)
**Original author:** Victor Lazzarini (CSound5)
**Algorithm:** Antti Huovilainen (2004, 2010)
**Source:** https://github.com/csound/csound

Note: This file is a derivative of LGPL v2.1-licensed CSound5 code. The LGPL
terms apply to this file specifically. The LGPL permits inclusion in a
larger MIT-licensed work provided the LGPL-covered portion can be modified
and replaced by users.

### RKSimulationModel.h
**License:** BSD 2-Clause
**Copyright:** 2015 Miller Puckette

### ImprovedModel.h
**License:** ISC
**Copyright:** 2012 Stefano D'Angelo

### StilsonModel.h
**License:** Public Domain
**Author:** David Lowenfels (2003)
Originally released as the moog~ Pure Data external.

### KrajeskiModel.h
**License:** Public Domain
**Author:** Aaron Krajeski

### OberheimVariationModel.h
**License:** Permissive (book source code, free to use without licensing or fees)
**Author:** Will Pirkle
**Source:** "Designing Software Synthesizer Plugins in C++" and "Designing Audio Effect Plugins in C++"

### MusicDSPModel.h
**License:** Public Domain (from musicdsp.org archive)
**Author:** Unknown

### MicrotrackerModel.h
**License:** Unlicense (Public Domain)
**Author:** Magnus Jonsson
**Source:** https://github.com/magnusjonsson/microtracker

### HyperionModel.h
**License:** Public Domain / Unlicense
**Authors:** Dimitri Diakopoulos and Claude (2025)

### LadderFilterBase.h, MoogUtils.h
**License:** Public Domain
**Author:** Dimitri Diakopoulos
**Source:** https://github.com/ddiakopoulos/MoogLadders

The Moog ladder filter collection originates from the MoogLadders project by
Dimitri Diakopoulos (https://github.com/ddiakopoulos/MoogLadders).

---

## Apple Frameworks (System)

This project uses macOS system frameworks (CoreAudio, AVFoundation, CoreMIDI,
SwiftUI) which are provided by Apple as part of macOS and are not redistributed.
