---
name: nexus-ui
description: Rebuild and style the Nexus Flutter client UI. Use when changing screens, theme, shell layout, connect button, or visual design.
---

# Nexus UI Skill

## Product
Nexus — cross-platform proxy client (sing-box). Desktop sidebar + mobile tabs.
Screens: Dashboard · Nodes · Import · Logs · Settings.

## Visual direction (locked)
**Graphite tide** — deep graphite atmosphere with a single sea-teal accent.
Not purple, not cream/terracotta, not newspaper, not neon glow stacks.

### Tokens
```
--bg-deep:      #0B1014
--bg-mid:       #121A21
--surface:      #18232C
--line:         rgba(232,240,245,0.10)
--text:         #E8F0F5
--text-dim:     rgba(232,240,245,0.55)
--text-faint:   rgba(232,240,245,0.34)
--accent:       #2DD4BF          /* sea teal */
--accent-deep:  #0F766E
--ok:           #3DDC97
--warn:         #E8B84A
--danger:       #F07178
--font-display: Syne
--font-body:    IBM Plex Sans
```

### Atmosphere
- Scaffold: vertical gradient `#0B1014 → #121A21` plus a soft teal radial wash (top-right), not flat fill.
- Prefer borders/opacity over heavy multi-layer shadows.
- Cards only for interaction (node row, setting row, import result). No decorative card chrome in hero.

### Composition rules
1. Dashboard first viewport = one composition: brand **NEXUS**, status, one connect control, short meta. No stat strips in the hero.
2. Brand must remain readable if nav is removed.
3. One job per section; one headline + one short line.
4. Motion (2–3): connect scale/pulse, page fade+slide, route-mode selection underline.
5. Desktop width > 720 → sidebar; else bottom nav.
6. Light theme allowed but keep same accent language (graphite surfaces lighten, not cream).

## Implementation map
- `lib/theme/nexus_theme.dart` — ThemeData + tokens
- `lib/widgets/` — shell chrome, connect control, surfaces
- `lib/screens/` — all five screens restyled; keep Provider wiring intact

## Do not
- Inter / Roboto / Arial / system-only stacks as primary
- Purple–indigo AI gradients, glow soup, emoji as UI icons
- Inset hero media cards / floating badge overlays on hero
- Rebuild providers/core logic unless UI requires a tiny glue change
