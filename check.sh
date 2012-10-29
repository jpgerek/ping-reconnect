#!/bin/sh

if [ -f config.sh ]
then
	# Loading a config file.
	source config.sh;
else
	echo "\tYou need to setup a config file, take a look to config_sample.sh.";
	exit 2;
fi

network_device=${network_device:-"wi-fi"};
network_interface=${network_interface:-"en0"};
maximum_RTT=${maximum_RTT:-"2"}; # seconds
interval=${interval:-"1"};
errors_limit=${errors_limit:-"8"};


reconnections_counter=0;
errors_counter=0;

echo "\tSetup:";
echo "\t\t- network: $network";
echo "\t\t- password: $password";
echo "\t\t- gateway: $gateway";
echo "\n";

reconnect () {
	networksetup -setairportpower $network_interface off;
	networksetup -setairportpower $network_interface on;
	# Wait a little till the interface is up again.
	sleep 0.3;
	while true
	do
		echo "\tConnecting...";
		networksetup -setairportnetwork "$network_interface" "$network" $password;
		network_return_code=$?;
		sleep 0.7;
		# Retry unless there is a successful ping.
		ping -t $maximum_RTT -c 2 "$gateway" 2>/dev/null 1>/dev/null;
		ping_return_code=$?;
		if [ $ping_return_code -ne 0 ]
		then
			# echo "\n\tnetwork: $network_return_code";
			# echo "\tping: $ping_return_code";
			echo "\n\t\tError connecting, retrying...";
			continue;
		else
			echo "\t\tConnection successful.";
			break;
		fi
	done
	reconnections_counter=$((reconnections_counter+1));
	echo "\t\tNumber of connections: $reconnections_counter.";
}

control_c() {
	echo "";
	exit 3;
}

trap control_c SIGINT;

# Checking if we are connected.
networksetup -getairportnetwork "$network_interface" | grep -q "You are not associated with an AirPort network";
if [ $? -eq 0 ]
then
	echo "\tWe aren't connected, lets connect...";
	reconnect;
	continue;
fi

while true
do
	ping -t $maximum_RTT -c 1 "$gateway" 2>/dev/null 1>/dev/null;
	# Checking if the ping was successful.
	if [ $? -ne 0 ]
	then
		errors_counter=$(($errors_counter+1));
		echo "\033[31m!\033[0m\c";
		# echo "\tTimeout or error in the ping: $errors_counter.";
		if [ $errors_counter -ge $errors_limit ]
		then
			errors_counter=0;
			# Reconnecting.
			reconnect;
			continue;
		fi
	else
		echo "\033[32m.\033[0m\c";
		errors_counter=0;
		sleep $interval;
	fi	
done
