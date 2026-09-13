# Curb Alert

A phone-sized garage sale finder, built as a single self-contained page
(`index.html`, no build step). Open it in a browser, or publish it as a
Claude Artifact where listings are stored server-side and shared between
everyone who opens the page.

Live prototype: https://claude.ai/code/artifact/ceb6a25d-4af7-4cea-bff8-ae698ccb1c47

## The three doors

The welcome screen is the launcher, exactly three ways in:

**Find garage sales** — search, filter, map, route.
- Search reads titles, descriptions, categories *and posted item lists*, so
  "drill" finds the woodshop sale that has a drill press on its list.
- Filters: radius (1–50 mi), day window (today / this weekend / next 7 days /
  a specific date), kind of sale, 20 categories, "has an item list",
  "has something under $X", payment accepted, early-bird policy, and 15
  good-to-know flags (prices marked, free pile, step-free access, bring a
  truck, help loading, bag deals, numbers at open…). Category and payment
  filters are OR; good-to-know flags are AND.
- Sort by nearest, starting soonest, most items, or newly posted. Sales that
  have already ended always sort last and render dimmed.
- Map view is a schematic pin field, labelled as such — pins are relative
  positions, not a street map.
- Route view orders your picked sales nearest-first (greedy nearest
  neighbour from home), with per-leg drive estimates and a warning when you
  would arrive before a sale opens.

**List a garage sale** — six steps, draft auto-saved to `localStorage`.
1. Basics: name, kind of sale, host, address, landmark, address visibility
2. When: any number of days with per-day hours, early-bird and rain policy
3. What: categories and a description
4. Items (optional): name, price, condition, quantity, category, firm-or-offer
5. Details: payment, good-to-know flags, contact preference
6. Review, then publish

**Account** — profile and defaults (name, home ZIP, radius, day window),
saved sales, your own listings (edit / take down), saved searches, alert
preferences, address-privacy and contact defaults, and a device-data reset.

## Data

| Where | What | Lifetime |
| --- | --- | --- |
| Artifact `db`, collection `sales` | every published listing | shared, durable |
| `localStorage` | profile, saved sales, route, saved searches, wizard draft, device key | this browser only |

A sale document:

```js
{
  title, type, host,
  addr: { street, city, state, zip, cross, visibility },  // visibility: always | dayof | cross
  geo: { x, y },              // 0..1 on the schematic field; distance = hypot * 12 mi from home
  days: [{ date: "2026-09-19", start: "07:00", end: "14:00" }],
  early, rain, cats: [], desc,
  items: [{ name, price, cond, qty, cat, firm }],
  pay: [], feat: [], contact, phone,
  ownerKey, createdAt, sample
}
```

A day may carry `offset` (days from today) instead of `date`. Only the seeded
example listings use it, so the demo stays current instead of going stale a
week after it was written. Anything published from the app writes real dates.

Ownership is a random device key in `localStorage`, written onto each listing
as `ownerKey`; the app only offers Edit / Take down on listings whose key
matches. That is a prototype stand-in for accounts, not a security boundary.

## What is stubbed

No sign-in, no messaging, no photo upload, no geocoding (positions are hashed
from the address onto the schematic field), and notification toggles record a
preference without a push backend. Everything else in the three flows works.

## Running it

Open `index.html` directly, or serve the directory:

```sh
npx http-server curb-alert -p 8080
```

Outside a Claude Artifact viewer the shared store is unavailable, so the page
falls back to the built-in example listings and says so on the welcome screen.
