#!/bin/bash
## Notes to go here...

run=5
batch=10
pause=2

internet_wait ()
{
	PL=$(ping -c 1 -q  8.8.8.8 | grep -oP '\d+(?=% packet loss)')
	while [ $PL == 100 ]; do
		echo "Offline"
		count=$( ps -A | grep -o wget | wc -l )
		if [ $count -ge 1 ]; then
			pkill wget
		fi
		## sleep $pause
		PL=$(ping -c 5 -q  8.8.8.8 | grep -oP '\d+(?=% packet loss)')
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
	
	sites=0
	time=$SECONDS
	uagent="Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; MATBJS; rv:11.0) like Gecko"
	while read p; do
		sites=$((sites+1))
		printf "$sites -> $p\n"
        wget -U "$uagent" -T 8 -t 1 -4bq -O /dev/null --no-cookies --https-only "https://$p" > /dev/null
		if [ $((sites % batch)) -eq 0 ] ; then
			speed=$(( sites / ((SECONDS - time)+1)))
			printf "$speed websites per second.\n"
			internet_wait
			wget_wait
		fi
	done < sites.txt
done
