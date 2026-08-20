#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/osascript -l JavaScript "$DIR/../Resources/StayAwake.js"
