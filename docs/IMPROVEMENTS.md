# Customer-flow Improvements — Punch List

Brief for Claude Code. Each item below is a self-contained ticket: the
"what", the "why", and the file(s) most likely to touch. Pick them up in
any order — none of them depend on each other.

---

## 1. Address search has no live suggestions

**Bug.** Tapping "Add address" opens the search sheet but typing produces
no autocomplete / search-as-you-type results. The user has to type the
whole address and hit save, which is error-prone for landmarks.

**Acceptance**
- Typing in the address search field surfaces a debounced list of
  suggestions (Google Places Autocomplete, Mapbox Geocoding, or Nominatim
  — pick whichever has a free dev tier and add the key to `env/dev.json`).
- Tapping a suggestion fills line 1, landmark/area, and city + pincode in
  one go.
- Empty state shows recent / saved addresses if any.

**Files**
- `lib/features/user/widgets/address_search_sheet.dart`
- `lib/features/user/widgets/address_picker_sheet.dart`
- `lib/core/services/location_service.dart` — add a `searchSuggestions(query)` method.
- `lib/data/repositories/address_repository.dart` — if results should be cached.

---

## 2. Event draft is lost when the app is killed mid-flow

**Bug.** `EventDraftController` keeps the in-progress event in memory
only. Killing or swiping the app away drops the draft, so the customer
re-enters occasion / guests / date / time / tier / venue / property /
add-ons from scratch.

**Acceptance**
- The draft survives a cold start. Reopening the app puts the user back
  on the same step of the flow with all selections intact.
- "Continue planning" card on the home picks up the rehydrated draft.
- A *Discard draft* affordance lives somewhere reasonable
  (long-press on the home card, or a tiny `×` inside it).

**Approach**
- Serialize `EventDraft` to a JSON map (the model is already a plain
  immutable value class — add `toJson` / `fromJson`).
- Persist via `shared_preferences` (already a dependency) under a single
  key like `dawat.event_draft.v1`.
- On `EventDraftController.build()`, read the stored JSON; on every
  mutation, write back. Debounce the write by ~250 ms to avoid hammering
  prefs.

**Files**
- `lib/data/models/event_draft.dart`
- `lib/data/models/private_property.dart` (already has `copyWith`, needs JSON)
- `lib/data/models/chef.dart` (ReccePick needs JSON)
- `lib/shared/providers/event_providers.dart` — hydrate on build, persist
  on every state change.

---

## 3. Customer bottom-nav text is oversized

**Polish.** Post-login, the customer's bottom nav (Home / Events /
Search / Saved / Profile) shows large labels under each icon. The
"Events" label especially feels heavy. The icons read fine on their own.

**Acceptance**
- Remove the text labels from the customer bottom nav and keep only the
  icons (with the cart badge intact on the Cart tab).
- Active tab still indicated by the red filled icon + a subtle dot or
  underline.
- Vertical centering of icons inside the 68 px tab area.

**Files**
- `lib/shared/widgets/user_bottom_nav.dart` — drop the `Text(label)` row
  in `_NavItem`, restyle the active indicator, tighten the column.

---

## 4. Button + icon alignment polish across primary CTAs

**Polish.** Across the plan-your-event flow (Venue / Property / Setup /
Recce) and the home sticky cart bar, the trailing icons inside red CTA
buttons sometimes sit slightly off the baseline of the label.

**Acceptance**
- Every primary CTA renders the label and trailing icon on the same
  optical baseline.
- Icon size is consistent (currently 18 / 20 / 22 are mixed — pick one,
  probably 20).
- The "Continue ›" / "Pick the menu ›" / "Confirm recce ✓" CTAs in
  `PlanFlowFooter` use the same horizontal padding and gap.

**Files**
- `lib/features/user/widgets/plan_flow_chrome.dart` — `PlanFlowFooter`.
- `lib/features/user/screens/event_details_screen.dart` — bottom button.
- `lib/shared/widgets/user_bottom_nav.dart` — `_InlineCartPeek` View-cart
  trailing chevron.

---

## 5. Location requests don't surface the OS permission dialog

**Bug.** `LocationService.currentAddress()` calls `Geolocator.requestPermission()`
but on a fresh install the OS dialog never appears — either the
`AndroidManifest.xml` is missing the runtime permissions, or the call
site isn't running before the first `getCurrentPosition()`.

**Acceptance**
- First time the user taps anything that needs location (Use map on the
  property screen, "current location" on address picker, hero header
  location chip), they see the system permission dialog.
- "Denied forever" path shows an inline banner with a "Open settings"
  link, not a crash.

**Approach**
1. Confirm `android/app/src/main/AndroidManifest.xml` declares both
   `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`.
2. Confirm `ios/Runner/Info.plist` has `NSLocationWhenInUseUsageDescription`.
3. In every call site that touches `LocationService`, await the
   permission *before* hiding any loading spinner so the user sees the
   dialog.

**Files**
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `lib/core/services/location_service.dart`
- Any UI that calls `LocationService.instance.currentAddress()`
  (grep for it).

---

## Out of scope (capture-only)

- The "Use map" affordance on `PrivatePropertyScreen` currently shows a
  *coming soon* snackbar. Wire it to a real map picker when item 5 is
  done.
- Onboarding image URLs are public Unsplash CDN links. If the team wants
  art-direction, swap to in-repo assets and remove `cached_network_image`
  from that screen.
