#!/bin/bash
# Matija Nalis mnalis-osmplanetbt@voyager.hr, started 20101201. GPLv3+
# creates torrent file for latest OpenStreetMap planet file
#
# you should edit "WORKDIR=" line, and copy this script in your /etc/cron.daily
#
# v1.34, 20120218
#


DEF_WORKDIR=/var/www/osm-torrent/files		# you must change this, if nothing else...
DEF_EXPIRE_DAYS=5				# removes all big files except last older than this many days. Enlarge if you would like to keep several planets...
DEF_FILE_TYPE=planet				# "planet" or "pbfplanet" (or "changesets" for faster testing)
WGET_OPTIONS="--limit-rate=500k"		# if you want to speed limit wget of PLANET etc.

# those can be overriden from environment, for example:
# env FILE_TYPE=changesets EXPIRE_DAYS=30 WORKDIR=/tmp DATE=101201 create_new_planet_torrent.sh

############################################
# no user configurable parts below
############################################


DEBUG=${DEBUG:-0}
WORKDIR=${WORKDIR:-$DEF_WORKDIR}
EXPIRE_DAYS=${EXPIRE_DAYS:-$DEF_EXPIRE_DAYS}
FILE_TYPE=${FILE_TYPE:-$DEF_FILE_TYPE}
DATE=${DATE:-$(date --date '2 days ago' +%y%m%d)}	# due to timezones and stuff, it seems we only see the planet when we're already two days ahead. compensate in order to get right planet name... This would not be needed if the script is run on OSMF servers themselves, and you'd have torrents immedaately instead of 48 hours delay....

cd "$WORKDIR" || exit 101

LICENSE="Original planets from http://planet.openstreetmap.org/ licensed under CC-BY-SA 2.0 by OpenStreetMap and contributors"
if [ "$FILE_TYPE" = "pbfplanet" ]
then
	FILE_PLANET="planet-${DATE}.osm.pbf"
	URL_EXTRA_DIR="pbf/"
else
	FILE_PLANET="${FILE_TYPE}-${DATE}.osm.bz2"
	URL_EXTRA_DIR=""
fi
FILE_MD5="${FILE_PLANET}.md5"
FILE_TORRENT="${FILE_PLANET}.torrent"
FILE_TORRENT_LATEST="${FILE_TORRENT/-*.osm./-latest.osm.}"
URL_PLANET2="http://ftp5.gwdg.de/pub/misc/openstreetmap/planet.openstreetmap.org/${URL_EXTRA_DIR}${FILE_PLANET}"	# Germany, mirror planet.osm.org
URL_PLANET="http://planet.osm.org/${URL_EXTRA_DIR}${FILE_PLANET}"	# webseed fallback, original site
URL_MD5="${URL_PLANET}.md5"
CHUNKSIZE=22		# 2^20=1MB, 2^22=4MB, etc. mktorrent 1.0 default ( 2^18=256kB) is too small for our ~15GB files

[ "$DEBUG" -gt 0 ] && echo "PLANET=$URL_PLANET $URL_PLANET2, MD5=$URL_MD5, file=$FILE_TORRENT, latest=$FILE_TORRENT_LATEST"
[ "$DEBUG" -gt 8 ] && exit 0

# expire old planet.osm.bz2 files, as not to fill up disks
if [ "$FILE_TYPE" = "pbfplanet" ]
then
	find . -maxdepth 1 \( -name "planet*.pbf" ! -name ${FILE_PLANET} -mtime +${EXPIRE_DAYS} \) -print0 | xargs -r0 rm -fv
else
	find . -maxdepth 1 \( -name "${FILE_TYPE}*.bz2" ! -name ${FILE_PLANET} -mtime +${EXPIRE_DAYS} \) -print0 | xargs -r0 rm -fv
fi

# abort new download if download currently in progress!
[ -f "$FILE_PLANET" ] && fuser -s "$FILE_PLANET" && exit 0

# download new planet (if remote file changed)
wget -q -N "$WGET_OPTIONS" "$URL_PLANET"
RET=$?
[ "$DEBUG" -gt 1 ] && echo "wget $URL_PLANET -- return code $RET"

# exit silently if nothing downloaded
[ -f "$FILE_PLANET" ] || exit 0

# exit silently if planet file didn't change (torrent is newer than file)
[ "$FILE_TORRENT" -nt "$FILE_PLANET" ] && exit 0

wget -N "$WGET_OPTIONS" "$URL_MD5"
RET=$?
[ "$DEBUG" -gt 1 ] && echo "wget $URL_MD5 -- return code $RET"

if md5sum -c $FILE_MD5
then
	echo checksum ok
else
	echo checksum failed, aborting
	exit 1
fi

[ "$DEBUG" -gt 1 ] && echo "running mktorrent to create $FILE_TORRENT"

# this is our full featured torrent file: redundant trackers, tcp+udp, ipv4+ipv6, webseed
mktorrent -l $CHUNKSIZE \
  -c "See http://osm-torrent.torres.voyager.hr/ -- $LICENSE" \
  -a udp://tracker.publicbt.com:80/announce,http://tracker.publicbt.com:80/announce \
  -a udp://tracker.ccc.de:80/announce,http://tracker.ccc.de/announce \
  -a udp://tracker.ipv6tracker.org:80/announce,http://tracker.ipv6tracker.org:80/announce \
  -a udp://tracker.openbittorrent.com:80/announce \
  -a http://backuptrcker.marshyonline.net/announce \
  -w $URL_PLANET2 -w $URL_PLANET $FILE_PLANET -o ${FILE_TORRENT}.tmp \
  && mv -f ${FILE_TORRENT}.tmp ${FILE_TORRENT} \
  && ln -sf ${FILE_TORRENT} ${FILE_TORRENT_LATEST}

[ "$DEBUG" -gt 1 ] && echo "running post-process.d for $FILE_TORRENT"

# run scripts in post-process.d directory if any (we can use it to cache torrent on torrage.com, generate RSS, etc)
export DEBUG
if [ -d ./post-process.d ]
then
  run-parts --verbose --arg="$FILE_TORRENT" ./post-process.d
fi

exit 0
