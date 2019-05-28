#!/bin/bash

# https://github.com/bikboy/Tim/wiki/AWS-CLI----ITerm2-automation-(Mac)
# https://starkandwayne.com/blog/bash-for-loop-over-json-array-using-jq/
# https://alvinalexander.com/source-code/mac-os-x/how-run-multiline-applescript-script-unix-shell-script-osascript

REGION=us-east-1
USERNAME='ec2-user'

usage() {
	echo "Usage: $0 [-s <45|90>] [-p <string>]" 1>&2;
	echo "Usage:"
	echo "    pip -h                      Display this help message."
	echo "    pip install                 Install a Python package."
	exit 1;
}


# Check Parameters...
while getopts ':h:r:n:u:' opt; do
  case "${opt}" in
    h )
      usage
      ;;
    r ) REGION="${OPTARG}" ;;
    n ) NAME="${OPTARG}" ;;
    u ) USERNAME="${OPTARG}" ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

# Check for Default Arguments (Instance Name)
if [ -z "${NAME}" ]; then
    usage
fi

# Retrieve Info from AWS
HOSTS="$(\
	aws ec2 describe-instances \
	--region $REGION \
	--filter 'Name=tag:Name,Values="'$NAME'"' \
	--query 'Reservations[].Instances[].{Host: PublicDnsName, KeyPair: KeyName, Name: Tags[?Key==`Name`].Value | [0]}'
)"

COUNT=$(echo $HOSTS | jq length)


# Check if Instances Exist
if [ "$COUNT" = "" ] || [ $COUNT == 0 ]; then
	echo "Instance(s) Not Found!"
	exit 1
fi

# Determine Row / Column Layout
if [ $COUNT > 3 ]; then
	ROWS=$(awk -v x=$COUNT 'BEGIN{printf "%3.0f\n", sqrt(x)}')
else
	ROWS=$COUNT
fi

# Start Terminal
osascript <<EOF
tell application "iTerm 2" to activate
tell application "System Events" to tell process "iTerm 2" to keystroke "n" using command down
EOF


# Interate through Instances / Results
BASE64=$(echo $HOSTS | jq -r '.[] | @base64')
i=0
for row in $BASE64; do
	_jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

    HOST=$(_jq '.Host')
    NAME=$(_jq '.Name')
    KEYPAIR=$(_jq '.KeyPair')

    MOD=$(($i%$ROWS))

    if (( $i < $ROWS )); then
    	# First Column - Split Horizontal to Init First of Each Row
    	if [[ $i != 0 ]]; then
    		osascript -e 'tell application "System Events" to tell process "iTerm 2" to keystroke "d" using {shift down, command down}'
    	fi
    else
    	if [[ $MOD == 0 ]]; then
    		# Loop Back Up to Top
    		for ((j=1;j<$ROWS;j++)); do
		    	osascript -e 'tell application "System Events" to tell process "iTerm 2" to key code 126 using {option down, command down}'
			done
    	else
    		# Move Left / Move Down
    		osascript -e 'tell application "System Events" to tell process "iTerm 2" to key code 123 using {option down, command down}'
    		osascript -e 'tell application "System Events" to tell process "iTerm 2" to key code 125 using {option down, command down}'
    	fi
    	# Split Vertical
		osascript -e 'tell application "System Events" to tell process "iTerm 2" to keystroke "d" using command down'
    fi

    osascript -e 'tell application "System Events" to tell process "iTerm 2" to keystroke "ssh -i '"$KEYPAIR"'.pem '"$USERNAME"'@'"$HOST"'"'
	osascript -e 'tell application "System Events" to tell process "iTerm 2" to key code 52'

    i=$(( $i + 1 ))
done

# Broadcast
osascript -e 'tell application "System Events" to tell process "iTerm 2" to keystroke "i" using {option down, command down}'
exit 0