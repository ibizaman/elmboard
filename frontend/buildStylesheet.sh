#!/bin/sh

# This file is needed because elm-live can only handle a single
# executable without arguments.

elm-css --output static StylesheetGenerator.elm
