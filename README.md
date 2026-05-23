# Caffeine

Keep your screen awake and prevent idle sleep with a single click on your DankBar.

<img src="screenshot.png" width="300" alt="Screenshot">

## Install

Install this plugin via the plugin manager:

```bash
dms plugins install caffeine
```

Or manually:

```bash
git clone https://github.com/hthienloc/dms-caffeine ~/.config/DankMaterialShell/plugins/Caffeine
```

## Features

- **One-click Stay Awake**: Click the coffee icon pill to toggle sleep inhibition.
- **Universal Wayland/X11 Support**: Powered by `systemd-inhibit` for native compatibility across window managers (Niri, Sway, Hyprland, etc.).
- **Startup Auto-Sync**: Automatically detects if sleep inhibition is active when shell starts.
- **Status Toasts**: Provides clean notification toasts when toggling screen state.

## Usage

| Action | Result |
|--------|--------|
| Left click | Toggle screen stay-awake / sleep inhibition |

## License

GPL-3.0
