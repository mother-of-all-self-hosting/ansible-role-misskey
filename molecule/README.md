<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 Slavi Pantaleev

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently there is one testing scenario available.

### `default`

Tests a standard Misskey installation against a Postgres installed by [ansible-role-postgres](https://github.com/mother-of-all-self-hosting/ansible-role-postgres) and a Valkey installed by [ansible-role-valkey](https://github.com/mother-of-all-self-hosting/ansible-role-valkey).

The verification does not stop at "the systemd service is active". It:

- waits for the unit and then for the container itself to exist — the unit creates it with `--rm`, so a Misskey that dies on startup leaves nothing behind, and `docker inspect misskey` would otherwise resolve to the container *network* of the same name and fail much later, far from the cause
- establishes, before it asserts anything about the role, that the stock Misskey image cannot start without the role's rendered configuration, and that a Misskey given everything *except* the bind-mount of `misskey_compiled_config_path` dies with `EACCES` on `/misskey/built/.config.json` — which is what makes that mount attributable rather than assumed
- waits for Misskey's own `/api/meta` rather than settling for the unit being `active`
- asserts the running version four ways: the API, the application's own `package.json`, the image tag, and the value of the image's `org.opencontainers.image.version` label — all against the `misskey_version` leaf that Renovate bumps
- checks that Misskey reports the address `misskey_hostname` gave it, that it answers on a port which is not Misskey's own default, that `templates/env.j2` reached the container's environment, and that `misskey_container_additional_volumes_custom` really is mounted
- checks that the moderation API refuses anonymous callers and forged tokens, and that signing in with the wrong password is refused
- creates the instance administrator through Misskey's own unauthenticated setup path, and then asserts that the same call is refused the second time — the bootstrap window has to close
- posts a note over the API, reads it back, asks for a note id that was never created, and cross-checks the row in Postgres along with the count of migrations Misskey ran there
- finds the note's id on the local timeline **inside Valkey**, in the database and under the key prefix the role configured, while Valkey's own default database 0 stays empty
- watches the service for long enough to catch a crash loop hiding behind `active`

The scenario deliberately runs Misskey on a port, a database name, a Redis key prefix and a Redis database number that are none of them Misskey's defaults, so that a configuration file which never reached the process would show up as a failure rather than as a pass.

Note that a Misskey with no accounts answers `GET /` with 200 all the same, which is why nothing here treats that as evidence.

The scenario's `prepare.yml` installs `fuse-overlayfs` and points the inner Docker at it, instead of the `vfs` storage driver the rest of this fleet uses. The Misskey image is around 4.5 GB across 35 layers, and `vfs` — which copies the whole filesystem for every layer — unpacks it to 41 GB, which no CI runner has. `fuse-overlayfs` needs about 3.3 GB for the same image.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
