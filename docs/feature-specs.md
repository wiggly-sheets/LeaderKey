# Feature Specs

Status: draft. Target: dev fork of Leader Key. Keep each implementation small and reversible.

Global constraints:

- Deployment target stays macOS 14.4; glass-only APIs require availability guards.
- Config remains JSON in `config.json`; new fields must be optional and backward compatible.
- Do not add dependencies unless a spec states the need.
- Tests use the existing `Leader KeyTests` target and TestPlan.
- New UI follows current Settings and cheatsheet patterns.

---

## 1. Text Snippet Action

**Goal:** let one leader key type a fixed string into the frontmost app.

**Config**

```json
{ "key": "s", "type": "text", "value": "Thanks for the review!", "label": "Reply" }
```

- New `Type.text` case.
- `value` holds the text to insert. Empty value is valid but does nothing.
- `label` and `iconPath` work like other actions.
- Default display name is the first 40 characters of `value`, single line.

**Behavior**

1. Hide the Leader Key window using the existing hide flow.
2. Wait about 150 ms for focus to return to the previous app.
3. Insert the text as synthetic keyboard input.
4. If the action is triggered in sticky mode, keep the window open and skip insertion; log nothing to the user.

**Implementation**

- Add a small `TextInserter` helper using `CGEvent.keyboardSetUnicodeString`.
- Send UTF-16 chunks of at most 20 units. Keep surrogate pairs inside one chunk.
- Map `\n` to Return key down/up and `\t` to Tab key down/up. Do not send other control characters.
- Check accessibility before posting. If not trusted, call `AXIsProcessTrustedWithOptions` with prompt enabled once, then show one alert that explains the permission requirement.
- Abort with a short alert when `IsSecureEventInputEnabled()` is true.
- Do not use the clipboard, and do not restore the clipboard afterward. That avoids clobbering user data but rules out paste-based insertion.
- Add an editor icon: `text.cursor`.

**Edge cases**

- Unicode, emoji, and combining marks must arrive in order.
- Very long values are allowed; the inserter must not build one huge event.
- Terminal and editors may interpret newlines as commands. Document this in the action type description. Do not add a confirmation prompt.

**Acceptance**

- Config round-trips through save and load.
- Missing accessibility permission produces one actionable alert, not repeated alerts.
- Secure input blocks insertion.
- Text arrives correctly in TextEdit, Safari, and a terminal.
- No main-thread hang while inserting.

**Effort:** M. **Risk:** medium, due to accessibility permission and synthetic input.

---

## 2. Clipboard Placeholder for Command Actions

**Goal:** use the current clipboard inside a command without shell quoting bugs.

**Syntax**

- `{{clipboard}}` in a `command` action value is replaced before launch.
- `\{{clipboard}}` becomes the literal text `{{clipboard}}`.
- Unknown placeholders stay untouched.

**Behavior**

- Read `NSPasteboard.general.string(forType: .string)` once per command run.
- Missing or non-string clipboard becomes an empty string.
- Substitute each unescaped occurrence with a single shell-quoted word.
- Quote rules: wrap in single quotes. Replace each internal `'` with `'\''`.
- Refuse to run and show one alert when clipboard text exceeds 1 MiB. State the size limit in the alert.
- Strip NUL characters. Preserve newlines, tabs, backticks, `$`, and other shell syntax inside the quoted word.

Example:

```json
{ "key": "g", "type": "command", "value": "open 'https://www.google.com/search?q={{clipboard}}'" }
```

The substituted clipboard value is one shell word. It is not re-parsed.

**Implementation**

- Add `CommandRunner.prepare(command:clipboard:) -> String?` as a pure function. Return nil when the size limit is exceeded.
- Keep command execution behavior unchanged.
- Move the clipboard read into `CommandRunner.run` so callers do not change.

**Tests**

- Empty clipboard.
- Text with spaces, single quotes, double quotes, backticks, `$HOME`, newlines.
- Multiple occurrences.
- Escaped placeholder.
- Over-limit input returns nil.
- Commands without placeholders are unchanged.

**Acceptance**

- All tests pass.
- A command like `printf '%s' {{clipboard}}` prints clipboard text exactly, including quotes and newlines.
- No clipboard write occurs.

**Effort:** S. **Risk:** low.

---

## 3. Named Action Deep Link

**Goal:** trigger an action by stable name instead of key path.

**URL**

```text
leaderkey://run?name=Reply%20with%20thanks
```

- Host: `run`. Required query item: `name`.
- `name` is URL-decoded once and trimmed.
- Requires the `Allow URL scheme automation` setting. Without it, the request is ignored.

**Resolution**

1. Search all groups depth-first for actions whose `label` equals `name` exactly.
2. If exactly one match, run that action through the existing action runner.
3. If no match or more than one match, do nothing. Log the result with `os_log` under a `LeaderKey.URLScheme` category. Do not show an alert, so scripts do not produce dialogs.
4. Groups are not valid targets in this version. Only `.action` items run.

**Non-goals**

- No fuzzy matching.
- No label changes in the config editor.
- No unauthenticated trigger path. The automation toggle is the gate.

**Implementation**

- Add `URLSchemeAction.run(name: String)`.
- Parse `leaderkey://run` in `URLSchemeHandler`.
- Add `UserConfig.firstAction(label:)` and a duplicate check. Keep traversal read-only.
- Reuse `Controller.runAction` by adding a narrow internal method. Do not duplicate action execution logic.
- Document the scheme in `README.md` with the automation toggle requirement.

**Tests**

- Parse valid, encoded, missing, and empty names.
- Resolve unique label.
- Reject duplicate labels.
- Reject missing labels.
- Ignore when automation is disabled. Test the gate at the AppDelegate decision seam, not through UI.

**Acceptance**

- Unique label runs the same action as its key path.
- Duplicate label executes nothing.
- Existing `navigate` behavior is unchanged when automation is enabled.

**Effort:** S. **Risk:** low.

---

## 4. Cheatsheet Search

**Goal:** find an action in large configs without navigating groups.

**Activation**

- Press Command-F while Leader Key is active. The cheatsheet opens if needed and focus moves to a search field.
- A magnifier button in the cheatsheet header does the same.
- Escape clears the query. Escape on an empty query closes search. The next Escape hides Leader Key as today.
- Search text is temporary; never written to config or defaults.

**Matching**

- Case-insensitive and diacritic-insensitive.
- Match against action key, label, display name, value, and group labels.
- Empty query shows the normal cheatsheet.
- Results are depth-first in config order. Cap at 100 rows.

**Presentation**

- Each result shows the key glyph, icon, display name, and a breadcrumb path such as `o › s`.
- Actions run on Return or click.
- Groups navigate into the group on Return or click. Search clears after navigation.
- If a result list is empty, show `No matches`.

**Implementation**

- Add a pure `CheatsheetSearch.results(in:query:)` function returning rows with item and path. Unit test it.
- Add `@State` query and focus state to `Cheatsheet.CheatsheetView`.
- Controller detects Command-F and posts a notification, matching the existing `lkExpandAll` pattern. Do not intercept normal leader keys globally.
- Use `.searchable` only if it behaves inside the non-activating panel. Otherwise use a plain `TextField` with `.focused`.
- Do not change cheatsheet sizing rules beyond the header height.

**Non-goals**

- No fuzzy ranking, recents, or persistent search.
- No search across disabled or hidden items, because no such concept exists.
- No config editing from search results.

**Tests**

- Empty query returns normal order.
- Case and accent folding.
- Group label match includes descendants.
- Duplicate labels appear once per item.
- Depth-first order and 100-row cap.

**Acceptance**

- Command-F opens search in an active session.
- Typing filters, Return runs the highlighted action, Escape behaves as specified.
- Search works when the cheatsheet was auto-opened and when opened with `?`.
- No regression in normal cheatsheet expansion and positioning.

**Effort:** M. **Risk:** low to medium, due to focus handling in a non-activating panel.

---

## 5. Liquid Glass Tint

**Goal:** let users tint Liquid Glass backgrounds without a full color picker.

**Setting**

- New `Defaults.Keys.glassTint` of type `GlassTint`, default `.none`.
- `GlassTint` cases: `none`, `blue`, `purple`, `green`, `pink`, `orange`. Raw string values.
- Only visible in Settings when Background is `Liquid Glass` or `Liquid Glass Clear` and macOS 26+ is available.

**Rendering**

- In `ThemeBackground`, pass a `Color?` to `Glass.tint(_:)`.
- `.none` passes nil.
- Classic Blur ignores the setting completely.
- Tint applies to both glass styles. No opacity control in this version; the system controls glass intensity.

**UI**

- Add a Tint picker below the Background picker in `GeneralPane`.
- Hide the picker for Classic Blur.
- Use plain names, no custom color well.

**Tests**

- Enum raw values and default.
- `GlassTint.color` mapping returns nil only for `.none`.
- Existing background style tests keep passing.

**Acceptance**

- Tint changes apply live while a theme window is visible.
- Setting persists across launches.
- macOS 14 and 15 builds compile and fall back to Classic Blur with no tint UI.

**Effort:** S. **Risk:** low.

---

## 6. Fuzzy Cheatsheet Search

**Goal:** rank likely actions when the query is not an exact substring. Builds on spec 4 and replaces its "no fuzzy ranking" non-goal after that spec ships.

**Scope**

- Applies only to cheatsheet search. Named deep links stay exact.
- No new dependency and no search index file.
- One shared matcher used by search and by tests.

**Normalization**

- Trim the query. Collapse whitespace.
- Fold case and diacritics for matching. Keep original text for display.
- Split the query on spaces. Each token must match one field. Different tokens may match different fields.
- One-character queries use prefix and substring matches only. Do not fuzzy-match every row.

**Matcher**

`FuzzyMatcher.score(_ candidate: String, query: String) -> (score: Int, ranges: [Range<Int>])?`

Return nil when the query is not a subsequence of the candidate.

Scoring, highest wins:

- Exact full match: +100.
- Substring match: +50.
- Consecutive matched characters: +10 each.
- Match at start or after a separator: +8.
- Penalty for each skipped character between matches: -1, capped at -20 per gap.
- Prefix match: +20.

Tie-break by config order, depth-first. Keep the order stable across runs.

**Fields and weights**

Match each field separately. Multiply each field's best score by its weight, then add the weighted scores:

- label: 1.0
- key: 0.8
- display name: 0.6
- value: 0.4
- group path: 0.3

A group label match includes its descendants once. Never emit the same action twice.

**Results**

- Show the top 50 matches above score 0.
- Drop results below 25% of the best score, so weak noise does not fill the list.
- Show the normal exact and substring results first. Fuzzy results follow.
- Highlight matched character ranges with `AttributedString`. Do not use color alone.
- Show the same key glyph, icon, breadcrumb, and Return behavior as spec 4.

**Implementation**

- Add a pure `FuzzyMatcher` with no AppKit or SwiftUI imports.
- Extend `CheatsheetSearch.results(in:query:)` to call exact matching first, then fuzzy scoring.
- Precompute normalized strings only within one search call. Do not cache across config edits.
- Keep the existing 100-row cap as a hard limit; the fuzzy top 50 sits inside it.
- Use the existing search field and debounce typing by 100 ms.

**Tests**

- Subsequence hit: `ghb` matches `GitHub`.
- Non-subsequence miss returns nil.
- Exact beats substring, substring beats subsequence.
- Consecutive and word-boundary matches outrank scattered matches.
- Case and diacritic folding.
- Multi-token query across label and group path.
- One-character query does not produce fuzzy noise.
- Duplicate labels appear once.
- Stable order for equal scores.
- Empty query behaves like spec 4.
- 10,000 actions search under 50 ms on the test machine.

**Non-goals**

- No typo correction or edit-distance matching in v1.
- No learning from past selections.
- No fuzzy matching for `leaderkey://run?name=`.
- No persistent index or background work.

**Acceptance**

- Typing `ghb` finds GitHub in the cheatsheet.
- Exact matches remain at the top.
- Search stays responsive with a large config.
- Spec 4 behavior is unchanged when fuzzy matching is disabled or the query is empty.

**Effort:** M. **Risk:** low to medium, mostly ranking quality and keeping results stable.

---

## Suggested Order

1. Clipboard placeholder.
2. Glass tint.
3. Named deep link.
4. Text snippet.
5. Cheatsheet search.
6. Fuzzy cheatsheet search.

Reason: first three are small and low risk. Text snippet adds a permission boundary. Cheatsheet search touches the most UI. Fuzzy ranking depends on that search existing and having stable result ordering.
