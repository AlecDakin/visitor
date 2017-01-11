#!/bin/bash
## Notes to go here...

RUN=5
BATCH=10
PAUSE=2

internet_wait ()
{
	local PL=$(ping -c 1 -q  8.8.8.8 | grep -oP '\d+(?=% packet loss)')
	while [ $PL -eq 100 ]; do
		echo "Offline"
		local COUNT=$( ps -A | grep -o wget | wc -l )
		if [ $COUNT -ge 1 ]; then
			pkill wget
		fi
		PL=$(ping -c 5 -q  8.8.8.8 | grep -oP '\d+(?=% packet loss)')
	done
}

wget_wait ()
{
	[ -z $1 ] && local MIN=$RUN || local MIN=$1
	local COUNT=$( ps -A | grep -o wget | wc -l )
	local LOOP=0
	while [ $COUNT -ge $MIN ]; do
		((LOOP++))
		[ $LOOP -gt 30 ] && pkill wget
		sleep $PAUSE
		COUNT=$( ps -A | grep -o wget | wc -l )
	done
}

get_agent ()
{
	[ -s agents.txt ] && UAGENT=$( shuf -n 1 agents.txt ) || UAGENT="Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; MATBJS; rv:11.0) like Gecko"
}

get_site ()
{

	local ADDRESS=$1
	local FILENAME="${ADDRESS##*/}"
	
	[ -s $FILENAME ] && wget -U "$UAGENT" -4 --no-cookies -N "$ADDRESS" || wget -U "$UAGENT" -4 --no-cookies -S "$ADDRESS"
}


while :
do 
	get_agent
	internet_wait
	
	get_site "http://techpatterns.com/downloads/firefox/useragentswitcher.xml"
	
	grep -oP 'useragent="\K[^"]*' useragentswitcher.xml > agents.txt
	
	get_site "https://s3.amazonaws.com/alexa-static/top-1m.csv.zip"
	get_site "https://statvoo.com/dl/top-1million-sites.csv.zip"
	
	## gzip -dc  top-1m.csv.zip | pv -s 22000000 | sed 's/[^,]*,//' > /tmp/test1.txt
	## gzip -dc  top-1million-sites.csv.zip | pv -s 22000000 | sed 's/[^,]*,//' > /tmp/test2.txt
	
	gzip -dc  top-1m.csv.zip | grep -oP ',\K[^\n]*' > /tmp/test1.txt
	gzip -dc  top-1million-sites.csv.zip | grep -oP ',\K[^\n]*' > /tmp/test2.txt

	sort -fuR /tmp/test1.txt /tmp/test2.txt > sites.txt

	rm /tmp/test1.txt
	rm /tmp/test2.txt
	
	SITES=0
	TIME=$SECONDS
	
	while read LINE; do
		((SITES++))
		printf "$SITES -> $LINE\n"
        wget -U "$UAGENT" -T 8 -t 1 -4bq -O /dev/null --no-cookies --https-only "https://$LINE" > /dev/null
		if [ $((SITES % BATCH)) -eq 0 ] ; then
			SPEED=$(( SITES / ((SECONDS - TIME)+1)))
			printf "$SPEED websites per second.\n"
			get_agent
			internet_wait
			wget_wait
		fi
	done < sites.txt
	
	wget_wait 1
	
done
