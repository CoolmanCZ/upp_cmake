#!/bin/bash

git log --pretty=format:"%ai - %h : %s" > ../Changelog
sed -i '1s/- .* :/-         :/' ../Changelog
git commit ../Changelog -m "Changelog update"

