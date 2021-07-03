#!/bin/sh -eux

rm -f include.tar.gz
tar -czf include.tar.gz --owner=root:0 --group=root:0 -C include etc root
