#!/bin/sh
# Validate the deployment configuration that build-images.yaml maps from
# repository variables.
#
#   sh .github/scripts/ci-config.sh
#
# The workflow has no defaults for these values: a missing repository variable
# must fail here instead of silently building against another registry or
# source tree.  SOURCE_DIR must also be the checkout of the commit this run
# builds; an old checkout would build code that was never pushed.
set -eu

say() { printf '%s\n' "$*" >&2; }
fail() {
    say "$*"
    exit 1
}

require() {
    eval "value=\${$1:-}"
    [ -n "$value" ] || fail "repository variable $1 is not set"
}

require REGISTRY
require NAMESPACE
require BUILDKIT_ADDR
require SOURCE_DIR

repo=$SOURCE_DIR
sha=${GITHUB_SHA:?GITHUB_SHA is not set}

# The job pod runs as a different user than the checkout's owner, so git needs
# the explicit safe.directory that the surrounding steps also pass.
g() { git -c "safe.directory=${repo}" -C "${repo}" "$@"; }

g rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fail "SOURCE_DIR is not a git checkout: ${repo}"

head=$(g rev-parse HEAD)
[ "$head" = "$sha" ] ||
    fail "SOURCE_DIR is at ${head}, but this run builds ${sha}; update the checkout"

say "config: source=${repo}@${sha} registry=${REGISTRY}/${NAMESPACE} buildkit=${BUILDKIT_ADDR}"
