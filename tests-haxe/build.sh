#!/usr/bin/env bash
# Regenerates the inputs of the Haxe-compiled code tests from hx/: the Haxe sources are compiled
# to a SWC (as a game links Haxe code), decompiled with JPEXS FFDec, and split as the
# Dungeon-Rampage-Decompiled sync does: the classes FFDec cannot print as ActionScript (§) and
# the Haxe standard library go to src-bytecode/ and lib/bytecode.swc, the others to src/.
# expected.txt is the output of the same checks run from the Haxe sources (--interp).
#
# Usage: tests-haxe/build.sh [ffdec.jar]   (FFDEC_JAR also works; the dev branch of
# https://github.com/Tutez64/jpexs-decompiler is needed for -swf2swc -selectclass)
set -euo pipefail
cd "$(dirname "$0")"
FFDEC_JAR="${1:-${FFDEC_JAR:?pass the path to ffdec.jar}}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

(cd hx && haxe -cp . -main RefMain --interp) > expected.txt
(cd hx && haxe -cp . -swf "$TMP/pipeline.swc" -swf-version 11 -D swf-param-names -debug pipeline.Checks)
unzip -p "$TMP/pipeline.swc" library.swf > "$TMP/library.swf"
java -jar "$FFDEC_JAR" -config paramNamesEnable=true -export script "$TMP/export" "$TMP/library.swf" > /dev/null

rm -rf src src-bytecode lib
mv "$TMP/export/scripts" src
mkdir -p src-bytecode lib
std="haxe,haxe.**,flash.Boot,flash.Lib,Std,Type,Reflect,StringTools,StringBuf,EReg,Lambda,Xml,ValueType,Dynamic,_Xml.**"
section="$(cd src && grep -rl --include='*.as' $'\xc2\xa7' . | sed 's|^\./||; s|\.as$||; s|/|.|g' | LC_ALL=C sort | paste -sd, -)"
selection="$std${section:+,$section}"
# move the selected sources to src-bytecode/
for pattern in ${selection//,/ }; do
  case "$pattern" in
    *.\*\*) dir="${pattern%.**}"; dir="${dir//.//}"; [[ -d "src/$dir" ]] && mkdir -p "src-bytecode/$(dirname "$dir")" && mv "src/$dir" "src-bytecode/$dir" ;;
    *) file="${pattern//.//}.as"; [[ -f "src/$file" ]] && mkdir -p "src-bytecode/$(dirname "$file")" && mv "src/$file" "src-bytecode/$file" ;;
  esac
done
find src -depth -type d -empty -delete
java -jar "$FFDEC_JAR" -selectclass "$selection" -swf2swc lib/bytecode.swc "$TMP/library.swf" > /dev/null
echo "src: $(find src -name '*.as' | wc -l) classes, src-bytecode: $(find src-bytecode -name '*.as' | wc -l)"
