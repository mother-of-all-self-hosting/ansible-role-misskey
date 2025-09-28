<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Misskey

This is an [Ansible](https://www.ansible.com/) role which installs [Misskey](https://misskey.com/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Misskey is a free and open-source collaborative wiki and documentation software, designed for seamless real-time collaboration. It can be used to manage a wiki, a knowledge base, project documentation, etc. It has various functions such as granular permissions management system, page history to track changes of articles, etc. It also supports diagramming tools like Draw.io, Excalidraw and Mermaid.

See the project's [documentation](https://misskey.com/docs/) to learn what Misskey does and why it might be useful to you.

## Prerequisites

To run a Misskey instance it is necessary to prepare a [Postgres](https://www.postgresql.org/) database server and [Redis](https://redis.io/) server for managing a metadata database.

If you are looking for Ansible roles for them, you can check out [ansible-role-postgres](https://github.com/mother-of-all-self-hosting/ansible-role-postgres) and [ansible-role-redis](https://github.com/mother-of-all-self-hosting/ansible-role-redis), both of which are maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team. The roles for [KeyDB](https://keydb.dev/) ([ansible-role-keydb](https://github.com/mother-of-all-self-hosting/ansible-role-keydb)) and [Valkey](https://valkey.io/) ([ansible-role-valkey](https://github.com/mother-of-all-self-hosting/ansible-role-valkey)) are available as well.

## Adjusting the playbook configuration

To enable Misskey with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# misskey                                                              #
#                                                                      #
########################################################################

misskey_enabled: true

########################################################################
#                                                                      #
# /misskey                                                             #
#                                                                      #
########################################################################
```

### Set the hostname

To enable the Misskey instance you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
misskey_hostname: "example.com"
```

>[!WARNING]
> Once the instance has started, changing the value will break the instance!

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting Misskey under a subpath (by configuring the `misskey_path_prefix` variable) does not seem to be possible due to Misskey's technical limitations.

### Set variables for connecting to a Redis server

As described above, it is necessary to set up a [Redis](https://redis.io/) server for managing a metadata database of a Misskey instance. You can use either KeyDB or Valkey alternatively.

Having configured it, you need to add and adjust the following configuration to your `vars.yml` file, so that the Misskey instance will connect to the server:

```yaml
misskey_redis_hostname: YOUR_REDIS_SERVER_HOSTNAME_HERE
misskey_redis_port: 6379
```

Make sure to replace `YOUR_REDIS_SERVER_HOSTNAME_HERE` with the hostname of your Redis server.

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `misskey_config_additional_configurations` variable

See its [configuration parameters](https://github.com/misskey-dev/misskey/blob/master/.config/docker_example.yml) for a complete list of Misskey's config options that you could put in `misskey_config_additional_configurations`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Misskey becomes available at the specified hostname like `https://example.com`.

To get started, open the URL on a web browser and create a first workspace by inputting required information. For an email address, make sure to input your own email address, not the one specified to `misskey_environment_variable_mail_from_address`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu misskey` (or how you/your playbook named the service, e.g. `mash-misskey`).
