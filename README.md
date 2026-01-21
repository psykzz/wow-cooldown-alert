# wow-cooldown-alert

A World of Warcraft addon that shows remaining time on failed spell or item casts.

## Features

- Displays cooldown alerts for spells and items
- Compatible with multiple WoW versions (Classic, TBC, Wrath, Retail)

## Installation

Install via CurseForge, Wago, or manually by downloading the latest release from GitHub.

## Development

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