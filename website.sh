#!/bin/bash

run=5
batch=10
pause=2

internet_wait ()
{
	nc -z -w 1 -4 8.8.8.8 53 > /dev/null 2>&1
	result=$?
	while [ $result -ne 0 ]; do
		sleep $pause
		echo "Offline"
		nc -z -w 1 -4 8.8.8.8 53 > /dev/null 2>&1
		result=$?
	done
}

wget_wait ()
{
	count=$( ps -A | grep -o wget | wc -l )
	while [ $count -ge $run ]; do
		sleep $pause
		count=$( ps -A | grep -o wget | wc -l )
		#echo $count
	done
}

while :
do 
	internet_wait
	
	if [ -f top-1m.csv.zip ]; then
		wget -N https://s3.amazonaws.com/alexa-static/top-1m.csv.zip 
	else
		wget -S https://s3.amazonaws.com/alexa-static/top-1m.csv.zip 
	fi

	if [ -f top-1million-sites.csv.zip ]; then
		wget -N https://statvoo.com/dl/top-1million-sites.csv.zip
	else
		wget -S https://statvoo.com/dl/top-1million-sites.csv.zip
	fi

	gzip -dc  top-1m.csv.zip | pv -s 22000000 | sed 's/[^,]*,//' > /tmp/test1.txt
	gzip -dc  top-1million-sites.csv.zip | pv -s 22000000 | sed 's/[^,]*,//' > /tmp/test2.txt

	cat /tmp/test1.txt /tmp/test2.txt | pv | sort -uR > sites.txt

	rm /tmp/test1.txt
	rm /tmp/test2.txt
	
	sites=1
	time=$SECONDS
	while read p; do
		printf "$sites -> $p\n"
        wget https://$p -T 8 -t 1 -4 -qO /dev/null &
		if [ $((sites % batch)) -eq 0 ] ; then
			speed=$(( sites / ((SECONDS - time)+1)))
			printf "$speed websites per second.\n"
			internet_wait
			wget_wait
			
		fi
		sites=$((sites+1))
	done < sites.txt
done
