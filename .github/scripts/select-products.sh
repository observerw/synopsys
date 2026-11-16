#!/bin/sh
# Decide whether this run has to build one image.
#
# Called from the "Check sources" step of build-images.yaml:
#
#   decision=$(sh "${SOURCE_DIR}/.github/scripts/select-products.sh" \
#                    <key> <dir> [base-deps] [extra-dirs])
#
# <key>              the workflow_dispatch `product` choice that selects this
#                    image ("base" for the two base images, otherwise the
#                    image name)
# <dir>              the path to watch: the build context, e.g. dc/2025.06-SP4
#                    (base/ for a whole context), or a single file such as
#                    base/Containerfile.build
# [base-deps]        which base change rebuilds this image:
#                      both     built on build:8.10 and runtime:8.10 (default)
#                      build    only build:8.10 (scl, vip)
#                      runtime  only runtime:8.10 (synopsys assembly)
#                      no       not built on either base (ciel, the bases)
#                    "yes" is accepted as an alias for "both".
# [extra-dirs]       colon-separated directories whose changes also rebuild
#                    this image, for an image assembled from other images
#                    (synopsys/ copies the trees out of the product images)
#
# Prints "yes" or "no" and appends the same decision as BUILD=yes|no to
# $GITHUB_ENV, which is what the "Build and push" step gates on.  The reason is
# printed to stderr so it lands in the job log.  Exits non-zero on a real error
# (an unknown event, an unusable checkout), which fails the job.
#
# Selection rules:
#
#   workflow_dispatch  product=<key>, or product=all
#   push               any file under <dir>/ or one of <extra-dirs>/, or the
#                      base input selected by <base-deps>.  When the push range
#                      cannot be resolved (first push of a branch, missing
#                      objects) every image is rebuilt: skipping one would be
#                      worse.
set -eu

key=$1
dir=$2
needs_base=${3:-both}
extra_dirs=${4:-}
repo=${SOURCE_DIR:?SOURCE_DIR is not set}
event=${GITHUB_EVENT_NAME:?GITHUB_EVENT_NAME is not set}

say() { printf '%s\n' "$*" >&2; }

case "$needs_base" in
yes) needs_base=both ;;
both | build | runtime | no) ;;
*)
    say "invalid base-deps: ${needs_base} (expected both, build, runtime or no)"
    exit 2
    ;;
esac

# The job pod runs as a different user than the checkout's owner, so git needs
# the explicit safe.directory that the surrounding steps also pass.
g() { git -c "safe.directory=${repo}" -C "${repo}" "$@"; }

decide() {
    echo "BUILD=$1" >> "${GITHUB_ENV:?GITHUB_ENV is not set}"
    echo "$1"
}

case "$event" in
workflow_dispatch)
    want=${PRODUCT:-}
    if [ "$want" = all ] || [ "$want" = "$key" ]; then
        say "workflow_dispatch: product=${want} selects ${key}"
        decide yes
    else
        say "workflow_dispatch: product=${want:-<unset>} does not select ${key}"
        decide no
    fi
    ;;
push)
    sha=${GITHUB_SHA:?GITHUB_SHA is not set}
    before=${BEFORE:-}
    case "$before" in
    0000000000000000000000000000000000000000) before= ;;
    esac

    if [ -z "$before" ] ||
        ! g cat-file -e "${before}^{commit}" 2>/dev/null ||
        ! g cat-file -e "${sha}^{commit}" 2>/dev/null; then
        say "push: cannot diff ${before:-<none>}..${sha}, assuming every image changed"
        decide yes
        exit 0
    fi

    changed=$(g diff --name-only --no-renames "$before" "$sha")

    # Documentation, the k8s manifests and the per-context flist manifests are
    # not build inputs (no Containerfile copies them; vip/ excludes flist from
    # its bind-mounted context), so they must not trigger a rebuild: a README
    # fix in synopsys/ would otherwise redo a ~250 GB image.
    inputs=$(printf '%s\n' "$changed" |
        grep -v -E '(^|/)[^/]*\.md$|(^|/)k8s/|(^|/)\.gitignore$|(^|/)flist$' || :)

    hit=no
    watch=$(printf '%s' "${dir}${extra_dirs:+:${extra_dirs}}" | tr ':' ' ')
    for d in $watch; do
        if [ -d "${repo}/${d}" ]; then
            if printf '%s\n' "$inputs" | grep -q "^${d}/"; then
                hit=yes
                say "push: ${before}..${sha} changes ${d}/"
                break
            fi
        elif printf '%s\n' "$inputs" | grep -qx "${d}"; then
            hit=yes
            say "push: ${before}..${sha} changes ${d}"
            break
        fi
    done

    if [ "$hit" = no ]; then
        case "$needs_base" in
        both)
            if printf '%s\n' "$inputs" | grep -q '^base/'; then
                hit=yes
                say "push: ${before}..${sha} changes base/"
            fi
            ;;
        build)
            if printf '%s\n' "$inputs" | grep -qx 'base/Containerfile.build'; then
                hit=yes
                say "push: ${before}..${sha} changes base/Containerfile.build"
            fi
            ;;
        runtime)
            if printf '%s\n' "$inputs" | grep -qx 'base/Containerfile.runtime'; then
                hit=yes
                say "push: ${before}..${sha} changes base/Containerfile.runtime"
            fi
            ;;
        esac
    fi

    if [ "$hit" = no ]; then
        say "push: ${before}..${sha} leaves ${watch} and the selected base inputs alone"
    fi
    decide "$hit"
    ;;
*)
    say "unsupported event: ${event}"
    exit 2
    ;;
esac
