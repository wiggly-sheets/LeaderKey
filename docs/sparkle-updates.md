# Sparkle Updates

This document applies to the independent
[Wiggly Sheets fork](https://github.com/wiggly-sheets/LeaderKey). The fork is not affiliated with or
endorsed by the upstream Leader Key project.

Updates are disabled in this fork. Nothing contacts an appcast server.

## Current state

- `FeatureFlags.sparkleUpdates` is false in `Leader Key/Constants.swift`.
- `AppDelegate` creates no updater while disabled.
- `MainMenu.swift` has no Check for Updates item.
- `StatusItem` adds no Check for Updates item when no handler exists.
- `Info.plist` has no `SUFeedURL` or `SUPublicEDKey`.

The Sparkle package stays linked, and the delegate code stays in place. Keep it that way until the fork has its own release feed.

## Re-enable with your own appcast

1. Publish an appcast and a public EdDSA key for this fork.
2. Add both keys to `Leader Key/Support/Info.plist`:

   ```xml
   <key>SUFeedURL</key>
   <string>https://example.com/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>YOUR_PUBLIC_KEY</string>
   ```

3. Set `FeatureFlags.sparkleUpdates = true` in `Leader Key/Constants.swift`.
4. Add a Check for Updates item to `Leader Key/MainMenu.swift` if you want it in the app menu. Target the AppDelegate and call `updaterController?.checkForUpdates(nil)`.
5. Build a signed, notarized release. Sparkle update checks need a stable signing identity.
6. Test one upgrade from the previous version before publishing the feed.

Do not reuse the original appcast or keys. They are not controlled by this fork.
