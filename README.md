# Ghlass

<img src="docs/icon.png" width="128" align="right" />

**Ghlass** (named from GitHub Glass) is a macOS application built with SwiftUI that brings a beautiful "Liquid Glass" design to your GitHub notifications.

## Features

*   **Liquid Glass Design**: A modern, transparent aesthetic using SwiftUI materials.
*   **GitHub Integration**: Securely sign in with your GitHub Personal Access Token.
*   **Notification Management**: View, filter, and manage your notifications.
    *   Filter by Repository, Type (Issue, PR, etc.), and Unread status.
    *   Batch select and mark notifications as done.
*   **Optimized Performance**: Local filtering ensures a smooth experience without constant re-fetching.

## Getting Started

1.  Clone the repository.
2.  Run with Swift Package Manager:
    ```bash
    swift run
    ```
3.  Enter your GitHub Personal Access Token (PAT) with `notifications` scope in the settings.

## Building for Release

To build the `.app` bundle and a `.dmg` file for distribution:

1.  Ensure you have the icon source file `icon.png` in the root directory if you want to regenerate the icon (optional, as `AppIcon.icns` is already generated).
2.  Run the build script:
    ```bash
    ./scripts/build_app.sh
    ```
    This will create `Ghlass.app` and `Ghlass.dmg` in the project root directory.

## Credits

This project was created by [Pochi](https://getpochi.com). The user did not write even one line of code.