# Personal build: input switching

Local additions to MonitorControl (not upstream):

- **Input row in each display's menu card**: buttons for the inputs ticked in Settings → Inputs → "Show in menu"
  (DP and HDMI by default). The current input is read and highlighted when the menu opens. Switches with VCP `0x60`
  (DP1/DP2/HDMI1/HDMI2/USB-C = 15/16/17/18/27).
- **Settings → Inputs** (new tab, built in code because the storyboard needs Xcode), per display:
  - **Hide from arrangement unless on**: set it to the input this Mac is plugged into. While the monitor shows another
    input the display is disabled (private `SLSConfigureDisplayEnabled`), so windows and the cursor stay on the other
    screens. Its menu card then reads "Not in arrangement · on DP" with a **Switch to HDMI 1** button. It also comes
    back when the monitor's own OSD switches back (the input is read every 3 s, only while a display is hidden).

  Hiding is decided on connect, app start and wake (by reading the current input, event driven) and on switches made
  from the menu. A switch made
  with the monitor's OSD while the display is still in the arrangement is not noticed (that would need constant polling).
  Disabled displays are re-enabled when the app quits and on the next launch (after a crash).

## Build

Needs only Command Line Tools and `gh` (to fetch the release DMG once, for its compiled storyboard and assets).

```bash
PersonalBuild/build.sh
```

Output: `PersonalBuild/out/MonitorControl.app` (ad-hoc signed, Sparkle update checks off).

## Install

```bash
pkill -x MonitorControl; rm -rf /Applications/MonitorControl.app && ditto PersonalBuild/out/MonitorControl.app /Applications/MonitorControl.app && open /Applications/MonitorControl.app
```

Start at login: System Settings → General → Login Items → add MonitorControl. After a rebuild, macOS may ask again for
Accessibility (only needed for keyboard brightness/volume keys), because the ad-hoc signature changes.
