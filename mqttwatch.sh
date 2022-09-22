#!/bin/bash

#options
help()
{
	# Display Help 
	printf "\nUsage: mqttwatch.sh [-v|h]\n\n"
	printf "Requires: jq, mosquitto_pub, mosquitto_sub\n\n"
	printf "mqttwatch.config MUST define: \n\t mqtt_server_url \n\t mqtt_server_port  \n\t mqtt_topic\n\n"
	printf "options:\n"
	printf "\t -h: this help message\n"
	printf "\t -v: verbose: enables debug messages\n"
}

# command line options
while getopts ":hv" option; do
   case $option in
      h) # display Help
         help
         exit;;
      v) # verbose/debug
         echo "verbose enabled"
      	 debug=true;;
      \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

# ============ MAIN ============
#source the config file
. ./mqttwatch.config

#loop on the mqtt topic
while :; do
    #read message from topic and disconnect once read [-C 1]
	msg=$(mosquitto_sub -h $mqtt_server_url -p $mqtt_server_port  -C 1 -t $mqtt_topic)
	[[ $debug == true ]] && echo $msg

	#check if valid json
	if jq -e <<< $msg 1>/dev/null 2>/dev/null; then
		#store payload values
		req_protocol=$(jq -c -r '.protocol' <<< $msg)
		req_port=$(jq -c -r '.port' <<< $msg)
		req_action=$(jq -c -r '.action' <<< $msg)
		req_service=$(jq -c -r '.service' <<< $msg)
		req_localip=$(jq -c -r '.localip' <<< $msg)
		[[ $debug == true ]] && echo "Request: $req_service> $req_action $_req_localip:$req_protocol:$req_port"
		
		#ngrok
		if [[ "$req_service" == "ngrok" ]]; then
			if [[ "$req_action" == "open" ]]; then
				#TODO!: check validity of protocol (tcp or udp) and port being a valid number
				~/ngrok $req_protocol $req_port > /dev/null &
				sleep 2s #necessary to wait ngrok api to be available
				curl -s "127.0.0.1:4040/api/tunnels" > ~/ngrok_tunnel
				url=$(cat ngrok_tunnel | jq '.tunnels[0].public_url')
				[[ $debug == true ]] && echo $url
				mosquitto_pub -h $mqtt_server_url -p $mqtt_server_port -t $mqtt_topic -m $url
			elif [[ "$req_action" == "close" ]]; then
				#TODO: should it be cleaner? e.g. store the pid when opening
				pkill ngrok
				[[ $debug == true ]] && echo "ngrok killed"
			fi
			
		#localhost.run	
		elif [[ "$req_service" == "lhrun" ]]; then
			if [[ "$req_action" == "open" ]]; then
				[[ $debug == true ]] && echo "starting localhost.run tunnel"
				#ssh options -f = fork in background, -N = run no command
				#when using fN however, the url is not returned in the variable
				#if not using it the ssh remains in foreground and block the script
				# ssh -R 80:$req_localip:80 localhost.run 
				nohup ssh -R 80:localhost:20211 localhost.run &
				lhr_pid=$!
				lhr_url=$(awk -F ', ' 'END{print $2}' nohup.out)
				[[ $debug == true ]] && echo "url: "$lhr_url
				[[ $debug == true ]] && echo "pid: "$lhr_pid
				mosquitto_pub -h $mqtt_server_url -p $mqtt_server_port -t $mqtt_topic -m {"lhr_url":"$lhr_url"}
			elif [[ "$req_action" == "close" ]]; then
				kill $lhr_pid
			fi
		#unknown service or empty key: nothing to do
		else
			[[ $debug == true ]] && echo "unknown:"$req_service
		fi
		
	#not valid json payload: nothing to do
	else
		[[ $debug == true ]] && echo "not a valid json"
	fi
done

