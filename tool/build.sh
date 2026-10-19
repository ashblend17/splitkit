#!/usr/bin/env bash
# Builds Splitkit, any part of it or all of it, with one command:
#   - the Android app: an APK to install, or an App Bundle for Google Play;
#   - the iOS app (on a Mac);
#   - the web app as a static bundle, to host anywhere;
#   - the Docker images docker compose runs: api, tricount (the same image) and web.
#
# Files go to dist/, named with the version, build number and commit, and dist/SHA256SUMS lists
# their checksums. Images are tagged :latest (what `docker compose up` runs) and
# :<version>-<build>-<commit>; whatever :latest was before keeps a tag of its own, so going back
# is one `docker tag`.
#
#   tool/build.sh apk --api-origin https://splitkit.example.com
#   tool/build.sh apk --beta --api-origin http://192.168.0.3:8000   # installs next to the app
#   tool/build.sh images                                            # docker compose's images
#   tool/build.sh all --api-origin https://splitkit.example.com --check
#
# `tool/build.sh --help` lists every target and option. Works with macOS's bash 3.2 too.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD

usage() {
  cat <<'EOF'
Usage: tool/build.sh <target>... [options]

Targets (any number, in any order):
  apk          Android APK, to install on a phone (adb install, or open it on the phone)
  aab          Android App Bundle, for Google Play
  android      apk and aab
  ios          iOS: an .ipa (needs a Mac with Xcode and signing; see --no-codesign)
  web          The web app as a static bundle (dist/splitkit-web-*.tar.gz)
  api          Docker image for the API and the Tricount sync (alias: backend)
  web-image    Docker image for the web app (nginx serving it, proxying /api)
  images       api and web-image: everything docker compose runs
  all          apk, aab, web and images, plus ios on a Mac

Options:
  --api-origin URL      Server the phone apps talk to, e.g. https://splitkit.example.com (the app
                        adds /api/v1). Needed for apk, aab and ios unless --debug or --dev-tools.
                        Default: $SPLITKIT_API_ORIGIN.
  --web-api-origin URL  Server the web bundle talks to. Default: none, the page's own origin (as
                        served by the web image, whose nginx proxies /api).
  --beta                Android: build "Splitkit Beta" (com.splitkit.splitkit.beta), which installs
                        next to the normal app instead of updating it and may use plain http.
  --debug | --profile   Build mode (default: release).
  --dev-tools           Keep developer settings (the login screen's Server link) in a release
                        build, so the server can be changed on the phone.
  --define KEY=VALUE    Extra --dart-define for the Flutter builds (repeatable), e.g.
                        --define SMS_TEST_SENDER=5551234.
  --split-per-abi       APK: one smaller file per CPU type instead of one for all.
  --base-href /path/    Web bundle: serve it under a sub-path.
  --no-codesign         iOS: build Runner.app without signing (zipped) instead of an .ipa.
  --build-name X.Y.Z    Version shown to users. Default: pubspec.yaml's (now 0.1.0).
  --build-number N      Android versionCode / iOS build. Default: the number of commits, so it
                        goes up with every commit (Android refuses an "update" to a lower one).
  --check               Run the checks first: flutter analyze and tests for app builds; ruff and
                        pytest for the API image (pytest needs the compose db: docker start
                        splitkit-db-1).
  --clean               flutter clean before building.
  --push REPO           After building images, push them as REPO:split-api|split-tricount|split-web
                        (what docker-compose.prod.yml pulls) and REPO:split-<svc>-<tag> (to go
                        back to). Needs docker login. Refuses a build with uncommitted changes.
  --allow-dirty         Push even with uncommitted changes in app/ or api/.
  --out DIR             Where files go. Default: dist/.
  -h, --help            This help.

Examples:
  tool/build.sh apk --api-origin https://splitkit.example.com
  tool/build.sh apk --beta --api-origin http://192.168.0.3:8000 --dev-tools
  tool/build.sh images && docker compose up -d --no-build
  tool/build.sh images --push <user>/<repo>
  tool/build.sh all --api-origin https://splitkit.example.com --check
EOF
}

# ---- output ----

if [[ -t 1 ]]; then BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' YEL=$'\033[33m' OFF=$'\033[0m'
else BOLD='' DIM='' RED='' YEL='' OFF=''; fi
die() { printf '%serror:%s %s\n' "$RED" "$OFF" "$*" >&2; exit 1; }
warn() { printf '%swarning:%s %s\n' "$YEL" "$OFF" "$*" >&2; }
step() { printf '\n%s==> %s%s\n' "$BOLD" "$*" "$OFF"; }
NOTES=()
note() { NOTES+=("$*"); }

STARTED=$SECONDS
CURRENT=""
trap 'rc=$?; if [[ $rc -ne 0 && -n $CURRENT ]]; then printf "\n%sfailed:%s %s (exit %s)\n" "$RED" "$OFF" "$CURRENT" "$rc" >&2; fi' EXIT

# ---- arguments ----

[[ $# -gt 0 ]] || { usage >&2; exit 2; }

API_ORIGIN=${SPLITKIT_API_ORIGIN:-}
WEB_API_ORIGIN=""
MODE=release
BETA=0
DEV_TOOLS=0
SPLIT_PER_ABI=0
BASE_HREF=""
NO_CODESIGN=0
BUILD_NAME=""
BUILD_NUMBER=""
CHECK=0
CLEAN=0
PUSH_REPO=""
ALLOW_DIRTY=0
OUT=$ROOT/dist
DEFINES=()
TARGETS=()

need_value() { [[ $# -ge 2 && -n $2 && $2 != --* ]] || die "$1 needs a value (see --help)"; }

while [[ $# -gt 0 ]]; do
  # --opt=value is the same as --opt value.
  if [[ $1 == --*=* ]]; then set -- "${1%%=*}" "${1#*=}" "${@:2}"; fi
  case $1 in
    -h|--help) usage; exit 0 ;;
    --api-origin) need_value "$@"; API_ORIGIN=$2; shift 2 ;;
    --web-api-origin) need_value "$@"; WEB_API_ORIGIN=$2; shift 2 ;;
    --beta) BETA=1; shift ;;
    --debug) MODE=debug; shift ;;
    --profile) MODE=profile; shift ;;
    --release) MODE=release; shift ;;
    --dev-tools) DEV_TOOLS=1; shift ;;
    --define) need_value "$@"; [[ $2 == *=* ]] || die "--define takes KEY=VALUE"; DEFINES+=("--dart-define=$2"); shift 2 ;;
    --split-per-abi) SPLIT_PER_ABI=1; shift ;;
    --base-href) need_value "$@"; BASE_HREF=$2; shift 2 ;;
    --no-codesign) NO_CODESIGN=1; shift ;;
    --build-name) need_value "$@"; BUILD_NAME=$2; shift 2 ;;
    --build-number) need_value "$@"; BUILD_NUMBER=$2; shift 2 ;;
    --check) CHECK=1; shift ;;
    --clean) CLEAN=1; shift ;;
    --push) need_value "$@"; PUSH_REPO=$2; shift 2 ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --out) need_value "$@"; OUT=$2; shift 2 ;;
    -*) die "unknown option $1 (see --help)" ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

DO_APK=0 DO_AAB=0 DO_IOS=0 DO_WEB=0 DO_API_IMAGE=0 DO_WEB_IMAGE=0
for t in ${TARGETS[@]+"${TARGETS[@]}"}; do
  case $t in
    apk) DO_APK=1 ;;
    aab|appbundle|bundle) DO_AAB=1 ;;
    android) DO_APK=1 DO_AAB=1 ;;
    ios|ipa) DO_IOS=1 ;;
    web) DO_WEB=1 ;;
    api|backend|api-image) DO_API_IMAGE=1 ;;
    web-image) DO_WEB_IMAGE=1 ;;
    images) DO_API_IMAGE=1 DO_WEB_IMAGE=1 ;;
    all)
      DO_APK=1 DO_AAB=1 DO_WEB=1 DO_API_IMAGE=1 DO_WEB_IMAGE=1
      if [[ $(uname) == Darwin ]]; then DO_IOS=1; else note "all: iOS skipped (it needs macOS; without a Mac, .github/workflows/ios.yml builds it)."; fi
      ;;
    *) die "unknown target '$t' (see --help)" ;;
  esac
done
[[ $((DO_APK + DO_AAB + DO_IOS + DO_WEB + DO_API_IMAGE + DO_WEB_IMAGE)) -gt 0 ]] || die "no target given (see --help)"

DO_ANDROID=$((DO_APK + DO_AAB))
DO_PHONE=$((DO_ANDROID + DO_IOS))
DO_FLUTTER=$((DO_PHONE + DO_WEB))
DO_IMAGES=$((DO_API_IMAGE + DO_WEB_IMAGE))

# ---- checks before anything runs ----

have() { command -v "$1" >/dev/null 2>&1; }
[[ $DO_FLUTTER -eq 0 && ! ($CHECK -eq 1 && $DO_WEB_IMAGE -eq 1) ]] || have flutter || die "flutter isn't on PATH"
[[ $DO_IMAGES -eq 0 ]] || have docker || die "docker isn't on PATH"
[[ $CHECK -eq 0 || $DO_API_IMAGE -eq 0 ]] || have uv || die "uv isn't on PATH (needed by --check for the API)"
have git || die "git isn't on PATH"
if [[ $DO_IOS -eq 1 && $(uname) != Darwin ]]; then
  die "iOS builds need macOS and Xcode. Without a Mac, run .github/workflows/ios.yml (GitHub → Actions → iOS build)."
fi
if [[ $DO_PHONE -gt 0 && -z $API_ORIGIN && $MODE != debug && $DEV_TOOLS -eq 0 ]]; then
  die "phone builds need --api-origin (the server they talk to, e.g. https://splitkit.example.com), or --dev-tools to type one on the phone"
fi
if [[ $DO_ANDROID -gt 0 && $BETA -eq 0 && $API_ORIGIN == http://* ]]; then
  warn "the normal Android app refuses plain http: $API_ORIGIN won't be reachable. Use https, or --beta."
fi
[[ $BETA -eq 0 || $DO_ANDROID -gt 0 ]] || warn "--beta only changes Android builds"
[[ $SPLIT_PER_ABI -eq 0 || $DO_APK -eq 1 ]] || warn "--split-per-abi only changes the APK"
[[ $NO_CODESIGN -eq 0 || $DO_IOS -eq 1 ]] || warn "--no-codesign only changes the iOS build"
[[ -z $PUSH_REPO || $DO_IMAGES -gt 0 ]] || die "--push pushes images: add a target that builds them (images, api, web-image)"
if [[ -n $BASE_HREF && ($BASE_HREF != /* || $BASE_HREF != */) ]]; then die "--base-href must start and end with /"; fi

# ---- version ----

[[ -n $BUILD_NAME ]] || BUILD_NAME=$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' app/pubspec.yaml)
[[ -n $BUILD_NAME ]] || die "couldn't read the version from app/pubspec.yaml; pass --build-name"
[[ -n $BUILD_NUMBER ]] || BUILD_NUMBER=$(git rev-list --count HEAD)
[[ $BUILD_NUMBER =~ ^[0-9]+$ ]] || die "--build-number must be a whole number"
SHA=$(git rev-parse --short HEAD)
DIRTY=""
[[ -z $(git status --porcelain -- app api) ]] || DIRTY="-dirty"
# Docker tags can't hold "+", so the tag and file names use "-": 0.1.0-81-eb4a276.
TAG="$BUILD_NAME-$BUILD_NUMBER-$SHA$DIRTY"
if [[ -n $DIRTY ]]; then
  warn "app/ or api/ has uncommitted changes: this build is marked $TAG"
  if [[ -n $PUSH_REPO && $ALLOW_DIRTY -eq 0 ]]; then die "refusing to push a build with uncommitted changes (commit them, or --allow-dirty)"; fi
fi

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
ARTIFACTS=()
IMAGES_BUILT=()
show() { case $1 in "$ROOT"/*) printf '%s' "${1#"$ROOT"/}" ;; *) printf '%s' "$1" ;; esac; }
keep() { cp "$1" "$OUT/$2"; ARTIFACTS+=("$2"); printf '   → %s\n' "$(show "$OUT/$2")"; }
sha256() { if have sha256sum; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

printf '%sSplitkit %s+%s (%s%s), %s%s\n' "$BOLD" "$BUILD_NAME" "$BUILD_NUMBER" "$SHA" "$DIRTY" "$MODE" "$OFF"
[[ $DO_PHONE -eq 0 ]] || printf '  phone apps talk to: %s\n' "${API_ORIGIN:-(none: set on the phone, dev tools)}"
[[ $DO_WEB -eq 0 ]] || printf '  web bundle talks to: %s\n' "${WEB_API_ORIGIN:-its own origin}"

# ---- Flutter options shared by the app builds ----

FLUTTER=(--"$MODE" --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER")
PHONE_DEFINES=(${DEFINES[@]+"${DEFINES[@]}"})
[[ -z $API_ORIGIN ]] || PHONE_DEFINES+=("--dart-define=API_ORIGIN=$API_ORIGIN")
[[ $DEV_TOOLS -eq 0 ]] || PHONE_DEFINES+=("--dart-define=DEV_TOOLS=true")
WEB_DEFINES=(${DEFINES[@]+"${DEFINES[@]}"})
[[ -z $WEB_API_ORIGIN ]] || WEB_DEFINES+=("--dart-define=API_ORIGIN=$WEB_API_ORIGIN")
[[ $DEV_TOOLS -eq 0 ]] || WEB_DEFINES+=("--dart-define=DEV_TOOLS=true")
# build.gradle.kts gives a beta its own application id ("Splitkit Beta"); empty is the normal app.
ID_SUFFIX=""
NAME=splitkit
if [[ $BETA -eq 1 ]]; then ID_SUFFIX=.beta NAME=splitkit-beta; fi

flutter_build() { (cd app && SPLITKIT_APP_ID_SUFFIX="$ID_SUFFIX" flutter build "$@"); }

# ---- checks ----

if [[ $CHECK -eq 1 ]]; then
  if [[ $DO_FLUTTER -gt 0 || $DO_WEB_IMAGE -eq 1 ]]; then
    CURRENT="checks: app"; step "Checks: flutter analyze and tests"
    (cd app && flutter analyze && flutter test --concurrency=1)
  fi
  if [[ $DO_API_IMAGE -eq 1 ]]; then
    CURRENT="checks: API"; step "Checks: ruff and pytest"
    (cd api && uv run ruff check . && uv run ruff format --check . && uv run pytest -q)
  fi
fi

if [[ $CLEAN -eq 1 && $DO_FLUTTER -gt 0 ]]; then
  CURRENT="flutter clean"; step "flutter clean"
  (cd app && flutter clean)
fi

# ---- Android ----

if [[ $DO_ANDROID -gt 0 ]] && grep -q 'signingConfigs.getByName("debug")' app/android/app/build.gradle.kts; then
  note "Android builds are signed with this machine's debug key: phones accept them, but an update must be signed with the same key (keep ~/.android/debug.keystore), and Google Play needs a release key."
fi

if [[ $DO_APK -eq 1 ]]; then
  CURRENT="APK"; step "Android APK${ID_SUFFIX:+ (beta: com.splitkit.splitkit$ID_SUFFIX)}"
  apks=app/build/app/outputs/flutter-apk
  rm -f "$apks"/app-*.apk
  if [[ $SPLIT_PER_ABI -eq 1 ]]; then
    flutter_build apk "${FLUTTER[@]}" ${PHONE_DEFINES[@]+"${PHONE_DEFINES[@]}"} --split-per-abi
    for f in "$apks"/app-*-"$MODE".apk; do
      abi=${f##*/app-}
      keep "$f" "$NAME-$TAG-${abi%-"$MODE".apk}-$MODE.apk"
    done
  else
    flutter_build apk "${FLUTTER[@]}" ${PHONE_DEFINES[@]+"${PHONE_DEFINES[@]}"}
    keep "$apks/app-$MODE.apk" "$NAME-$TAG-$MODE.apk"
  fi
fi

if [[ $DO_AAB -eq 1 ]]; then
  CURRENT="App Bundle"; step "Android App Bundle${ID_SUFFIX:+ (beta: com.splitkit.splitkit$ID_SUFFIX)}"
  aab=app/build/app/outputs/bundle/$MODE/app-$MODE.aab
  rm -f "$aab"
  flutter_build appbundle "${FLUTTER[@]}" ${PHONE_DEFINES[@]+"${PHONE_DEFINES[@]}"}
  keep "$aab" "$NAME-$TAG-$MODE.aab"
fi

# ---- iOS ----

if [[ $DO_IOS -eq 1 ]]; then
  CURRENT="iOS"
  if [[ $NO_CODESIGN -eq 1 ]]; then
    step "iOS app, unsigned"
    flutter_build ios "${FLUTTER[@]}" ${PHONE_DEFINES[@]+"${PHONE_DEFINES[@]}"} --no-codesign
    case $MODE in debug) dir=Debug-iphoneos ;; profile) dir=Profile-iphoneos ;; *) dir=Release-iphoneos ;; esac
    app=app/build/ios/iphoneos/Runner.app
    [[ -d $app ]] || app=app/build/ios/$dir/Runner.app
    [[ -d $app ]] || die "couldn't find the built Runner.app"
    (cd "$(dirname "$app")" && zip -qry "$OUT/splitkit-$TAG-ios-$MODE.app.zip" Runner.app)
    ARTIFACTS+=("splitkit-$TAG-ios-$MODE.app.zip"); printf '   → %s\n' "$(show "$OUT/splitkit-$TAG-ios-$MODE.app.zip")"
  else
    [[ $MODE != debug ]] || die "an .ipa can't be a debug build: use --profile, --release or --no-codesign"
    step "iOS .ipa (needs signing set up in Xcode)"
    rm -rf app/build/ios/ipa
    flutter_build ipa "${FLUTTER[@]}" ${PHONE_DEFINES[@]+"${PHONE_DEFINES[@]}"}
    for f in app/build/ios/ipa/*.ipa; do keep "$f" "splitkit-$TAG-$MODE.ipa"; done
  fi
fi

# ---- web bundle ----

if [[ $DO_WEB -eq 1 ]]; then
  CURRENT="web bundle"; step "Web app bundle"
  web_flags=("${FLUTTER[@]}" ${WEB_DEFINES[@]+"${WEB_DEFINES[@]}"})
  [[ -z $BASE_HREF ]] || web_flags+=("--base-href=$BASE_HREF")
  flutter_build web "${web_flags[@]}"
  tar -C app/build/web -czf "$OUT/splitkit-web-$TAG-$MODE.tar.gz" .
  ARTIFACTS+=("splitkit-web-$TAG-$MODE.tar.gz"); printf '   → %s\n' "$(show "$OUT/splitkit-web-$TAG-$MODE.tar.gz")"
fi

# ---- Docker images ----

# Keeps the image splitkit-<svc>:latest points at under a tag of its own before it's replaced:
# the tag it was built with, if it still has one, else backup-<when it was built>.
keep_previous() {
  local repo=$1 id tags t kept
  id=$(docker image inspect -f '{{.Id}}' "$repo:latest" 2>/dev/null) || return 0
  tags=$(docker image inspect -f '{{join .RepoTags " "}}' "$id")
  for t in $tags; do
    if [[ $t != "$repo:latest" && $t == "$repo:"* ]]; then
      printf '   previous %s:latest is kept as %s\n' "$repo" "$t"
      return 0
    fi
  done
  kept=$(docker image inspect -f '{{with .Config.Labels}}{{index . "app.splitkit.tag"}}{{end}}' "$id")
  if [[ -z $kept ]]; then
    kept=backup-$(docker image inspect -f '{{.Created}}' "$id" | cut -c1-16 | tr -d ':-' | tr 'T' '-')
  fi
  docker tag "$id" "$repo:$kept"
  printf '   previous %s:latest is kept as %s:%s\n' "$repo" "$repo" "$kept"
}

build_image() { # image name, build context
  local repo=$1 context=$2
  keep_previous "$repo"
  docker build \
    --label "org.opencontainers.image.title=$repo" \
    --label "org.opencontainers.image.version=$BUILD_NAME+$BUILD_NUMBER" \
    --label "org.opencontainers.image.revision=$SHA$DIRTY" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --label "app.splitkit.tag=$TAG" \
    -t "$repo:latest" -t "$repo:$TAG" "$context"
  IMAGES_BUILT+=("$repo:$TAG")
}

if [[ $DO_API_IMAGE -eq 1 ]]; then
  CURRENT="API image"; step "Docker image: api (and tricount, the same image)"
  build_image splitkit-api api
  # docker compose builds tricount from the same context: the same image under its own name.
  keep_previous splitkit-tricount
  docker tag splitkit-api:latest splitkit-tricount:latest
  docker tag splitkit-api:latest "splitkit-tricount:$TAG"
  IMAGES_BUILT+=("splitkit-tricount:$TAG")
fi

if [[ $DO_WEB_IMAGE -eq 1 ]]; then
  CURRENT="web image"; step "Docker image: web"
  [[ -z $WEB_API_ORIGIN && $DEV_TOOLS -eq 0 && $MODE == release ]] ||
    note "The web image is always a release build served from its own origin; --web-api-origin, --dev-tools and the mode apply to the web bundle only."
  build_image splitkit-web app
fi

if [[ -n $PUSH_REPO ]]; then
  CURRENT="push"; step "Pushing to $PUSH_REPO"
  for image in ${IMAGES_BUILT[@]+"${IMAGES_BUILT[@]}"}; do
    svc=${image%%:*}; svc=${svc#splitkit-}
    for remote in "$PUSH_REPO:split-$svc" "$PUSH_REPO:split-$svc-$TAG"; do
      docker tag "$image" "$remote"
      docker push "$remote"
    done
  done
fi

# ---- summary ----

CURRENT=""
if [[ ${#ARTIFACTS[@]} -gt 0 ]]; then
  # One checksum line per file in dist/, this build's and earlier ones'.
  (
    cd "$OUT"
    files=()
    for f in *; do [[ -f $f && $f != SHA256SUMS ]] && files+=("$f"); done
    sha256 "${files[@]}" > SHA256SUMS
  )
fi

elapsed=$((SECONDS - STARTED))
step "Done in $((elapsed / 60))m $((elapsed % 60))s"
for a in ${ARTIFACTS[@]+"${ARTIFACTS[@]}"}; do
  printf '  %-60s %8s  %s\n' "$(show "$OUT/$a")" "$(du -h "$OUT/$a" | cut -f1)" "$(sha256 "$OUT/$a" | cut -c1-16)…"
done
for i in ${IMAGES_BUILT[@]+"${IMAGES_BUILT[@]}"}; do
  printf '  %-60s %8s\n' "$i" "$(docker image inspect -f '{{.Id}}' "$i" | cut -c8-19)"
done
for n in ${NOTES[@]+"${NOTES[@]}"}; do printf '%snote:%s %s\n' "$DIM" "$OFF" "$n"; done

if [[ $DO_IMAGES -gt 0 && -z $PUSH_REPO ]]; then
  printf '\nTo run the new images: docker compose up -d --no-build\n'
  printf '%s(the API migrates the database as it starts: back it up first, see deploy.md)%s\n' "$DIM" "$OFF"
fi
if [[ $DO_APK -eq 1 ]]; then
  printf 'To install the APK: adb install %s (or open it on the phone)\n' "$(show "$OUT/${ARTIFACTS[0]}")"
fi
