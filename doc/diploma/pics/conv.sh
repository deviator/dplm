#!/bin/bash
find . -name "*.svg" -exec sh -c 'inkscape -f "$0" -A "${0%.svg}.eps"' {} \;
