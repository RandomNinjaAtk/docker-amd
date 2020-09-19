#!/usr/bin/env python3
from deemix.api.deezer import Deezer
import sys

if __name__ == '__main__':
    if len(sys.argv) > 1:
        dz = Deezer()
        releases = dz.get_artist_discography_gw(sys.argv[1], 100)
        for type in releases:
            for release in releases[type]:
                print(release['id'])
