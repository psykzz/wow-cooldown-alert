# wow-cooldown-alert

A World of Warcraft addon that shows remaining time on failed spell or item casts.

## Features

- Displays cooldown alerts for spells and items
- Compatible with multiple WoW versions (Classic, TBC, Wrath, Retail)

## Project Structure

The addon is split into small, single-purpose modules, loaded in this order (see `CooldownAlert.toc`):

- `Libs/PsyUtils/` - reusable helpers shared across PsyKzz's addons.
- `Core/` - constants, client-capability detection, API compat wrappers, bag cache, and settings persistence.
- `UI/` - the on-screen cooldown text/icon display.
- `Core/Bootstrap.lua` / `Core/EventHandler.lua` - wires everything together; loaded last since it depends on Core and UI.

Open **Options > AddOns > Cooldown Alert** to change the font size (12-48, default 28). Moving the slider saves and applies the size immediately and shows a four-second countdown preview at the alert position. No Save button is needed.

## Installation

Install via CurseForge, Wago, or manually by downloading the latest release from GitHub.

## Development

Run the settings tests with `python -m pip install -r requirements-test.txt` and `python -m unittest discover -s tests`.

### Creating a Release

This addon uses BigWigs Packager for automated releases. To create a new release:

1. Update the version in your local repository
2. Create and push a git tag:
   ```bash
   git tag -a v1.2.0 -m "Release version 1.2.0"
   git push origin v1.2.0
   ```
3. The GitHub Actions workflow will automatically:
   - Package the addon
   - Create a GitHub release
   - Upload to CurseForge (if `CF_API_KEY` secret is configured)
   - Upload to Wago (if `WAGO_API_TOKEN` secret is configured)

### Required Secrets

To enable automatic uploads, configure these repository secrets:

- `CF_API_KEY` - CurseForge API key for uploading to CurseForge
- `WAGO_API_TOKEN` - Wago API token for uploading to Wago Addons

The `GITHUB_TOKEN` is automatically provided by GitHub Actions.

## License

All Rights Reserved