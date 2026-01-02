<div align="center">
   <img src="docs/icon.png" width="200" />
   <h1>Ghlass</h1>
   <p><strong>Ghlass</strong> (named from GitHub Glass) is a macOS application built with SwiftUI that brings a beautiful "Liquid Glass" design to your GitHub notifications.</p>
</div>

---

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
3.  Create a GitHub Personal Access Token (PAT) with the following scopes:
    *   `notifications` - Required to read and manage your GitHub notifications
    *   `repo` - Required to access issue and pull request details

    **[Click here to create a token with these permissions pre-selected](https://github.com/settings/tokens/new?description=Ghlass%20App&scopes=notifications,repo)**

4.  Enter your GitHub Personal Access Token in the Ghlass settings.

## Building for Release

To build the `.app` bundle and a `.dmg` file for distribution:

1.  Ensure you have the icon source file `icon.png` in the root directory if you want to regenerate the icon (optional, as `AppIcon.icns` is already generated).
2.  Run the build script:
    ```bash
    ./scripts/build_app.sh
    ```
    This will create `Ghlass.app` and `Ghlass.dmg` in the project root directory.

---

<div align="center">
   <h3>✨ Designed and Maintained by Pochi ✨</h3>
   <p><em>This entire project was created with ❤️ + 🤖 by Pochi from TabbyML</em></p>
   <a href="https://app.getpochi.com">
      <img alt="Pochi AI Coding Assistant" width="120" src="https://github.com/TabbyML/pochi/blob/main/packages/vscode/assets/icons/logo128.png?raw=true">
   </a>
   <h4><a href="https://app.getpochi.com">Pochi is an AI agent designed for software development.</a></h4>
   <p>It operates within your favorite IDE, VSCode, using a toolkit of commands to execute complex tasks, from code generation to project-wide refactoring.</p>
</div>