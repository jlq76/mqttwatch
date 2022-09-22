# mqttwatch

Important note: this is a very early draft version and not intended to be used as is.

## Principle
The idea behind this script is to use a MQTT payload to request a distant server (behind a NAT) to open a tunnel using ngrok or localhost.run.
The goal being not to have any permanent open port on the local router.

The script uses a config file that specifies the mqtt server's url and port as well as the topic to listen.

Whenever a valid payload is received, it will take action to create a tunnel.

The "request" json payload will contain:
  - the service to use: either ngrok or lhrun (localhost.run)
  - the protocol to use (specific to ngrok): either UDP or TCP
  - the port to tunnel (any port with ngrok / 80 or 443 only with localhost)
  - the action: open or close the tunnel
  - the ip of the server to tunnel (specific to localhost.run)

The "answer" payload will contain:
  - the unique URL that was generated to access the service
  
**Limitations** (and reasons to use two different services)
  - ngrok can only tunnel the server from which it runs
  - localhost.run (in its free version) will only allow ports 80 and 443 to be tunneled.
  
## TODO & Future plan
 - Make the code robust, handle errors
 - Create a frontend (likely php) to post the MQTT request and read the answer
