# Mobile-first redesign of Scavenger Hunt Party

## Intent

Rebuild the experience of the four core flows (creating a hunt, creating and
joining teams, submitting items, presenting results) around the phone in a
hunter's hand, without changing what the app does. Every existing route,
model, broadcast and background behaviour stays; views, styles and the small
Stimulus controllers that drive them are redone.

## Who it is for

- A hunter: phone in hand, outdoors, often in sunlight, in a hurry, sometimes a
  kid. Their job is "find the item, snap it, see it tick off".
- An organizer: picks a list, shares a code, and later presents the photos on a
  laptop or TV.

## Goals

- Submitting a photo or video is one tap from the list, shows progress
  immediately, and never leaves the hunter wondering whether it worked.
- Primary actions sit in thumb reach (sticky bottom bars with safe-area insets).
- Pages load fast on a phone: no third-party CDN scripts or styles, one web
  font, native date pickers.
- Readable in daylight: light surfaces, high-contrast ink, one strong action
  colour. Phones set to dark mode get a dark variant of the same theme.
- The presenter view is a proper stage for photos on a big screen.

## Non-goals

- No new features, routes, or schema changes.
- No change to scoring, voting, locking, timers, broadcasts or archives.

## Anti-goals

- A generic "SaaS card kit" look. Lists are lists, not stacks of identical
  cards.
- Garish seasonal palettes. The month-based theme switch stays, but each
  season is a variant of the same system (see Visual system).

## Visual system

- Device: the Polaroid. Found items, results and the presenter render photos
  as captioned instant prints. This is the one place the design is loud.
- Colour: paper white base (#FFFFFF / #F3F4F1 / #E4E6E1), ink #1B1F24, one
  action colour, one highlight colour reserved for score and "found"
  celebration, one green for success. Three seasonal variants share this
  structure and are picked by month in `ApplicationHelper#daisy_theme`:
  - party (default): cobalt #2452E0 actions, marigold #FFB703 highlights.
  - halloween (October): violet #6D28D9 actions, pumpkin #F0691F highlights.
  - autumn (November, December): cranberry #B42332 actions, gold #D9A419
    highlights, spruce #2E7D4F for found items.
  Brand utilities (`text-ink`, `bg-marigold`, `text-field`) resolve through
  theme variables, so views never name a season.
  Each season has a dark variant applied under `prefers-color-scheme: dark`
  (`html[data-theme=...]` overrides in the stylesheet): same action and
  highlight hues lifted for a dark ground. Instant prints always stay white
  with dark ink, and the presenter stage is dark in both modes.
- Type: Bricolage Grotesque only, weight contrast (800 display, 600 UI, 400
  body). No all-caps labels.
- Layout: left-aligned, 20px gutters, max-width 42rem for flows, full-bleed for
  the presenter. Bottom bars for primary actions on mobile.

## Decisions made for the builder

- Date and time fields are native `datetime-local` inputs on phones and a
  flatpickr calendar on desktop, where Safari's native control is weak.
  flatpickr makes that switch itself; its CSS is bundled, not loaded from a CDN.
- Replace ionicons and animate.css with inline SVG icons and CSS keyframes.
- Vote menu becomes two explicit buttons instead of a dropdown.
- Rejoin list on the join page is a list of links, not a select.
- Specs are updated for new labels; behaviour under test is unchanged.
