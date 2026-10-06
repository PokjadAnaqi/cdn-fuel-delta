# CDN-Fuel -> DT_fuelsystem bridge

This build keeps cdn-fuel 2.1.9 as the fuel core.

## UI provider

```lua
Config.useDTfuel = true
```

- `true`: CDN-Fuel context menus and input dialogs are rendered by `DT_fuelsystem`.
- `false`: CDN-Fuel uses the normal `ox_lib` menu/input flow.
- If DT_fuelsystem is temporarily unavailable while `Config.useDTfuel = true`, the client adapter falls back to ox_lib when the corresponding `Config.Ox.Menu` / `Config.Ox.Input` option is enabled.
- Progress bars, target, inventory and other CDN-Fuel behavior are unchanged.

The DT bridge also retains the existing ID-card and monthly allowance integration.
