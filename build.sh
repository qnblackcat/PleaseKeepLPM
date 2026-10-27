#!/bin/bash
# ./build.sh                    release packages, roothide + rootless (clears ./packages first, opens it after)
# ./build.sh roothide|rootless  release package for one scheme only
# ./build.sh ip15               build and install on ip15 (roothide)
# ./build.sh ip12               build and install on ip12 (rootless)
# ./build.sh install            build and install on both
# IP15 and IP12 override the address each device is reached at (default: ip15, ip12).
# Add "debug" to any of these for a debug build: FINALPACKAGE=0 plus the project's own debug switch
# (a Makefile line such as `ifeq ($(NOTEMATH_DEBUG),1)`, found automatically). Only the bare
# ./build.sh clears and opens ./packages.
# Works in any Theos project: run it from the project folder (or link it into your PATH).
set -e

# Device -> package scheme, and the address it is reached at
IP15=${IP15:-ip15}
IP12=${IP12:-ip12}
scheme_of() {
	case "$1" in
		ip15) echo roothide ;;
		ip12) echo rootless ;;
	esac
}
address_of() {
	case "$1" in
		ip15) echo "$IP15" ;;
		ip12) echo "$IP12" ;;
	esac
}

DEBUG=0
DEVICES=()
SCHEMES=()
for arg in "$@"; do
	case "$arg" in
		debug)             DEBUG=1 ;;
		ip15|ip12)         DEVICES+=("$arg") ;;
		install)           DEVICES+=(ip15 ip12) ;;
		roothide|rootless) SCHEMES+=("$arg") ;;
		*) echo "Usage: $0 [debug] [roothide|rootless | ip15 | ip12 | install]" >&2; exit 1 ;;
	esac
done

if [ $DEBUG -eq 1 ]; then
	FLAGS="FINALPACKAGE=0"
	# The project's debug switch: the first "<NAME>_DEBUG" the Makefile tests with ifeq/ifdef/ifneq.
	DEBUG_VAR=$(grep -Eo '^[[:space:]]*if(n?eq|n?def)[[:space:]]*\(?\$\(?[A-Z0-9_]*_DEBUG' Makefile 2>/dev/null | grep -Eo '[A-Z0-9_]*_DEBUG' | head -1)
	[ -n "$DEBUG_VAR" ] && FLAGS="$FLAGS $DEBUG_VAR=1"
else
	FLAGS="FINALPACKAGE=1"
fi

# Theos names objects after their compile flags, so there is no need for "make clean". The link
# step is not part of that name, though (rootless links libroot, roothide does not): removing the
# linked dylibs makes every build link again, which takes a moment.
build() { # build <scheme> [extra make args...]
	local scheme=$1
	shift
	rm -f .theos/obj/*.dylib .theos/obj/*/*.dylib
	make package $FLAGS THEOS_PACKAGE_SCHEME=$scheme "$@"
}

if [ ${#DEVICES[@]} -gt 0 ]; then
	if [ ${#SCHEMES[@]} -gt 0 ]; then
		echo "A scheme cannot be combined with ip15/ip12/install" >&2
		exit 1
	fi
	for device in $(printf '%s\n' "${DEVICES[@]}" | awk '!seen[$0]++'); do
		build "$(scheme_of "$device")" install THEOS_DEVICE_IP="$(address_of "$device")"
	done
	exit 0
fi

# Only a bare ./build.sh clears ./packages first and opens it afterwards.
[ $# -eq 0 ] && rm -rf ./packages
[ ${#SCHEMES[@]} -eq 0 ] && SCHEMES=(roothide rootless)
for scheme in "${SCHEMES[@]}"; do
	build "$scheme"
done
[ $# -eq 0 ] && open ./packages
exit 0
