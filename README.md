# Mímir v4

A portable bash setup script for new GAIN WordPress projects. Handles WordPress core installation, Erebus parent theme setup, child theme scaffolding, and git initialisation — all via WP-CLI.

---

## Prerequisites

Ensure the following are available in your environment before running the script:

| Tool | Install | Notes |
|------|---------|-------|
| [WP-CLI](https://wp-cli.org) | `brew install wp-cli` | `wp --info` should return without error |
| Git | `brew install git` | |
| PHP 8.2+ | via Valet or Homebrew | |
| MySQL / MariaDB | via Valet or Docker | Server must be running before `mimir` is invoked |
| MySQL client | `brew install mysql-client` | Required by WP-CLI for database operations — see note below |

> **MySQL client note:** WP-CLI's database commands require the `mysql` binary to be available in your PATH, even when MySQL is already running via Valet or Docker. Install the client tools with `brew install mysql-client`. Homebrew installs this as keg-only (not auto-linked), but the script handles that automatically.

---

## Installation

Install `mimir` as a global command once, then use it for every new project:

```bash
curl -fsSL https://raw.githubusercontent.com/thisisgain/Mimir/main/install.sh | bash
```

This downloads `setup.sh` to `/usr/local/bin/mimir` and prompts for your password (sudo required to write there). You only need to do this once per machine.

### Updating

To pull in the latest changes to Mimir:

```bash
mimir update-cli
```

This re-downloads `setup.sh` from GitHub and reinstalls it — equivalent to running the curl command above again.

---

## Usage

From an **empty directory** that will become your project root:

```bash
mkdir my-project && cd my-project
mimir
```

### Local development (without global install)

If you have the repo cloned locally, you can symlink the script instead of installing a static copy — any changes you make to the repo are reflected immediately:

```bash
sudo ln -sf /path/to/Mimir/setup.sh /usr/local/bin/mimir
```

---

## What the script does

The interactive wizard walks through the following steps in order:

1. **Requirements check** — verifies WP-CLI, Git, and PHP are available
2. **Database configuration** — DB name, user, password, and host
3. **Site configuration** — URL, title, admin credentials
4. **WordPress core** — downloads core (`en_GB`), generates `wp-config.php`, creates the database, runs the install
5. **Theme setup** — clones Erebus as the parent theme, scaffolds a child theme with the correct `Template:` header
6. **Deploy workflow** — copies `deploy.yml` from the Mimir repo into `.github/workflows/`
7. **Git initialisation** — writes a `.gitignore`, makes the initial commit on `main`, optionally sets a remote and pushes
8. *(Placeholder)* Plugin installation
9. *(Placeholder)* Optional WP settings configuration
10. *(Placeholder)* Front-end build dependency installation

---

## After setup

Navigate into the Erebus parent theme directory and follow its README to install and run the front-end build:

```bash
cd wp-content/themes/erebus
# follow Erebus README
```

---

## wp-config.php

`wp-config.php` is intentionally excluded from version control. It should be created per-environment:

- **Local** — generated automatically by this script
- **WP Engine** — added via the WP Engine custom config panel or directly on the server

---

## TODO

The following are planned additions. Each has a placeholder stub in `setup.sh` marked with a `TODO` comment.

- [ ] **Child theme scaffold** — `setup_themes()` generates placeholder `style.css`, `functions.php`, and `index.php` files. These need updating once the Erebus child theme approach is finalised (asset enqueuing, namespace setup, any required config files).

- [ ] **Plugin installation** — `setup_plugins()` is a stub. Implement a default plugin set installed and activated via `wp plugin install <slug> --activate`. Consider either a hardcoded list or a `plugins.json` config file for flexibility.

- [ ] **Settings configuration** — `setup_config()` is a stub. Implement optional WordPress settings (permalink structure, timezone, default post/comment settings, etc.) using `wp option update`.

- [ ] **Build dependencies** — `setup_build()` is a stub. Once the Erebus build tooling is confirmed, implement `yarn install` (and an optional initial build run) in both the parent and child theme directories.

---

## Troubleshooting

**`env: mysql: No such file or directory`**
WP-CLI needs the `mysql` binary even when MySQL is already running. Install the client tools:
```bash
brew install mysql-client
```
The script adds `/opt/homebrew/opt/mysql-client/bin` to PATH automatically, so no further config is needed.

---

**`Error: Database connection error (2002) No such file or directory`**
PHP is trying to connect via a Unix socket but can't find it. Use `127.0.0.1` instead of `localhost` as the DB host — this forces a TCP connection which works reliably with both Valet and Docker.

---

**`Error: WordPress files seem to already be present here`**
The script is resumable — re-run `mimir` from the same directory and it will skip any steps that already completed (WP download, config, DB creation, theme setup) and continue from where it left off.

---

**Deprecation notices in WP-CLI output**
The script filters PHP deprecation and notice lines from WP-CLI output automatically. If you still see them, ensure you are running the latest version of the script (`mimir --help` shows the version).

---

## Contributing

Branch from `main`, open a PR, and tag the GAIN dev team for review.
