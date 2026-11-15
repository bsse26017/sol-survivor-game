# Game Design Document — *Sol Survivor* (working title)

> **Challenge:** NASA Space Apps Challenge 2026 — *Build a Junior Astronaut Mission Trainer*
> **Event dates:** 14–15 November 2026 (48 hours)
> **Team:** 4 people (all new to game dev)
> **Engine / platform:** Unity → WebGL (hosted on itch.io), with a Windows build as backup
> **Version:** v1.0 — 7 Nov 2026

---

## 1. One-line pitch

A storm leaves a young astronaut alone on Mars. Walk around your outpost in first person, fix what breaks, and make hard choices about **life support, power, food and radiation shielding** to stay alive until your crew can come back for you.

## 2. How we answer the challenge brief

| What the brief asks | How our game does it |
|---|---|
| Interactive game or app | First-person 3D web game |
| Students run a lunar or Martian outpost | The player runs a small Mars outpost alone |
| Balance life support, radiation shielding, power, food production | These are the **4 meters** on screen. Every event trades one against another |
| Experience the decisions that make a mission succeed or fail | Real win/fail outcomes, plus a **Mission Debrief** that explains *why* |
| Not too simple, not too complex | Short text, icons, 3 choices per event, real consequences |
| Subject tag "Sun" | A solar storm event built on a **real NASA solar flare** |
| Use NASA data | Real Curiosity weather and radiation data, a real flare, and the real 2018 dust storm (see §9) |

## 3. Target audience

- **Ages 7–12** (school students)
- Plays in a browser with mouse and keyboard
- Very little reading: icons, short sentences, big buttons
- A session lasts about **10–15 minutes**

## 4. Design pillars

1. **Fix things to survive.** Every problem is a machine to repair or a choice to make.
2. **Every choice has a cost.** There is never a perfect answer, only trade-offs (just like real missions).
3. **Lonely but beautiful.** Calm pastel Mars, never scary.
4. **Real science, kid-sized.** Real NASA data, explained simply.

## 5. Story

### Setup
During a spacewalk, a huge dust storm hits. The crew has to launch to their ship in orbit to stay safe, but they can't find you in the dust. They leave, sad and hoping you're OK.

You wake up half-buried in sand, alone. The outpost is damaged and the radio dish is broken. **Your crew is still in orbit.** If you can fix the dish and survive, they can come back down for you.

### Characters
- **The Astronaut (player):** a fixed hero. We never show their face or say their gender, so the player decides who they are. Their personality comes through short, funny thoughts ("Note to self: Mars is cold. Very cold.").
- **The crew (Commander voice):** heard only at the end, when the dish works.

### Story beats (6 sols)
| Sol | Beat |
|---|---|
| Intro | Wake up outside with low air. Walk to the hab. (Tutorial: move, look, interact.) |
| 1 | Get the power back on. |
| 2 | Survive the first freezing night. |
| 3 | First good news: the greenhouse makes food! |
| 4 | Water problems: drink it or grow food? |
| 5 | The Sun throws a solar storm at Mars. Take shelter! |
| 6 (finale) | Fix the dish before a dust storm hits. Call the crew. |
| Ending | "We hear you! We're coming down!" The lander arrives. Mission Debrief. |

## 6. Gameplay

### 6.1 Core loop (one sol)

1. **Morning:** an objective appears ("Fix the heater").
2. **Repair task:** walk to the object, look at it, **hold E** for 3 seconds. The meter changes.
3. **Event card:** the game pauses and a card pops up with **3 choices**. Each choice shows its effects as icons.
4. **Go to bed:** click the bed. The screen fades to black.
5. **Night summary:** the meters update, and a "Did you know?" fact with real NASA data appears.
6. Next sol begins.

### 6.2 The 4 meters (0–100)

| Icon | Meter | What it means | Main drain |
|---|---|---|---|
| 🫁 | **Life Support** | Air, water, warmth | −8 every night |
| ⚡ | **Power** | Electricity from solar panels and the battery | Heating, machines, storms |
| 🥔 | **Food** | Stored food + greenhouse | −8 every night (+5 if the greenhouse is working) |
| 🛡️ | **Shield** | Radiation protection of the shelter | Damaged by solar storms |

**Starting values:** Life 60 · Power 40 · Food 50 · Shield 40

**Night rules (kept simple on purpose):**
- Life Support −8, Food −8
- Power +15 if the panels are clean, otherwise +5
- Greenhouse working → Food +5 (it needs Power above 10)

*All numbers are first guesses. We balance them during playtesting.*

### 6.3 Win and fail

- **Win:** finish Sol 6 with the dish fixed and every meter above 0.
- **Fail (gentle):** any meter hits 0. Instead of dying, the game ends with a **Mission Aborted** screen and the **Mission Debrief** explains what went wrong. The player can **retry from the start of the previous sol**, which undoes the earlier choice that caused the failure.
- **Mission Debrief (both endings):** shows each choice the player made and one short real-world lesson for it.
  *Example: "You heated the whole hab, so Power ran out. Real Mars bases must share energy between heat, air and food!"*

### 6.4 Controls

| Action | Key |
|---|---|
| Move | W A S D |
| Look | Mouse |
| Interact / repair | Hold **E** |
| Choose on cards | Mouse click |
| Pause | Esc |

A "Click to start" screen is needed (browsers only lock the mouse after a click).

## 7. Sols and events

Events come from the team's event list (PDF, 25 events). For the jam version we use **6**. Each card pauses the game.

### Sol 1 — Power On
- **Task:** flip the main power switch in the hab (hold E).
- **Event: Dusty Solar Panels** (PDF #6). *"The storm covered your solar panels in dust!"*
  | Choice | Effect |
  |---|---|
  | 🧹 Clean them yourself outside | ⚡ +20 · 🫁 −10 (uses suit air) |
  | 🔧 Rig a dust blower from spare parts | ⚡ +10 |
  | 😴 Live with less power | ⚡ −10 |

### Sol 2 — The Cold Night
- **Task:** fix the heater.
- **Event: Extreme Cold** (PDF #5). *"Tonight it will be −78°C!"* (real Curiosity temperature)
  | Choice | Effect |
  |---|---|
  | 🔥 Heat the whole hab | ⚡ −20 · 🫁 +10 |
  | 🛏️ Heat only the bedroom | ⚡ −10 · 🥔 −10 (greenhouse gets cold) |
  | 🧥 Wear extra layers, no heat | 🫁 −15 |

### Sol 3 — First Harvest!
- **Task:** reboot the oxygen tanks (3 tanks, hold E on each).
- **Event: Greenhouse Harvest** (PDF #23). *"Your first potatoes are ready!"*
  | Choice | Effect |
  |---|---|
  | 🍽️ Eat them all now | 🥔 +25 |
  | 🌱 Save some as seeds | 🥔 +10 now, then +5 every night after |
  | ⏳ Let them keep growing | 🥔 +0 now, +35 on Sol 5 |

### Sol 4 — Water Trouble
- **Task:** patch the crack in the greenhouse dome.
- **Event: Water Shortage for Crops** (PDF #12). *"There isn't enough water for you AND the plants."*
  | Choice | Effect |
  |---|---|
  | 💧 Water the plants | 🥔 +15 · 🫁 −15 |
  | 🌿 Grow fewer plants | 🥔 +5 · 🫁 −5 |
  | 🚰 Save drinking water | 🫁 +5 · 🥔 −10 |

### Sol 5 — Solar Storm
- **Task:** repair the shelter wall (🛡️ +20 when done).
- **Event: Solar Storm Warning** (PDF #1–3 combined). *"The Sun just blasted out energy! It reaches Mars soon."* (based on a **real flare** from NASA DONKI)
  | Choice | Effect |
  |---|---|
  | 🛡️ Hide in the shelter | ⚡ −10 · 🥔 −5 (lost work time) · safe |
  | 🔌 Shut down machines, stay in the hab | ⚡ +10 · 🫁 −10 if 🛡️ ≥ 50, otherwise −20 |
  | 🔧 Keep working on the dish outside | 🫁 −25 · 🛡️ −10 · Sol 6 dish repair starts half done |

### Sol 6 — Call Home (finale)
- **Task:** fix the comms dish (3 parts: antenna, cable, power box).
- **Event: Dust Storm Approaching + Comms** (PDF #4 + #15). *"A dust storm is coming. Send your message before it hits!"*
  | Choice | Effect |
  |---|---|
  | 📡 Send the message now on low power | ⚡ −20 |
  | 🧹 Clean the panels first, then send | 🫁 −10 · ⚡ +10 |
  | 🏠 Wait out the storm inside | 🥔 −15 · 🫁 −10 |
- If all meters stay above 0, the crew answers and the **ending** plays.

### Future events (not in the jam version)
Water leak, power failure, air filter problem, habitat damage, rover breakdown, research discovery, water ice discovery, equipment overheating, communication delay, medical supplies, supply shipment delay, fatigue.

## 8. Level and world

One map: **the outpost** (based on our low-poly base render) plus the area around it.

| Object in render | Use in game |
|---|---|
| Round hab | Living module: bed, heater, main power switch |
| Box modules | Workshop and **radiation shelter** |
| Geodesic dome | **Greenhouse** |
| 3 glowing tanks | **Oxygen/water tanks** (Sol 3 task) |
| Solar panel field | **Power** (dust appears on panels) |
| Dishes | **Comms dish** (broken until Sol 6) |
| Crates | Decoration / spare parts |
| Crash spot (new) | Intro start position, a short walk from the hab |

- Interiors can be **one simple room** per module, or no interiors at all (walk up to a door and interact). We decide based on time.
- Invisible walls keep the player near the base.

## 9. Real NASA data

**Rule:** download the data before the event and store it inside the game (JSON or ScriptableObjects). **No live web requests**, because they break easily in WebGL.

| Data | Source | Used for |
|---|---|---|
| Day/night temperatures at Gale Crater | Curiosity rover REMS weather station (NASA PDS) | Each sol's temperature (Sol 2 cold night) |
| Surface radiation dose | Curiosity RAD instrument (NASA PDS) | Shield / radiation facts |
| Real solar flare | NASA DONKI space weather database | Sol 5 solar storm |
| 2018 global dust storm | NASA Mars Exploration news (Opportunity rover) | Sol 6 storm and the "Did you know?" fact |
| General Mars facts | NASA Mars Exploration pages | "Did you know?" cards |

Every data point shown in-game includes a small source line, e.g. *"Data: NASA Curiosity rover."* Sources are also listed in the credits and on the project page.

**Data table format (one row per sol):**
`sol, earth_date_used, temp_min_c, temp_max_c, radiation_note, event_id, fact_text, source`

## 10. Art direction

- **Style:** low-poly, flat-shaded, soft and calm (reference: *Mars: Mars* and our base render).
- **Palette:**
  | Use | Colour |
  |---|---|
  | Daytime ground/sky | Peach `#F4A988`, rust `#C1502E` |
  | Dusk | Lavender `#9C88B8` |
  | Night | Deep blue `#2B3A67` |
  | Machine lights / UI glow | Teal `#4FD1C5` |
  | Warning | Amber `#F5A623` |
- **Lighting:** 3 presets (day, night, storm). Swap between them instead of building a real-time day cycle.
- **UI:** big rounded buttons, icons for every meter and effect, one readable font.

## 11. UI screens

1. **Title:** game name, "Click to start", credits button
2. **HUD:** 4 meters with icons (top-left), sol counter (top-centre), current objective (top-right), "Hold E" prompt (centre)
3. **Event card:** title, 2 short lines, 3 big choice buttons showing effect icons
4. **Night summary:** meter changes plus a "Did you know?" fact with its source
5. **Mission Debrief:** win/fail message, list of choices with lessons, Retry / Play again
6. **Credits:** team, NASA data sources, asset credits

## 12. Audio

- Calm ambient music loop (free, credited)
- Wind outside, quieter wind inside
- Repair sound, button click, warning beep, radio static for the finale
- Sources: free libraries with clear licences (e.g. Kenney, Freesound with CC0). Credit everything.

## 13. Technical plan (Unity)

- **Unity version:** everyone installs **the same LTS version** (decide on day 1, then never change it).
- **Template:** Universal 3D (URP).
- **Player:** Unity **Starter Assets – First Person** (free).
- **Version control:** GitHub with Unity's `.gitignore`. **Only one person edits the main scene.** Everyone else works in their own test scenes or prefabs.

**Scripts:**
| Script | Job |
|---|---|
| `GameManager` | Runs the sol loop: morning → task → card → bed → night → next sol |
| `MeterSystem` | Holds the 4 values, clamps them to 0–100, checks for fail |
| `Interactable` | "Hold E" with a progress circle, raises an event when complete |
| `RepairTask` | Links an Interactable to a meter change and the objective |
| `EventCardData` (ScriptableObject) | Title, text, 3 choices with their meter changes |
| `SolData` (ScriptableObject) | Sol number, task, event, real-data fields |
| `EventCardUI` | Shows a card, pauses the game (`Time.timeScale = 0`), unlocks the cursor |
| `NightSummaryUI` / `DebriefUI` | End-of-sol and end-of-game screens |
| `LightingSwitcher` | Day / night / storm presets |

**WebGL checklist:**
- Build to WebGL on **day 1** and upload to itch.io.
- If itch shows a decompression error: in Player Settings, switch compression to **Gzip** or enable **Decompression Fallback**.
- Keep textures small and avoid heavy post-processing.
- Test in Chrome *and* one other browser.

## 14. Scope

| Priority | Features |
|---|---|
| **Must have** | Walk + look, hold-E repairs, 4 meters, 6 sols with event cards, win/fail, Mission Debrief, real data in at least 2 places, WebGL build |
| **Should have** | Night summary with "Did you know?", lighting presets, sounds, intro wake-up scene |
| **Could have** | Interiors, astronaut thoughts, crew voice at the end |
| **Won't have (jam)** | Rover, exploration, crafting, long story, saving/loading |

## 15. Risks

| Risk | What we do |
|---|---|
| WebGL build breaks late | Build and upload from day 1, every few hours |
| Git merge conflicts on scenes | One scene owner; prefabs for everything else |
| Too much to build | Follow the scope table; feature freeze at hour 36 |
| Numbers feel unfair | Playtest with someone outside the team, then tweak values in the ScriptableObjects |
| Team exhaustion | Sleep in shifts |

## 16. Open decisions

- [ ] Final game title
- [ ] Unity LTS version
- [ ] Interiors or exterior-only?
- [ ] Which real solar flare (date) to use for Sol 5
- [ ] Confirm Space Apps rules on assets made before the event (e.g. our base model) and on free asset packs
