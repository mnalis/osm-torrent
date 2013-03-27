#!/bin/sh
# downloads latest planets and changelogs from cron, nicely serialized
# source http://osm-torrent.torres.voyager.hr/
# by Matija Nalis 20120218 GPLv3+


get_all()
{
	env FILE_TYPE=changesets 	EXPIRE_DAYS=30	/var/www/osm-torrent/files/create_new_planet_torrent.sh && \
	env FILE_TYPE=pbfplanet		EXPIRE_DAYS=5	/var/www/osm-torrent/files/create_new_planet_torrent.sh && \
	env FILE_TYPE=planet 		EXPIRE_DAYS=5	/var/www/osm-torrent/files/create_new_planet_torrent.sh
}

#DEBUG=9
#export DEBUG

# check if any other instance is running and abort if it is
fuser -s /var/www/osm-torrent/files/*.osm.* && exit 0

# default (2 days ago)
#get_all

# today ?
DATE=$(date --date today +\%y\%m\%d)
export DATE
get_all

# yesterday ?
DATE=$(date --date yesterday +\%y\%m\%d)
export DATE
get_all

# day before yesterday ?
DATE=$(date --date '2 days ago' +\%y\%m\%d)
export DATE
get_all

# day before day before yesterday ?
DATE=$(date --date '3 days ago' +\%y\%m\%d)
export DATE
get_all

# day before day before day before yesterday ?
DATE=$(date --date '4 days ago' +\%y\%m\%d)
export DATE
get_all

# day before day before day before day before yesterday ?
DATE=$(date --date '5 days ago' +\%y\%m\%d)
export DATE
get_all

exit 0
