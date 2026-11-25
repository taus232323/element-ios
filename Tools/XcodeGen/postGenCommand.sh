#!/bin/bash

# This script is invoked by xcodegen for running post commands

# Move file header template in project shared data folder
cp IDETemplateMacros.plist ../../Arcana.xcodeproj/xcshareddata/

# Rewrite schemes the way Xcode saves them
swift normalizeSchemes.swift ../../Arcana.xcodeproj/xcshareddata/xcschemes
