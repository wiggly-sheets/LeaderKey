# Leader Key — Wiggly Sheets fork

This is an independent fork of [Leader Key](https://github.com/mikker/LeaderKey), maintained at
[wiggly-sheets/LeaderKey](https://github.com/wiggly-sheets/LeaderKey).

**This fork is not affiliated with, endorsed by, or supported by Mikkel Malmberg, the upstream
Leader Key project, or Tuna.** Report issues with this fork here, not upstream.

The fork keeps the original leader-key workflow and adds the features listed below. It uses the
bundle identifier `com.wigglysheets.LeaderKey`, has its own local development setup, and does not
contact the original update feed.

## Fork additions

- **Hyper key as ✦** — enable **Settings > General > Show hyper key as ✦** to display every
  Control-Option-Shift-Command shortcut as `✦ + key` in the shortcut recorders. Turn it off to show
  the normal modifier glyphs.
- **Clipboard placeholder in commands** — use `{{clipboard}}` in a command action to insert the
  current text clipboard. Use `\{{clipboard}}` for a literal placeholder. Unknown placeholders are
  left alone. Very large clipboards are rejected with an alert.
- **Named action deep links** — run an action by its exact label:
  `leaderkey://run?name=Reply%20with%20thanks`. Requires **Allow URL scheme automation** in
  Settings > Advanced. Missing or duplicate labels do nothing.
- **Text snippet action** — add an action with `"type": "text"` and `"value": "your text"` to type
  a fixed string into the frontmost app. This needs Accessibility permission. Secure input blocks
  insertion, and sticky mode skips insertion so the window remains open.
- **Cheatsheet search** — press <kbd>⌘F</kbd> while Leader Key is open, or click the magnifier in the
  cheatsheet. Results show their group path, and <kbd>Return</kbd> or a click runs or opens the
  selected item.
- **Fuzzy cheatsheet search** — when an exact match is not enough, results are ranked with fuzzy
  matching. Exact and substring matches stay first, and matched characters in the item name are
  highlighted.
- **Liquid Glass tint** — on macOS 26 and later, choose any tint color with the native color
  picker in Settings > General.
- **Updates disabled** — this fork does not check the original appcast and has no automatic update
  feed yet. See [docs/sparkle-updates.md](docs/sparkle-updates.md).

The original upstream project has its own features, releases, and support channels. This fork does
not speak for it.

## Install from source

This fork has no binary releases or Homebrew formula yet. Build it locally:

```sh
git clone https://github.com/wiggly-sheets/LeaderKey.git
cd LeaderKey
xcodebuild -scheme "Leader Key" -configuration Release -derivedDataPath build build
cp -R "build/Build/Products/Release/Leader Key.app" /Applications/
open "/Applications/Leader Key.app"
```

Requires macOS 14.4 or later and Xcode. Local builds do not use the upstream signing setup.

### Post-install setup

- Open the settings menu from the menu bar icon.
- Choose your leader key. Only modifiers will not work.
- Add shortcuts in the **Config** settings.

Configuration lives at `~/Library/Application Support/Leader Key/config.json` unless you choose
another directory in Settings.

## Tests

```sh
xcodebuild -scheme "Leader Key" -testPlan "TestPlan" test
```

## Why Leader Key?

### Problems with traditional launchers

1. Typing the name of the thing can be slow and give unpredictable results.
2. Global shortcuts have limited combinations.
3. Leader Key offers predictable, nested shortcuts, like combos in a fighting game.

### Example shortcuts

- <kbd>leader</kbd><kbd>o</kbd><kbd>m</kbd> → Launch Messages (`open messages`)
- <kbd>leader</kbd><kbd>m</kbd><kbd>m</kbd> → Mute audio (`media mute`)
- <kbd>leader</kbd><kbd>w</kbd><kbd>m</kbd> → Maximize the current window (`window maximize`)

## Text snippet actions

A text action inserts a fixed string into the app that was frontmost before Leader Key opened.

```json
{
  "key": "s",
  "type": "text",
  "value": "Thanks for the review!",
  "label": "Reply"
}
```

The first 40 characters of `value` are used as the default display name. Newlines and tabs are sent
as Return and Tab. Other control characters are skipped.

Text insertion uses synthetic keyboard input. Grant Accessibility permission when macOS asks.
Insertion is blocked while secure input is active. In sticky mode the action keeps the window open
and does not insert anything.

## URL Scheme

Leader Key supports URL scheme automation for integration with Alfred, Raycast, shell scripts, and
other tools.

### Configuration management

```sh
open "leaderkey://config-reload"
open "leaderkey://config-reveal"
```

### Window control

```sh
open "leaderkey://activate"
open "leaderkey://hide"
open "leaderkey://reset"
```

### Settings and info

```sh
open "leaderkey://settings"
open "leaderkey://about"
```

### Navigation

```sh
# Navigate through keys and execute actions
open "leaderkey://navigate?keys=a,b,c"

# Navigate without executing (preview mode)
open "leaderkey://navigate?keys=a,b,c&execute=false"
```

### Named actions

```sh
# Run the action with this exact label. Requires "Allow URL scheme automation"
# in Settings > Advanced. Duplicate or missing labels do nothing.
open "leaderkey://run?name=Reply%20with%20thanks"
```

Named action lookup only matches action labels, uses exact case-sensitive labels, and ignores
groups. If more than one action has the label, nothing runs.

### Example use cases

- Alfred or Raycast workflows that trigger Leader Key shortcuts.
- Shell scripts that reload configuration after editing `config.json`.
- Keyboard Maestro chains that combine Leader Key with other automations.
- External triggers that open specific action sequences from other apps.

## FAQ

### What do I set as my leader key?

Any key can be your leader key, but only modifiers will not work.

Examples:

- <kbd>F12</kbd>
- <kbd>⌘ + space</kbd>
- <kbd>⌘⌥ + space</kbd>
- <kbd>⌘⌥⌃⇧ + L</kbd> (hyper key)

With **Show hyper key as ✦** enabled, the last example appears as <kbd>✦ + L</kbd> in shortcut
recorders.

Advanced setups can use [Karabiner Elements](https://karabiner-elements.pqrs.org/), for example:

- <kbd>right ⌘ + left ⌘</kbd> at once, bound to <kbd>F12</kbd>.
- <kbd>caps lock</kbd>, bound to hyper when held and <kbd>F12</kbd> when pressed.

### I disabled the menu bar item. How do I get Leader Key back?

Activate Leader Key, then press <kbd>⌘ + ,</kbd>.

### A command action fails with "Command not found"

Make sure your shell environment is set up for non-interactive mode and exports `PATH`.

For zsh, export `PATH` in `~/.zshenv`. For bash, export it in `~/.bash_profile`.

## Upstream and license

Leader Key was created by Mikkel Malmberg. The upstream project is
[mikker/LeaderKey](https://github.com/mikker/LeaderKey). This fork is independent and does not
claim affiliation with or endorsement from the upstream project.

MIT License. Original code Copyright (c) 2024 Mikkel Malmberg. Fork modifications Copyright (c) 2026
Zeb Mikula. See [LICENSE](LICENSE).
