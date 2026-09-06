# Squawkr — Omarchy widget ✈️

**Calling every Omarchy tiling-window devotee who also happens to look up.** If you fly — light aircraft,
gliders, drones, or you just love watching the sky — this one's for you.

Squawkr lives in your [Omarchy](https://omarchy.org) / Hyprland status bar and answers, at a
glance, the two questions a pilot actually asks before heading out:
**"what restriction zones exist nearby, and what's the weather at my airfield?"**
No tab-hunting, no detours — just a click on your bar between commits. It's a free,
at-a-glance companion to the full [Squawkr](https://squawkr.net) service which is launching soon!

Click the Squawkr mark in your bar and a compact panel drops down: your **home airfield** (wind,
favoured runway, sky) plus up to a few **tracked** airfields and restriction areas. 

Add and remove what you follow; open any item for a fuller view; jump to the full
service for the rest.

![The Squawkr panel — home airfield plus tracked airfields and restriction areas](assets/panel-home.png)

> [!IMPORTANT]
> **Not an official flight-briefing source.** Squawkr is an at-a-glance convenience, not a substitute
> for a briefing. Always verify restriction-area activation and on-site signage, and weather from official METAR/TAF, before you fly.
>
> **Coverage:** weather and airfield data are worldwide. Live restriction-area **activation status**
> is currently **Sweden only** (the United States follows once its official feed is live). Outside a
> covered territory the widget shows an airspace's **boundary and vertical limits only** 
>
> **Missing weather:** when a field has no current observation it reads **"no report"**, and with no
> forecast, **"No forecast available."** Missing data is always shown as unknown — never as good
> conditions.

---

## What you get

- A **Squawkr mark in the status bar**; click it to toggle the panel.
- A **home airfield** at the top — condition, wind (bearing + strength), favoured runway with
  crosswind, QNH — and up to three **tracked** airfields / restriction areas below.
- **Airfield detail:** a 2-D runway with a wind chevron + sky interpretation — decoded values only;
  the raw METAR/TAF text is left to the full report, so it can't overflow the panel.
- **Restriction-area detail:** a vertical-limits meter + the week's activation schedule where we
  have a status feed (Sweden today), or a plain *zone only* boundary-and-limits view where we don't.
- **Keyboard:** `a` add · `h` set home · `x` remove · `↵` open · `Esc` back.
- A subtle link to the full service for everything the free teaser doesn't cover.

| Airfield detail | Restriction-area detail |
|---|---|
| ![Airfield detail — runway with wind chevron, wind, sky](assets/detail-airfield.png) | ![Restriction-area detail — vertical limits and the week's schedule](assets/detail-area.png) |

## Requirements

- **Omarchy** with the **Quickshell** status bar (Omarchy's default). *(A Waybar
  alternative is in [`extras/waybar/`](extras/waybar).)*
- Network access to the Squawkr plugin API (see [Configuration](#configuration)).

The panel is a **native QML popup** — outside-click, `Esc`, theming, and focus
all come from the shell itself. No browser, no local server.

## Install

```sh
git clone https://github.com/dboy74/squawkr-widget.git
cd squawkr-widget
./install.sh --wire
```

`./install.sh --wire` is **additive and reversible** — it backs up every file it touches, never
clobbers a config, and never modifies anything under `/usr/share/omarchy`. It:

- copies the QML plugin to `~/.config/omarchy/plugins/squawkr`;
- registers the module at the start of the bar's **right** group in `~/.config/omarchy/shell.json`
  (right, not centre, so a laptop's display notch can't hide it) and reloads the shell;
- retires the pre-native chromium stack (launcher, loopback server, float rule) if present.

Run `./install.sh` **without** `--wire` to copy the files and *print* the config step for you
to add by hand instead.

Then click the Squawkr mark in your bar.

**Updating:** `git pull && ./install.sh --wire` — the installer refreshes the installed files, brings
the Hyprland rule block up to date, and closes a running panel so the next click loads the new version.

## Usage

- **Click the bar icon** to open the panel; click again to close it (standard toolbar-panel toggle).
- **Add** with `a` (or the **+** card): one search box covers **both** airfields and restriction
  zones — type an ICAO, a place, or a zone name (e.g. `ESSA`, `Visby`, `R28`) and pick from the
  combined results. **Set a home** field with `h`; **remove** a tracked item with `x`; **open** a
  detail with `↵`; go **back** with `Esc`.
- The **"Full airspace & forecasts →"** link opens the full service in your browser and closes the
  panel.

## Configuration

Everything is driven by [`omarchy-plugin/squawkr/Squawkr.js`](omarchy-plugin/squawkr/Squawkr.js):

| Setting | What it does |
|---|---|
| `API_BASE` | The Squawkr plugin API the widget reads from. Defaults to `https://plugin-api.squawkr.net`. |
| `SERVICE_URL` | The "full service" link target. |
| `SEED_HOME` | The home airfield seeded on first run (default `ESSV`, Visby). |
| `REFRESH_MS` | Live refresh cadence (also refreshes on panel open). |
| `STALE_CUTOFF_MIN` | Past this age, a value shows as **unknown** — never as a current answer. |

State: the widget stores a per-install API token and your tracked list in
`~/.local/share/squawkr-widget/state.json`. First run seeds the home field from the Omarchy
location (the `weather.json` pin when set, else IP detection) — a saved home never moves on
its own, but the panel says so when you are far from it.

## How it works

The bar plugin (`omarchy-plugin/squawkr/`) puts the mark in the Quickshell bar; clicking it
toggles a native popup (`Panel.qml` — outside-click, `Esc`, theming, and focus come from the
shell itself). `Panel.qml` owns data fetching (curl over `Quickshell.Io` `Process`), `Squawkr.js`
holds the pure logic (runway maths, zone week strip, theme-ramp parsing), and the `*View.qml`
files render home, detail, and search. Status colours come from the active Omarchy theme's
`colors.toml`, read live — the panel follows theme switches with no restart.

## Uninstall

```sh
rm -rf ~/.config/omarchy/plugins/squawkr ~/.local/share/squawkr-widget
```

Then remove `{"id":"squawkr.panel"}` from `~/.config/omarchy/shell.json` (or restore the `.bak.*`
file the installer left beside it), and reload the shell.

## The full service

The widget serves the **free, open** airspace and weather data. Restriction-area coverage,
activation schedules, forecasts, and more live at **<https://squawkr.net>**.

---

*Squawkr is a product of RW 03 AB, Visby, Sweden. The Squawkr name and mark are reserved — see
[LICENSE](LICENSE).*
