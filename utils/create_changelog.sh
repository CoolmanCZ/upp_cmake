#!/bin/bash

git log --pretty=format:"%ai - %h : %s" > ../Changelog
git commit ../Changelog -m "Changelog update"

