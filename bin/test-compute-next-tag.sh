#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Misskey 2026.6.0 which has already seen
# two releases of it (v2026.6.0-0 and v2026.6.0-1), plus the `v2026-0` tag this
# repository really carries from the era when the version was read out of
# Renovate's commit subjects - Misskey publishes a floating `2026` tag next to
# the real ones, and the autotagger of the day took it for a version. It must
# not be counted as a release of anything.
#
# The defaults file deliberately carries the traps this role's real one has: the
# Renovate annotation that must keep pointing at the same leaf, a commented-out
# example of the version variable, and an image tag derived from it. Neither of
# the latter two may be picked up as the version.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# misskey_version: 9999.9.9
		# renovate: datasource=docker depName=misskey/misskey versioning=semver
		misskey_version: 2026.6.0
		misskey_container_image_tag: "{{ misskey_version }}"
	YAML
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v2026-0 v2026.6.0-0 v2026.6.0-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^misskey_version: 2026.6.0|misskey_version: 2026.7.0|' defaults/main.yml"
revert_version="sed -i 's|^misskey_version: 2026.7.0|misskey_version: 2026.6.0|' defaults/main.yml"
bump_patch="sed -i 's|^misskey_version: 2026.6.0|misskey_version: 2026.6.1|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v2026.7.0-0 "$(merge "$bump_version")"
expect 'task edit'    v2026.7.0-1 "$(merge "$edit_task")"
expect 'template'     v2026.7.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v2026.6.0-2 "$(merge "$edit_task")"
expect 'version bump' v2026.7.0-0 "$(merge "$bump_version")"

scenario 'A patch-level version bump'
expect 'patch bump' v2026.6.1-0 "$(merge "$bump_patch")"

# `v2026-0` exists in every scenario, because this repository really carries it.
# If the version were ever read as a bare year - which is exactly the mistake the
# commit-message era made, Misskey publishing a floating `2026` tag - the counter
# would continue from that instead of starting afresh.
scenario 'The floating-year tag left over from the commit-message era'
expect 'a task' v2026.6.0-2 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''           "$(merge "$edit_readme")"
expect 'a script' ''           "$(merge "$edit_script")"
expect 'a task'   v2026.6.0-2  "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v2026.6.0-$release_number"
done
expect 'a task' v2026.6.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v2026.6.0-1 already published, so there is
# nothing new to release.
expect 'a revert' ''           "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v2026.6.0-2 "$(merge "$revert_version && $edit_task")"

# Renovate edits the literal on the line the `# renovate:` annotation sits on. If a
# refactor ever moved this script onto another variable - `misskey_container_image_tag`
# is right there in the fixture, and holds a Jinja expression rather than a version -
# releases would stop tracking the version that actually ships. This ties the two
# together explicitly.
scenario 'The version comes from the leaf the Renovate annotation sits on'
annotated_value="$(sed -n '/^# renovate:/{n;s|^[^:]*:[[:space:]]*||;p}' defaults/main.yml)"
expect 'a task on the annotated version' "v${annotated_value}-2" "$(merge "$edit_task")"

# The same fixture, with the version variable renamed out from under the script.
# Guessing a version here rather than failing loudly would be worse than useless.
scenario 'No version variable at all'
sed -i 's|^misskey_version:|misskey_version_renamed:|' defaults/main.yml
git add -A
git commit -qm 'Rename the version variable'
if bin/compute-next-tag.sh > /dev/null 2>&1; then
	printf '  FAIL | a defaults file without misskey_version produced a tag\n'
	failures=$((failures + 1))
else
	printf '  ok   | a defaults file without misskey_version fails loudly\n'
fi

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
