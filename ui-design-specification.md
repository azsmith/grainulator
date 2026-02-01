# Grainulator UI Design Specification

## Table of Contents
1. [Design Philosophy](#design-philosophy)
2. [Color Palette & Typography](#color-palette--typography)
3. [View Modes](#view-modes)
4. [Main Window Layout](#main-window-layout)
5. [Component Specifications](#component-specifications)
6. [Interaction Patterns](#interaction-patterns)
7. [Visual Feedback](#visual-feedback)
8. [Accessibility](#accessibility)
9. [Responsive Design](#responsive-design)

---

## 1. Design Philosophy

### 1.1 Core Principles

**Clarity Through Minimalism**
- Focus on essential controls, hide complexity until needed
- Clear visual hierarchy: primary controls prominent, secondary controls accessible
- Generous use of whitespace to reduce cognitive load

**Performance-Focused Design**
- Real-time visual feedback for all audio parameters
- Animations that enhance understanding, not decoration
- Responsive UI that never blocks audio processing

**Hardware-Inspired Aesthetics**
- Influenced by modular synthesizers and tactile instruments
- Physical metaphors for abstract DSP concepts
- Dark color scheme to reduce eye strain during long sessions

**Musical Workflow**
- Controls organized by musical function, not technical implementation
- Quick access to common operations
- Visual feedback that aids musical decision-making

### 1.2 Design Goals

1. **Immediate playability**: Key parameters accessible within one click
2. **Visual learning**: UI teaches granular synthesis concepts through interaction
3. **Non-destructive workflow**: Encourage experimentation without fear
4. **Performance-ready**: Suitable for live use, not just studio work

---

## 2. View Modes

### 2.1 Overview

Grainulator supports three primary view modes to accommodate different workflows and focus needs:

1. **Multi-Voice View** - See all voices simultaneously (default)
2. **Focus View** - Single voice takes full width with all parameters visible
3. **Performance View** - Minimal controls, maximum visual feedback

### 2.2 Multi-Voice View (Default)

**Layout**: Side-by-side display of Granular and Plaits sections
- Both engines visible simultaneously
- Compact parameter layout
- Quick switching between voices via track selector
- Best for: Mixing, balancing, overview of entire project

**Visual Characteristics**:
- Granular section: Left half of window
- Plaits section: Right half of window
- Effects and Mixer sections: Full width below
- Track selector shows all 4 granular tracks

### 2.3 Focus View

**Activation**:
- Double-click voice section header
- Click maximize icon in voice header
- Keyboard shortcut: `Cmd + F` (cycles through voices)
- Right-click voice → "Focus on Voice"

**Layout**: Selected voice expands to full width
```
┌────────────────────────────────────────────────────────────────┐
│  [◀ Back to Multi-Voice]    GRANULAR VOICE 1 - Focused    [⚙] │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    WAVEFORM DISPLAY                       │  │
│  │                    (Expanded Height: 200px)               │  │
│  │                                                           │  │
│  │  ≈≈≈≈▓▓▓▓▓▓▓▓▓▓████ ▒ ████▓▓▓▓▓▓▓▓▓▓▓▓≈≈≈≈             │  │
│  │  ≈≈≈▓▓▓▓▓▓▓▓▓▓▓████ ▒ ████▓▓▓▓▓▓▓▓▓▓▓▓≈≈≈              │  │
│  │                      ┃                                    │  │
│  │  Splice 1: Intro    ┃ Splice 2: Main                     │  │
│  │                                                           │  │
│  │  [Grain Cloud Visualization Active]                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  TRACK SELECTOR & ROUTING                                      │
│  ┌────┬────┬────┬────┐  Solo/Mute: [S][M]  Quantize: [Oct+5▼]│
│  │ 1▓ │ 2  │ 3  │ 4  │                                         │
│  └────┴────┴────┴────┘                                         │
│   Active track highlighted, all visible in Focus View          │
│                                                                 │
│  CORE PARAMETERS (Full Size Knobs: 80px)                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│  │  SLIDE  │  │  GENE   │  │  MORPH  │  │  VARI   │          │
│  │         │  │  SIZE   │  │         │  │  SPEED  │          │
│  │    ◉    │  │    ◉    │  │    ◉    │  │    ◉    │          │
│  │         │  │         │  │         │  │         │          │
│  │  0.500  │  │ 120 ms  │  │  0.650  │  │  1.000  │          │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘          │
│                                                                 │
│  ┌─────────┐  ┌─────────┐                                     │
│  │ORGANIZE │  │  PITCH  │         [Record] [▶ Play]           │
│  │         │  │         │                                      │
│  │    ◉    │  │    ◉    │         Recording: [Off ▼]          │
│  │         │  │         │         SOS Mix:   [━━━━○━━━]       │
│  │ Splice 0│  │  +7 st  │                                      │
│  └─────────┘  └─────────┘                                     │
│                                                                 │
│  EXTENDED PARAMETERS (Always Visible in Focus View)            │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│  │ SPREAD  │  │ JITTER  │  │ FILTER  │  │  RES    │          │
│  │         │  │         │  │ CUTOFF  │  │         │          │
│  │    ◉    │  │    ◉    │  │    ◉    │  │    ◉    │          │
│  │         │  │         │  │         │  │         │          │
│  │  0.200  │  │  0.100  │  │ 8000 Hz │  │  0.30   │          │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘          │
│                                                                 │
│  SPLICE MANAGEMENT                                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Splice  Name      Start     End     Loop   Actions       │  │
│  │ ─────────────────────────────────────────────────────────│  │
│  │   0 ▓  Intro     0:00.00   0:15.30  [✓]   [Edit][Delete]│  │
│  │   1    Main      0:15.30   1:45.00  [✓]   [Edit][Delete]│  │
│  │   2    Outro     1:45.00   2:30.00  [ ]   [Edit][Delete]│  │
│  │                                        [+ Add Splice]     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  MODULATION & PERFORMANCE                                       │
│  ┌──────────────────────┐  ┌─────────────────────────────┐    │
│  │ LFO 1                │  │ MACRO CONTROLS              │    │
│  │ Rate:  [◉]  Shape: ∿ │  │ Complexity:  [━━━○━━━━]    │    │
│  │ Depth: [◉]  Dest: [▼]│  │ Brightness:  [━━━━━━○━]    │    │
│  │ [✓] Sync to tempo    │  │ Movement:    [━━○━━━━━]    │    │
│  └──────────────────────┘  └─────────────────────────────┘    │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Focus View Features**:
- **Expanded Waveform**: 200px height (vs 120px in multi-view)
- **Larger Knobs**: 80px diameter (vs 60px)
- **All Parameters Visible**: No collapsible panels needed
- **Track Overview**: See all 4 tracks, select active one
- **Splice Management Table**: Full CRUD operations
- **Modulation Section**: LFO and macro controls visible
- **Recording Controls**: Prominent and accessible
- **Quick Switch**: Navigation to other voices via header

**Multi-Track Display in Focus View**:
```
┌────┬────┬────┬────┐
│ 1▓ │ 2  │ 3  │ 4  │  ← Track selector tabs
└────┴────┴────┴────┘

Track 1 (Active):  All parameters shown above
Track 2-4:         Mini preview cards:

┌─────────────────────────────┐
│ Track 2 (Preview)           │
│ Buffer: pad.wav             │
│ Gene Size: 80ms             │
│ Morph: 0.45                 │
│ Pitch: +12 st (Octave up)   │
│ [Switch to Track 2]         │
└─────────────────────────────┘
```

### 2.4 Performance View

**Activation**:
- Keyboard shortcut: `Cmd + Shift + P`
- View menu → "Performance View"
- Toolbar icon: [🎭]

**Layout**: Minimal controls, maximum visual feedback
```
┌────────────────────────────────────────────────────────────────┐
│  [Exit Performance View]                      CPU: 15%  6.2ms  │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│              ┌────────────────────────────────────┐            │
│              │                                    │            │
│              │      WAVEFORM DISPLAY (Huge)      │            │
│              │         Height: 300px              │            │
│              │                                    │            │
│              │      ≈≈▓▓████ ▒ ████▓▓≈≈          │            │
│              │      ≈≈▓▓████ ▒ ████▓▓≈≈          │            │
│              │              ┃                     │            │
│              │         [Grain Cloud]              │            │
│              │                                    │            │
│              └────────────────────────────────────┘            │
│                                                                 │
│  SCENE RECALL (8 Scenes)                                       │
│  ┌────┬────┬────┬────┬────┬────┬────┬────┐                   │
│  │ 1▓ │ 2  │ 3  │ 4  │ 5  │ 6  │ 7  │ 8  │                   │
│  │Intro│Main│Bld │Drp │Brk │Bld2│Drp2│Out │                   │
│  └────┴────┴────┴────┴────┴────┴────┴────┘                   │
│                                                                 │
│  ESSENTIAL CONTROLS (Hidden until hover)                       │
│  Hover bottom edge to reveal:                                  │
│  [Volume: ═══○══] [Morph: ═══○══] [Pitch: ═══○══]            │
│                                                                 │
│  METERING (Prominent)                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │ Voice 1  │  │ Voice 2  │  │ Voice 3  │  │  MASTER  │      │
│  │    ║█    │  │    ║▓    │  │    ║░    │  │    ║█    │      │
│  │    ║█    │  │    ║▓    │  │    ║     │  │    ║█    │      │
│  │   -6dB   │  │  -12dB   │  │  -24dB   │  │   -3dB   │      │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

**Performance View Features**:
- **Scene Recall**: 8 snapshot slots, keyboard 1-8 to trigger
- **Huge Waveform**: Maximum visual feedback
- **Minimal UI**: Controls hidden until needed
- **Focus on Output**: Large meters, visual feedback
- **Quick Tweaks**: Essential parameters accessible via hover
- **Fullscreen Compatible**: Works with macOS fullscreen mode

### 2.5 View Mode Transitions

**Smooth Animations**:
```swift
// Transition duration: 400ms ease-in-out
.animation(.easeInOut(duration: 0.4))

// Waveform scales up
// Parameters rearrange with stagger (50ms delay each)
// Opacity fades: 0 → 1 for new elements
```

**State Preservation**:
- Audio continues uninterrupted during view changes
- All parameter values maintained
- Undo/redo history preserved
- Controller mappings remain active

**View Mode Memory**:
- Last used view mode saved per project
- Per-voice Focus View history (Cmd+[ / Cmd+] to navigate)
- Quick return to Multi-Voice: `Esc` key

### 2.6 View Mode Indicators

**Top Bar Shows Current Mode**:
```
Multi-Voice:  [≡≡] Grainulator - Project Name
Focus View:   [▓] GRANULAR VOICE 1 - Focused
Performance:  [🎭] PERFORMANCE MODE
```

**Quick Switcher** (Cmd + E):
```
┌─────────────────────────────┐
│ Switch View Mode            │
├─────────────────────────────┤
│ › Multi-Voice View          │
│   Focus: Granular Voice 1   │
│   Focus: Granular Voice 2   │
│   Focus: Granular Voice 3   │
│   Focus: Granular Voice 4   │
│   Focus: Plaits Synthesizer │
│   Performance View          │
└─────────────────────────────┘
```

### 2.7 Keyboard Shortcuts for View Modes

```
Cmd + 1-4        Focus on Granular Voice 1-4
Cmd + 5          Focus on Plaits
Cmd + 0          Return to Multi-Voice View
Cmd + F          Cycle through Focus Views
Cmd + Shift + P  Toggle Performance View
Cmd + E          Open View Switcher
Esc              Return to Multi-Voice (from any view)

In Focus View:
Cmd + [          Previous voice
Cmd + ]          Next voice
Tab              Switch between tracks (within granular focus)
```

---

## 3. Color Palette & Typography

### 2.1 Color System

**Base Colors (Dark Theme)**
```
Background Primary:    #1A1A1D (near-black)
Background Secondary:  #252528 (dark gray)
Background Tertiary:   #2F2F33 (medium gray)

Surface:               #3A3A3F (raised elements)
Surface Hover:         #45454A (interactive hover state)
Surface Active:        #505055 (pressed/active state)
```

**Accent Colors**
```
Primary Accent:        #4A9EFF (electric blue) - main actions, playhead
Secondary Accent:      #7B68EE (medium purple) - Plaits, synthesis
Tertiary Accent:       #FF6B6B (coral red) - warnings, clipping

Success:               #51CF66 (green) - recording, enabled states
Warning:               #FFD93D (yellow) - alerts, attention
Error:                 #FF6B6B (red) - errors, clipping
```

**Text Colors**
```
Text Primary:          #FFFFFF (white) - main labels, values
Text Secondary:        #B0B0B8 (light gray) - secondary labels
Text Disabled:         #606068 (medium gray) - disabled elements
Text Accent:           #4A9EFF (blue) - links, interactive text
```

**Granular Voice Colors** (for multi-track identification)
```
Voice 1:               #4A9EFF (electric blue)
Voice 2:               #9B59B6 (purple)
Voice 3:               #E67E22 (orange)
Voice 4:               #1ABC9C (teal)
Plaits:                #7B68EE (medium purple)
```

**Meter & Visualization Colors**
```
Meter Safe:            #51CF66 (green)        -∞ to -12 dB
Meter Caution:         #FFD93D (yellow)       -12 to -3 dB
Meter Danger:          #FF6B6B (red)          -3 dB to 0 dB+
Waveform:              #4A9EFF (40% opacity)
Splice Marker:         Voice-specific color (80% opacity)
Playhead:              #4A9EFF (100% opacity)
Grain Cloud:           #4A9EFF (10% opacity, accumulates)
```

### 2.2 Typography

**Primary Font**: SF Pro (system font on macOS)
- Excellent readability at all sizes
- Native feel on macOS
- Wide range of weights

**Font Sizes**
```
Heading 1:             24pt, Medium
Heading 2:             18pt, Medium
Body:                  13pt, Regular
Small:                 11pt, Regular
Tiny:                  9pt, Regular
Parameter Value:       14pt, Medium (monospace digits)
Parameter Label:       11pt, Regular
```

**Monospace Font**: SF Mono (for numeric values, timecode)
- Used for parameter values that update frequently
- Prevents layout shift when digits change

---

## 4. Main Window Layout

**Note**: This section describes the **Multi-Voice View** layout. See [View Modes](#view-modes) for Focus View and Performance View layouts.

### 4.1 Overall Structure (Multi-Voice View)

```
┌────────────────────────────────────────────────────────────────┐
│  Title Bar: Grainulator - [Project Name]          ●  ●  ●      │
├────────────────────────────────────────────────────────────────┤
│  Toolbar: [File] [Edit] [View] [Controllers] [Help]            │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────┐  ┌──────────────────────────────┐│
│  │   GRANULAR SECTION      │  │   PLAITS SECTION             ││
│  │                         │  │                              ││
│  │  ┌──────────────────┐   │  │  Model: [Wavetable      ▼]  ││
│  │  │  Waveform        │   │  │                              ││
│  │  │  Display         │   │  │  ┌──────┐  ┌──────┐         ││
│  │  │                  │   │  │  │Harm. │  │Morph │         ││
│  │  │  [splice markers]│   │  │  │ ◉    │  │  ◉   │         ││
│  │  │  [playhead]      │   │  │  └──────┘  └──────┘         ││
│  │  └──────────────────┘   │  │                              ││
│  │                         │  │  ┌──────────────────┐        ││
│  │  Track: [1▼] [2][3][4]  │  │  │   Envelope       │        ││
│  │                         │  │  │   Visualization  │        ││
│  │  ┌─────┐ ┌─────┐       │  │  └──────────────────┘        ││
│  │  │Slide│ │Gene │       │  │                              ││
│  │  │ ◉   │ │Size │       │  │  [MIDI Learn Active]         ││
│  │  │     │ │ ◉   │       │  │                              ││
│  │  └─────┘ └─────┘       │  └──────────────────────────────┘│
│  │                         │                                  │
│  │  ┌─────┐ ┌─────┐       │                                  │
│  │  │Morph│ │Vari │       │                                  │
│  │  │ ◉   │ │Speed│       │                                  │
│  │  │     │ │  ◉  │       │                                  │
│  │  └─────┘ └─────┘       │                                  │
│  │                         │                                  │
│  │  [▶ Advanced]           │                                  │
│  └─────────────────────────┘                                  │
│                                                                 │
├────────────────────────────────────────────────────────────────┤
│  EFFECTS CHAIN                                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐   │
│  │ TAPE DELAY   │ │   REVERB     │ │   DISTORTION         │   │
│  │ [On]         │ │ [On]         │ │   [Off]              │   │
│  │              │ │              │ │                      │   │
│  │ Time   [◉]   │ │ Size   [◉]   │ │   Drive      [◉]     │   │
│  │ Feedback [◉] │ │ Decay  [◉]   │ │   Type  [Tube  ▼]    │   │
│  │ Mix    [◉]   │ │ Mix    [◉]   │ │   Mix        [◉]     │   │
│  └──────────────┘ └──────────────┘ └──────────────────────┘   │
├────────────────────────────────────────────────────────────────┤
│  MIXER                                                          │
│  ┌───────┐  ┌───────┐  ┌───────┐  ┌───────┐  ┌────────────┐  │
│  │Voice 1│  │Voice 2│  │Voice 3│  │Voice 4│  │   MASTER   │  │
│  │   ║   │  │   ║   │  │   ║   │  │   ║   │  │     ║      │  │
│  │   ║   │  │   ║   │  │   ║   │  │   ║   │  │     ║      │  │
│  │  ┌─┐  │  │  ┌─┐  │  │  ┌─┐  │  │  ┌─┐  │  │    ┌─┐     │  │
│  │  │█│  │  │  │▓│  │  │  │░│  │  │  │ │  │  │    │█│     │  │
│  │  │█│  │  │  │▓│  │  │  │ │  │  │  │ │  │  │    │█│     │  │
│  │  │█│  │  │  │ │  │  │  │ │  │  │  │ │  │  │    │█│     │  │
│  │  └─┘  │  │  └─┘  │  │  └─┘  │  │  └─┘  │  │    └─┘     │  │
│  │  -6dB  │  │ -12dB │  │ -24dB │  │  -∞   │  │   -3dB     │  │
│  │ [S][M] │  │ [S][M]│  │ [S][M]│  │ [S][M]│  │            │  │
│  └───────┘  └───────┘  └───────┘  └───────┘  └────────────┘  │
├────────────────────────────────────────────────────────────────┤
│  Status Bar: ● Grid Connected  ● Arc Connected  ● MIDI Active  │
│              CPU: 15%   Latency: 6.2ms   48kHz   Buffers: 4/32 │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Window Dimensions

**Multi-Voice View**

**Minimum Window Size**: 1200 × 800 pixels
**Preferred Window Size**: 1400 × 900 pixels
**Maximum Window Size**: Unlimited (scales appropriately)

**Sections**:
- Toolbar: 40px height
- Granular/Plaits Section: 40% of window height (min 300px)
- Effects Chain: 20% of window height (min 150px)
- Mixer: 30% of window height (min 200px)
- Status Bar: 30px height

**Focus View**
- **Minimum Window Size**: 1200 × 900 pixels (taller to accommodate expanded controls)
- **Preferred Window Size**: 1400 × 1100 pixels
- **Sections**:
  - Header: 50px height (includes back button and voice selector)
  - Waveform Display: 200px height (expandable up to 300px)
  - Track Selector: 60px height
  - Core Parameters: 180px height
  - Extended Parameters: 180px height
  - Splice Management: 150px height (collapsible)
  - Modulation Section: 120px height (collapsible)
  - Status Bar: 30px height

**Performance View**
- **Recommended**: Fullscreen or maximized window
- **Minimum**: 1024 × 768 pixels
- **Waveform**: 300px height (or 40% of window)
- **Scene Recall**: 80px height
- **Meters**: 200px height
- **Hidden Controls**: Slide up from bottom on hover (150px)

---

## 5. Component Specifications

### 4.1 Rotary Knob

**Visual Design**
```
     Indicator line
         ╱
    ╭───○───╮
   ╱         ╲
  │     ◉     │  ← Current value indicator (dot)
   ╲         ╱
    ╰───────╯
       ↑
   Value arc (colored)
```

**Specifications**
- Diameter: 60px (primary), 48px (secondary), 36px (compact)
- Rotation range: 270° (135° left to 135° right)
- Center position: 12 o'clock = maximum/default (context-dependent)
- Value arc: Colored segment showing current value
- Indicator line: Thin line from center to edge

**Interaction**
- Click & drag vertically: Coarse adjustment (1px = 1% change)
- Shift + drag: Fine adjustment (1px = 0.1% change)
- Double-click: Reset to default value
- Mouse wheel: Adjust by fixed increments
- Right-click: Context menu (MIDI learn, reset, etc.)

**States**
- Default: Surface color with accent-colored value arc
- Hover: Surface Hover color, value arc brightens
- Active (dragging): Surface Active color, larger value arc
- Disabled: Text Disabled color, desaturated

**Label & Value Display**
```
┌──────┐
│ ◉    │  ← Knob
│      │
└──────┘
  Slide    ← Parameter name (below)
  0.50     ← Current value (below name)
```

### 4.2 Fader (Vertical Slider)

**Visual Design**
```
   ┌─┐
   │ │ ← Mute/Solo buttons
   └─┘

   ║║║  ← Level meter (peak/RMS)
   ║║║
   ║▓║
   ║█║
   ║█║
  ┌┴┬┴┐
  │ │ │ ← Fader thumb
  └┬─┬┘
   │ │
   │ │
   └─┘

  -6dB   ← Current value
```

**Specifications**
- Width: 44px (channel), 60px (master)
- Height: 150px minimum, scales with window
- Thumb: 44px × 20px rounded rectangle
- Track: 8px wide, centered
- Meter: Behind track, 4px × 2 (L/R) or 8px (mono)

**Interaction**
- Click & drag: Move fader
- Click on track: Jump to position
- Shift + drag: Fine adjustment
- Double-click: Reset to 0dB (or default)
- Mouse wheel: Adjust by 1dB increments

**Metering**
- Green: -∞ to -12dB
- Yellow: -12 to -3dB
- Red: -3dB to 0dB
- Clip indicator: Red dot above meter (persists 2 seconds)

### 4.3 Waveform Display

**Visual Design**
```
┌────────────────────────────────────────────────────────┐
│ Buffer: drone.wav (2:30 / 2:30)              [Export] │
├────────────────────────────────────────────────────────┤
│                       ┃                                │
│  ≈≈≈≈▓▓▓▓▓▓▓▓▓▓████ ▒ ████▓▓▓▓▓▓▓▓▓▓▓▓≈≈≈≈            │
│  ≈≈≈▓▓▓▓▓▓▓▓▓▓▓████ ▒ ████▓▓▓▓▓▓▓▓▓▓▓▓≈≈≈             │
│  ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔ ╂ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔            │
│  Splice 1: Intro    ┃ Splice 2: Main                  │
│  └─────────────────┐┃┌───────────────────────────────┘│
│                     ┃                                  │
│                  Playhead                              │
└────────────────────────────────────────────────────────┘
  ◀─────────── Time ───────────▶
  Grain cloud visualization (overlaid, translucent)
```

**Specifications**
- Height: 120px (primary), 80px (compact)
- Waveform rendering: Peak/RMS envelope
- Splice markers: Colored rectangles with labels
- Playhead: Vertical line (2px, accent color)
- Grain cloud: Translucent sprites showing active grains
- Zoom: Horizontal scroll + pinch/scroll to zoom

**Interaction**
- Click: Jump playhead (set Slide position)
- Drag: Scrub through audio
- Right-click: Add splice at position
- Shift + drag: Select region
- Hover: Show timecode at mouse position

**Splice Markers**
- Color-coded per splice
- Draggable edges to adjust boundaries
- Click label to rename
- Right-click for splice menu

### 4.4 Button Styles

**Primary Button** (main actions)
```
┌─────────────────┐
│   Load Sample   │  ← Primary Accent background
└─────────────────┘    White text, 13pt Medium
     Hover: Lighter, scale(1.02)
     Active: Darker, scale(0.98)
```

**Secondary Button** (less important actions)
```
┌─────────────────┐
│     Export      │  ← Surface background, accent border
└─────────────────┘    Text Accent, 13pt Regular
```

**Icon Button** (toolbar, toggle)
```
┌───┐
│ ▶ │  ← Surface background, icon in Text Primary
└───┘    24×24px
```

**Toggle Button** (on/off state)
```
 On:  ┌───┐
      │ M │  ← Accent background, white text
      └───┘

 Off: ┌───┐
      │ M │  ← Surface background, Text Secondary
      └───┘
```

### 4.5 Dropdown Menu

```
┌──────────────────────┐
│  Wavetable      ▼    │  ← Selected item
└──────────────────────┘

    (on click)

┌──────────────────────┐
│ ✓ Wavetable          │  ← Currently selected
│   Phase Distortion   │
│   FM                 │
│   Grain Formant      │
│   ...                │
└──────────────────────┘
```

**Specifications**
- Height: 32px
- Font: 13pt Regular
- Selected item indicated with checkmark
- Hover: Background Hover
- Max height: 300px, scroll if needed

### 4.6 Track Selector

```
┌──────────────────────────────┐
│ Track: [1▼] [2] [3] [4]      │
│        ▔▔▔▔  ─   ─   ─       │
└──────────────────────────────┘
         ↑
    Active track (underline + accent color)
    Inactive tracks (no underline, secondary text)
```

**Interaction**
- Click number: Switch to that track
- All parameters update to show selected track
- Visual feedback on Grid/Arc
- Color-coded per track

### 4.7 Advanced Parameters Panel

**Collapsed State**
```
┌─────────────────────────────┐
│  [▶ Advanced Parameters]     │
└─────────────────────────────┘
```

**Expanded State**
```
┌─────────────────────────────┐
│  [▼ Advanced Parameters]     │
├─────────────────────────────┤
│  ┌──────┐  ┌──────┐         │
│  │Spread│  │Jitter│         │
│  │  ◉   │  │  ◉   │         │
│  └──────┘  └──────┘         │
│                              │
│  ┌──────┐  ┌──────┐         │
│  │Filter│  │ Res  │         │
│  │  ◉   │  │  ◉   │         │
│  └──────┘  └──────┘         │
│                              │
│  Quantization: [Octaves+5th▼]│
└─────────────────────────────┘
```

---

## 6. Interaction Patterns

### 6.1 Parameter Adjustment

**Mouse Interactions**
1. **Hover**: Parameter highlights, shows tooltip with current value
2. **Click & Drag**: Vertical drag adjusts value (up = increase)
3. **Shift + Drag**: Fine adjustment (10× slower)
4. **Double-Click**: Reset to default value
5. **Right-Click**: Context menu
   - MIDI Learn
   - Reset to Default
   - Copy Value
   - Paste Value
   - Edit Manually (text input)

**Keyboard Shortcuts** (when parameter focused)
- **Arrow Up/Down**: Increment/decrement by small amount
- **Shift + Arrow**: Increment/decrement by large amount
- **Home**: Minimum value
- **End**: Maximum value
- **Delete/Backspace**: Reset to default

### 6.2 MIDI Learn Workflow

1. **Activate MIDI Learn**
   - Right-click parameter → "MIDI Learn"
   - Or click "MIDI Learn" button in toolbar
   - Parameter highlights in accent color
   - Status bar shows: "MIDI Learn Active: Waiting for input..."

2. **Move MIDI Controller**
   - User moves knob/fader on MIDI controller
   - CC message received
   - Parameter displays: "Mapped to CC #14"

3. **Confirmation**
   - Parameter returns to normal state
   - Mapping saved
   - MIDI icon appears next to parameter name

4. **Cancel**
   - Press Escape
   - Click anywhere else
   - Right-click → "Cancel MIDI Learn"

### 6.3 File Operations

**Load Audio File**
```
1. Click "Load Sample" button or Cmd+O
2. File picker appears (filtered to audio files)
3. User selects file
4. Progress indicator shown during load
5. Waveform display updates
6. File name shown in header
7. Notification: "Loaded: filename.wav"
```

**Save Project**
```
1. Cmd+S or File → Save
2. If new project: Save dialog appears
3. Project saved (JSON format)
4. Status bar: "Project saved successfully"
5. Window title updates to show saved state
```

### 6.4 Preset Management

**Load Preset**
```
[Preset: ──────────────▼]
  ↓ (click)
┌────────────────────────────┐
│ 📁 Textures                │
│   • Shimmer Pad            │
│   • Granular Wash          │
│ 📁 Rhythmic                │
│   • Stuttering Glitch      │
│   • Gate Sequence          │
│ 📁 User                    │
│   • My Favorite (★)        │
└────────────────────────────┘
```

**Save Preset**
```
1. Click "Save Preset" button
2. Dialog appears:
   ┌─────────────────────────┐
   │ Save Voice Preset       │
   ├─────────────────────────┤
   │ Name: [____________]    │
   │ Category: [Textures ▼]  │
   │ Tags: [ambient, pad]    │
   │                         │
   │ Include buffer: [✓]     │
   │                         │
   │     [Cancel]  [Save]    │
   └─────────────────────────┘
```

### 6.5 Grid/Arc Visual Feedback

**Grid Button Press**
```
1. User presses Grid button
2. Application receives OSC message
3. Parameter updates (e.g., Slide position jumps)
4. LED brightness updates to reflect new state
5. UI on screen updates simultaneously
6. Round-trip latency target: <50ms
```

**Arc Encoder Rotation**
```
1. User rotates Arc encoder
2. Delta value received (e.g., +5)
3. Parameter increments smoothly
4. LED ring updates to show new position
5. On-screen knob animates to match
6. Smooth interpolation (no jumps)
```

---

## 7. Visual Feedback

### 6.1 Real-Time Indicators

**Playhead Animation**
- Smooth scrolling through waveform
- Updates at 60fps
- Position synchronized to audio sample accuracy
- Slight glow effect for visibility

**Grain Cloud Visualization**
- Translucent sprites for each active grain
- Positioned based on grain read position
- Opacity based on grain amplitude
- Fade in/out with grain envelope
- Limited to 32 visible grains max (for performance)

**Metering**
- Peak hold: 2-second decay
- RMS: Smooth ballistics (300ms integration time)
- Clip indicator: Persists 2 seconds, requires manual reset
- Update rate: 60fps (interpolated from audio thread data)

### 6.2 State Indicators

**Recording State**
```
Not Recording:  ⚫ [Record]
Armed:          ⦿ [Record]  (pulsing)
Recording:      🔴 [Stop]   (solid red, pulsing indicator)
```

**Playback State**
```
Stopped:        ▶ [Play]
Playing:        ⏸ [Pause]
Paused:         ▶ [Resume]  (half-brightness)
```

**Buffer Load State**
```
Empty:          [Load Sample]
Loading:        [●●●○○○]  (animated spinner)
Loaded:         ✓ drone.wav [✕] (filename, close button)
Error:          ⚠ Failed to load
```

### 6.3 Hover States & Tooltips

**Tooltip Appearance**
- Delay: 500ms after hover
- Position: Below element (or above if near bottom)
- Content: Parameter name + current value + units
- Background: Surface color, slight transparency
- Border: 1px accent color

**Example Tooltip**
```
┌─────────────────┐
│ Gene Size       │
│ 120 ms          │
│ (Shift: fine)   │
└─────────────────┘
```

### 6.4 Animation Timing

**Transitions**
- Default: 150ms ease-out
- Quick: 100ms ease-out (small state changes)
- Smooth: 250ms ease-in-out (large movements)
- Slow: 400ms ease-in-out (panel expansions)

**Examples**
```swift
// Button hover
.animation(.easeOut(duration: 0.1))

// Knob value change
.animation(.easeOut(duration: 0.15))

// Panel expand/collapse
.animation(.easeInOut(duration: 0.25))

// Waveform zoom
.animation(.easeInOut(duration: 0.4))
```

---

## 8. Accessibility

### 8.1 Keyboard Navigation

**Tab Order**
1. Toolbar buttons
2. Granular track selector
3. Granular primary parameters (Slide, Gene Size, Morph, Varispeed)
4. Granular advanced parameters (if expanded)
5. Plaits model selector
6. Plaits parameters
7. Effects controls (left to right)
8. Mixer faders (left to right)
9. Master fader

**Focus Indicators**
- 2px accent-colored outline
- No impact on layout (use outline, not border)
- Clearly visible against all backgrounds

### 8.2 Screen Reader Support

**Parameter Announcements**
```
"Slide, 0.5, slider, value 50 percent"
"Gene Size, 120 milliseconds, rotary control"
"Recording, button, not pressed"
```

**VoiceOver Navigation**
- All controls labeled with accessibility identifiers
- Value changes announced immediately
- State changes announced ("Recording started")
- Waveform described as "audio waveform visualization, 2 minutes 30 seconds"

### 8.3 Color Accessibility

**Contrast Ratios**
- Text on background: Minimum 4.5:1 (WCAG AA)
- Large text: Minimum 3:1
- Interactive elements: Minimum 3:1

**Color Blindness Considerations**
- Don't rely solely on color to convey information
- Use icons, labels, and patterns in addition to color
- Meters use position + color
- Splice markers have patterns in addition to colors

### 8.4 Reduced Motion

**Respects System Preference**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

if reduceMotion {
    // Instant transitions instead of animations
    // Static playhead instead of smooth scrolling
    // Disable grain cloud animation
}
```

---

## 9. Responsive Design

### 9.1 Breakpoints

**Large (1400px+ width)**
- Full layout as specified
- All parameters visible
- Generous spacing

**Medium (1200-1399px width)**
- Maintain layout
- Slightly reduce spacing
- Compact some labels

**Small (1024-1199px width)**
- Stack Granular and Plaits vertically
- Reduce waveform height to 80px
- Smaller knobs (48px)
- Effects in 2-column grid instead of 3-column

**Minimum (1024px width)**
- Minimum supported size
- Scroll if window smaller
- Warning message if too small

### 9.2 Scalable Elements

**Vector Graphics**
- All icons as SF Symbols (system) or SVG
- Waveform renders at native resolution
- Meters scale smoothly

**Text**
- Never smaller than 11pt
- Scale up proportionally with window
- Maintain readability at all sizes

### 9.3 Layout Flexibility

**Resizable Panels**
```
User can drag dividers between:
- Granular/Plaits section ↔ Effects
- Effects ↔ Mixer
- Minimum/maximum constraints enforced
- Ratios saved with project
```

---

## 10. Additional UI Elements

### 10.1 Context Menus

**Parameter Context Menu**
```
┌────────────────────────┐
│ MIDI Learn         ⌘L  │
│ ────────────────────── │
│ Reset to Default   ⌘⌫  │
│ Copy Value         ⌘C  │
│ Paste Value        ⌘V  │
│ ────────────────────── │
│ Enter Value...         │
│ Automate (future)      │
└────────────────────────┘
```

**Waveform Context Menu**
```
┌────────────────────────┐
│ Add Splice Here        │
│ ────────────────────── │
│ Zoom In            ⌘+  │
│ Zoom Out           ⌘-  │
│ Zoom to Fit        ⌘0  │
│ ────────────────────── │
│ Export Buffer...       │
└────────────────────────┘
```

### 10.2 Modal Dialogs

**Confirmation Dialog**
```
┌─────────────────────────────────┐
│  ⚠️ Unsaved Changes              │
├─────────────────────────────────┤
│  Your project has unsaved        │
│  changes. Do you want to save    │
│  before closing?                 │
│                                  │
│  [Don't Save]  [Cancel]  [Save] │
└─────────────────────────────────┘
```

**Error Dialog**
```
┌─────────────────────────────────┐
│  ⛔ Error Loading Audio File     │
├─────────────────────────────────┤
│  The file "sample.wav" could not │
│  be loaded. The file may be      │
│  corrupted or in an unsupported  │
│  format.                         │
│                                  │
│  Supported formats: WAV, AIFF,   │
│  FLAC, MP3, M4A                  │
│                                  │
│                      [OK]        │
└─────────────────────────────────┘
```

### 10.3 Preferences Window

```
┌─────────────────────────────────────────┐
│  Grainulator Preferences                 │
├──────────┬──────────────────────────────┤
│          │                              │
│ General  │  Audio Device                │
│ Audio    │    Output: [Built-in ▼]     │
│ MIDI     │    Input:  [Built-in ▼]     │
│ Grid/Arc │                              │
│ Advanced │  Sample Rate: [48000 ▼]     │
│          │  Buffer Size: [128    ▼]    │
│          │                              │
│          │  [✓] Safety Limiter          │
│          │  [✓] Auto-save projects      │
│          │                              │
└──────────┴──────────────────────────────┘
```

---

## 11. Dark Mode Support

### 10.1 Color Adjustments

**Dark Mode** (default, as specified above)
- Background: #1A1A1D
- Text: White/light gray
- Reduced eye strain for long sessions

**Light Mode** (optional, future consideration)
- Background: #F5F5F7
- Text: Dark gray/black
- Inverted meter colors
- Accent colors adjusted for contrast

### 10.2 System Integration

```swift
// Respect system appearance
@Environment(\.colorScheme) var colorScheme

if colorScheme == .dark {
    // Use dark theme colors
} else {
    // Use light theme colors
}
```

---

## Document Information
- **Version**: 1.0
- **Date**: 2026-02-01
- **Design Tool**: Mockups described in ASCII/text
- **Related Documents**:
  - music-app-specification.md
  - architecture.md
  - api-specification.md
