#!/bin/sh -eux

for dir in */ ; do
	fakeroot dpkg-deb -b "$dir"
done
