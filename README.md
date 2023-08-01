# beronet-sms-api-client
## SMS-API Client for Beronet GSM Gateway

This script allows to use the beronet HTTP SMS-API to send/receive SMS via a Beronet GSM Gateway.
All you need is bash and wget.


```
Usage:
  send-sms-beronet.sh [options]

beronet SMS-API-Client   Allows to send/receive SMS from/to a
                           beronet GSM Gateway
Version 0.1 20230801 - made by JWA

Requirements:
  wget                   Needs to be in PATH variables or in cd
                           Can be obtained as a debian package

Options:
  -H, --host <host>      IP or hostname of the GSM gateway
  -u, --user <user>      Username for HTTP-Basic-Auth, omit for no auth
  -p, --pass <pass>      Password for HTTP-Basic-Auth, omit for no auth

  -c, --command <cmd>    Command which can be one of:
                           delete, get, list, send, inbox
                         Command inbox is an inofficial feature that gets all messages

Options for command >> list, inbox <<
  -q, --queue <queue>    Name of the sms queue which is one of:
                           in, out, failout

Options for command >> get, delete <<
  -q, --queue <queue>    Name of the sms queue which is one of:
                           in, out, failout
  -i, --identifier <id>  Identifier of the sms to get/delete
                           (as returned by list command)
  -D, --delete           Delete the sms after getting it
                           (only to be used with get command to get and delete)

Options for command >> send <<
  -P, --port <gsmport>   SIM-card slot to use (0-4, default: 1)
                           Although 0 is a documented valid number for send-API and it is
                           also supported here, when selecting slot 0 your messages will end
                           up in out-queue and will never get sent. Good for testing inbox...
  -n, --number <number>  Phone number of the receiver
  -m, --message <text>   Message to send

Other options:
  -v, --verbose          Enable debug output
  -d, --dry-run          Do not run the final beronet command, just print it
  -h, --help             Print this help and exit

Examples:
  send-sms-beronet.sh -H 192.168.1.10 -u admin -p admin -c send -P 1 -n +436640000000 -m 'Test-SMS'
  send-sms-beronet.sh -H 192.168.1.10 -u admin -p admin -c inbox -q in
  send-sms-beronet.sh --host 192.168.1.10 --command get --queue out --identifier 596d089c263412 --delete
```
