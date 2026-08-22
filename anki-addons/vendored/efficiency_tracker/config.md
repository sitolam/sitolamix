# Efficiency Tracker — configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `theme` | string | `"auto"` | Visual theme of the dashboard. One of `"auto"` (follow system), `"dark"`, or `"light"`. You can also cycle this from the dashboard's "Theme" button. |
| `good_threshold` | number | `70` | Efficiency percentage at which the indicator turns **green**. |
| `warn_threshold` | number | `45` | Below this percentage the indicator is **red**. Between this and `good_threshold` it is **amber**. |
| `range_days` | number | `30` | How many days the dashboard shows. One of `7`, `30`, `90`, or `365`. Also changeable from the dashboard's range dropdown. |
| `notify_every_30min` | boolean | `true` | While a live session is running, show a check-in tooltip every 30 minutes with current efficiency. Set to `false` to silence. |
| `show_toolbar_button` | boolean | `true` | Show an "Efficiency" link in Anki's top toolbar (next to Stats). Restart Anki after changing. |

After changing the threshold values, reopen the statistics window to see the
new colours.
