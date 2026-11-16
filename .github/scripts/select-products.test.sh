#!/bin/sh
# Tests for select-products.sh.  Builds throwaway git repositories and checks the
# decision for a few representative pushes; run it after touching the mapping:
#
#   sh .github/scripts/select-products.test.sh
set -eu

script=$(dirname "$0")/select-products.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fail=0

# Commit into the scratch repo; echoes the new commit.
commit() {
    repo=$1
    shift
    git -C "$repo" add -A
    git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m "$*"
    git -C "$repo" rev-parse HEAD
}

# build <event> <before> <sha> <product> <dir> <base-deps> [extra-dirs]; echoes yes/no
build() {
    env -i PATH="$PATH" \
        GITHUB_EVENT_NAME="$1" BEFORE="$2" GITHUB_SHA="$3" \
        PRODUCT="$4" GITHUB_ENV="$work/env" SOURCE_DIR="$5" \
        sh "$script" "$6" "$7" "$8" "${9:-}"
}

check() {
    label=$1 want=$2 got=$3
    if [ "$want" = "$got" ]; then
        echo "ok   ${label}: ${got}"
    else
        echo "FAIL ${label}: want ${want}, got ${got}" >&2
        fail=1
    fi
}

newrepo() {
    repo=$work/repo-$1
    git init -q "$repo"
    mkdir -p "$repo/fc/2025.06" "$repo/verdi/2025.06-SP1" "$repo/base" "$repo/ciel" \
             "$repo/vip/2023.12" "$repo/synopsys/2025.06" "$repo/scl/2025.03" \
             "$repo/vcs/2025.06-SP1" "$repo/vcs/2023.12-SP2" "$repo/verdi/2023.12-SP2"
    echo 1 >"$repo/fc/2025.06/Containerfile"
    echo 1 >"$repo/verdi/2025.06-SP1/Containerfile"
    echo 1 >"$repo/vcs/2025.06-SP1/Containerfile"
    echo 1 >"$repo/vcs/2023.12-SP2/Containerfile"
    echo 1 >"$repo/verdi/2023.12-SP2/Containerfile"
    echo 1 >"$repo/scl/2025.03/Containerfile"
    echo 1 >"$repo/base/Containerfile.build"
    echo 1 >"$repo/base/Containerfile.runtime"
    echo 1 >"$repo/ciel/Containerfile.pdk"
    echo 1 >"$repo/vip/2023.12/Containerfile"
    echo 1 >"$repo/synopsys/2025.06/Containerfile"
    echo "$repo"
}

# One commit per touched product, pushed one at a time.
r=$(newrepo single)
root=$(commit "$r" root)

echo x >>"$r/fc/2025.06/Containerfile"
touch_file=$(commit "$r" fc)
check "push touching fc/ builds fc" yes "$(build push "$root" "$touch_file" '' "$r" fc fc/2025.06 both)"
check "push touching fc/ skips verdi" no "$(build push "$root" "$touch_file" '' "$r" verdi verdi/2025.06-SP1 both)"
check "push touching fc/ skips ciel" no "$(build push "$root" "$touch_file" '' "$r" ciel ciel no)"

# A push carrying several commits (before is not HEAD~1) must see them all.
echo y >>"$r/verdi/2025.06-SP1/Containerfile"
multi=$(commit "$r" verdi)
check "multi-commit push builds verdi" yes "$(build push "$root" "$multi" '' "$r" verdi verdi/2025.06-SP1 both)"
check "multi-commit push builds fc" yes "$(build push "$root" "$multi" '' "$r" fc fc/2025.06 both)"

# base/ rebuilds everything built on the selected base, but not the scratch
# images; scl/vip only use build:8.10, synopsys only uses runtime:8.10.
deps='vcs/2025.06-SP1:verdi/2025.06-SP1:lc/2025.06:spyglass/2025.06:fm/2025.06:pt/2025.06:dc/2025.06-SP4:fc/2025.06:vcst/2025.06-SP2:vip:ciel'

echo z >>"$r/base/Containerfile.build"
basec=$(commit "$r" base)
check "base/Containerfile.build builds fc" yes "$(build push "$multi" "$basec" '' "$r" fc fc/2025.06 both)"
check "base/Containerfile.build builds vip" yes "$(build push "$multi" "$basec" '' "$r" vip vip/2023.12 build)"
check "base/Containerfile.build builds scl" yes "$(build push "$multi" "$basec" '' "$r" scl scl/2025.03 build)"
check "base/Containerfile.build skips ciel" no "$(build push "$multi" "$basec" '' "$r" ciel ciel no)"

echo r >>"$r/base/Containerfile.runtime"
runtimec=$(commit "$r" base-runtime)
check "base/Containerfile.runtime builds fc" yes \
    "$(build push "$basec" "$runtimec" '' "$r" fc fc/2025.06 both)"
check "base/Containerfile.runtime builds synopsys" yes \
    "$(build push "$basec" "$runtimec" '' "$r" synopsys synopsys/2025.06 runtime "$deps")"
check "base/Containerfile.runtime skips vip" no \
    "$(build push "$basec" "$runtimec" '' "$r" vip vip/2023.12 build)"
check "base/Containerfile.runtime skips scl" no \
    "$(build push "$basec" "$runtimec" '' "$r" scl scl/2025.03 build)"
check "base/Containerfile.build builds only the build base" yes \
    "$(build push "$multi" "$basec" '' "$r" base base/Containerfile.build no)"
check "base/Containerfile.build skips the runtime base" no \
    "$(build push "$multi" "$basec" '' "$r" base base/Containerfile.runtime no)"
check "base/Containerfile.runtime builds only the runtime base" yes \
    "$(build push "$basec" "$runtimec" '' "$r" base base/Containerfile.runtime no)"
check "base/Containerfile.runtime skips the build base" no \
    "$(build push "$basec" "$runtimec" '' "$r" base base/Containerfile.build no)"

# A file renamed out of a product directory still counts as a change there.
r2=$(newrepo rename)
root2=$(commit "$r2" root)
mkdir -p "$r2/docs"
git -C "$r2" mv fc/2025.06/Containerfile docs/fc-notes.txt
renamed=$(commit "$r2" rename)
check "rename out of fc/ builds fc" yes "$(build push "$root2" "$renamed" '' "$r2" fc fc/2025.06 both)"

# A documentation-only change under a product directory must not rebuild it.
r3=$(newrepo docs)
root3=$(commit "$r3" root)
echo doc >"$r3/fc/2025.06/README.md"
mkdir -p "$r3/fc/2025.06/k8s"
echo "kind: Pod" >"$r3/fc/2025.06/k8s/pod.yaml"
docs=$(commit "$r3" docs)
check "README under fc/ skips fc" no "$(build push "$root3" "$docs" '' "$r3" fc fc/2025.06 both)"

# The all-in-one image is assembled from the product images, so any of them (or
# the PDK image) changing must rebuild it; a change under synopsys/ itself does
# too, and a documentation-only change still does not.

# A flist-only change updates the build-input manifest; it is not a build
# input, so it must not rebuild the image (or the all-in-one image that copies
# it).
r5=$(newrepo flist)
root5=$(commit "$r5" root)
echo "Containerfile" >"$r5/fc/2025.06/flist"
echo "pdk/" >"$r5/ciel/flist"
flistc=$(commit "$r5" flist)
check "flist under fc/ skips fc" no \
    "$(build push "$root5" "$flistc" '' "$r5" fc fc/2025.06 both)"
check "flist under fc/ skips synopsys" no \
    "$(build push "$root5" "$flistc" '' "$r5" synopsys synopsys/2025.06 runtime "$deps")"
check "flist under ciel/ skips ciel" no \
    "$(build push "$root5" "$flistc" '' "$r5" ciel ciel no)"

# A product with two built releases selects by version directory, and an older
# release that the all-in-one image does not copy must not rebuild it.
r4=$(newrepo releases)
root4=$(commit "$r4" root)
echo x >>"$r4/vcs/2023.12-SP2/Containerfile"
c2023=$(commit "$r4" vcs-2023)
check "push touching vcs/2023.12-SP2 builds that release" yes \
    "$(build push "$root4" "$c2023" '' "$r4" vcs vcs/2023.12-SP2 both)"
check "push touching vcs/2023.12-SP2 skips vcs/2025.06-SP1" no \
    "$(build push "$root4" "$c2023" '' "$r4" vcs vcs/2025.06-SP1 both)"
check "push touching vcs/2023.12-SP2 skips synopsys" no \
    "$(build push "$root4" "$c2023" '' "$r4" synopsys synopsys/2025.06 runtime "$deps")"
check "push touching vcs/2023.12-SP2 skips verdi" no \
    "$(build push "$root4" "$c2023" '' "$r4" verdi verdi/2025.06-SP1 both)"

echo x >>"$r4/verdi/2023.12-SP2/Containerfile"
c_v2023=$(commit "$r4" verdi-2023)
check "push touching verdi/2023.12-SP2 builds that release" yes \
    "$(build push "$c2023" "$c_v2023" '' "$r4" verdi verdi/2023.12-SP2 both)"
check "push touching verdi/2023.12-SP2 skips verdi/2025.06-SP1" no \
    "$(build push "$c2023" "$c_v2023" '' "$r4" verdi verdi/2025.06-SP1 both)"
check "push touching verdi/2023.12-SP2 skips synopsys" no \
    "$(build push "$c2023" "$c_v2023" '' "$r4" synopsys synopsys/2025.06 runtime "$deps")"

echo x >>"$r4/vcs/2025.06-SP1/Containerfile"
c2025=$(commit "$r4" vcs-2025)
check "push touching vcs/2025.06-SP1 builds vcs" yes \
    "$(build push "$c_v2023" "$c2025" '' "$r4" vcs vcs/2025.06-SP1 both)"
check "push touching vcs/2025.06-SP1 skips vcs/2023.12-SP2" no \
    "$(build push "$c_v2023" "$c2025" '' "$r4" vcs vcs/2023.12-SP2 both)"
check "push touching vcs/2025.06-SP1 builds synopsys" yes \
    "$(build push "$c_v2023" "$c2025" '' "$r4" synopsys synopsys/2025.06 runtime "$deps")"
check "README under fc/ skips synopsys" no \
    "$(build push "$root3" "$docs" '' "$r3" synopsys synopsys/2025.06 runtime "$deps")"
check "push touching fc/ builds synopsys" yes \
    "$(build push "$root" "$touch_file" '' "$r" synopsys synopsys/2025.06 runtime "$deps")"
check "push touching fc/ skips synopsys without the dependency list" no \
    "$(build push "$root" "$touch_file" '' "$r" synopsys synopsys/2025.06 both)"

echo 2 >"$r3/synopsys/2025.06/Containerfile"
synopsysc=$(commit "$r3" synopsys)
check "push touching synopsys/ builds synopsys" yes \
    "$(build push "$docs" "$synopsysc" '' "$r3" synopsys synopsys/2025.06 runtime "$deps")"

echo 2 >>"$r3/ciel/Containerfile.pdk"
cielc=$(commit "$r3" ciel)
check "push touching ciel/ builds synopsys" yes \
    "$(build push "$synopsysc" "$cielc" '' "$r3" synopsys synopsys/2025.06 runtime "$deps")"
check "push touching ciel/ skips synopsys without the dependency list" no \
    "$(build push "$synopsysc" "$cielc" '' "$r3" synopsys synopsys/2025.06 both)"
check "push touching ciel/ builds ciel" yes \
    "$(build push "$synopsysc" "$cielc" '' "$r3" ciel ciel no)"

# An unresolvable range (new branch, force push) rebuilds everything.
check "unknown range builds verdi" yes "$(build push '' "$touch_file" '' "$r" verdi verdi/2025.06-SP1 both)"
check "missing object builds verdi" yes \
    "$(build push 1111111111111111111111111111111111111111 "$touch_file" '' "$r" verdi verdi/2025.06-SP1 both)"

# workflow_dispatch keeps selecting by product name.
check "dispatch product=fc builds fc" yes "$(build workflow_dispatch '' '' fc "$r2" fc fc/2025.06 both)"
check "dispatch product=fc skips verdi" no "$(build workflow_dispatch '' '' fc "$r2" verdi verdi/2025.06-SP1 both)"
check "dispatch product=all builds verdi" yes "$(build workflow_dispatch '' '' all "$r2" verdi verdi/2025.06-SP1 both)"
check "dispatch product=all builds base" yes "$(build workflow_dispatch '' '' all "$r2" base base no)"
check "dispatch product=base skips verdi" no "$(build workflow_dispatch '' '' base "$r2" verdi verdi/2025.06-SP1 both)"

# The decision is exported for the build step's `if:`.
grep -qx 'BUILD=yes' "$work/env" || { echo "FAIL GITHUB_ENV was not written" >&2; fail=1; }

exit "$fail"
