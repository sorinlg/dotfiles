# Sync app preferences

Rectangle, Clipy and MonitorControl keep settings in macOS `defaults`. After changing one in its UI, capture it into your fork:

```sh
mise run config:diff -- --app rectangle       # review drift, changes nothing
mise run config:app:pull -- --app rectangle   # app -> repo (diffed and confirmed)
mise run config:app:push -- --app rectangle   # repo -> app, restarts it
```

Use `clipy` or `monitorcontrol` in place of `rectangle` for the others. To add an app, add one entry to `_APP_DEFAULTS_REGISTRY` in `lib/utils-app-defaults`; no other file changes.

After the first install, grant Accessibility permission to Rectangle, Clipy and MonitorControl in System Settings > Privacy & Security. macOS requires this to be done by hand. Clipy may also ask for Input Monitoring.
