#!/bin/bash
cd "${0%/*}"

# made by JWA
version="0.1 20230801"
script_name="$(basename -- $0)"
use_command="wget" # currently only wget tested and supported!!!

############################ FUNCTIONS ############################

fail_help() {
echo "Usage:
  $script_name [options]

beronet SMS-API-Client   Allows to send/receive SMS from/to a
                           beronet GSM Gateway
Version $version - made by JWA

Requirements:
  $use_command                   Needs to be in PATH variables or in cd
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
                           up in out-queue and will never get sent. Use it for testing the out queue.
  -n, --number <number>  Phone number of the receiver
  -m, --message <text>   Message to send

Other options:
  -v, --verbose          Enable debug output
  -d, --dry-run          Do not run the final beronet command, just print it
  -h, --help             Print this help and exit

Examples:
  $script_name -H 192.168.1.10 -u admin -p admin -c send -P 1 -n +436640000000 -m 'Test-SMS'
  $script_name -H 192.168.1.10 -u admin -p admin -c inbox -q in
  $script_name --host 192.168.1.10 --command get --queue out --identifier 596d089c263412 --delete
"; exit 3;
}
fail() { printf "$script_name failed: %s\n" "$1" >&2; exit 3; }
fail_usage() { printf "$script_name: $1\n  Type $script_name -h for usage help\n" >&2; exit 3; }

isNum_notEmpty_canNeg="^-?[0-9]+$"
isNum_notEmpty_notNeg="^[0-9]+$"
isNum_notEmpty_phoneNumber="^[0-9+]+$"
isNum_notEmpty_hexNumber="^[0-9A-Fa-f]+$"
isNum_canEmpty_canNeg="^-?[0-9]*$"
isNum_canEmpty_notNeg="^[0-9]*$"
isNum() { if ! [[ "$2" =~ $1 ]]; then return 1; fi; return 0; }

urle () { [[ "${1}" ]] || return 1; local LANG=C i x; for (( i = 0; i < ${#1}; i++ )); do x="${1:i:1}"; [[ "${x}" == [a-zA-Z0-9.~_-] ]] && echo -n "${x}" || printf '%%%02X' "'${x}"; done; echo; }
urld () { [[ "${1}" ]] || return 1; : "${1//+/ }"; echo -e "${_//%/\\x}"; }

############################ SCRIPT BEGIN ############################

VALID_ARGS=$(getopt -o H:u:p:c:q:i:DP:n:m:vdh --long host:,user:,pass:,command:,queue:,identifier:,delete,port:,number:,message:,verbose,dry-run,help -- "$@")
if [ $? != 0 ] ; then fail_usage "invalid options"; fi

p_host=""
p_user=""
p_pass=""
p_command=""
p_queue=""
p_identifier=""
p_delete=false
p_port="1"
p_number=""
p_message=""
p_verbose=false
p_dryrun=false
eval set -- "$VALID_ARGS"
while true; do
    case "$1" in
        -H | --host )        p_host="$2";        shift 2 ;;
        -u | --user )        p_user="$2";        shift 2 ;;
        -p | --pass )        p_pass="$2";        shift 2 ;;
        -c | --command )     p_command="$2";     shift 2 ;;
        -q | --queue )       p_queue="$2";       shift 2 ;;
        -i | --identifier )  p_identifier="$2";  shift 2 ;;
        -D | --delete )      p_delete=true;      shift ;;
        -P | --port )        p_port="$2";        shift 2 ;;
        -n | --number )      p_number="$2";      shift 2 ;;
        -m | --message )     p_message="$2";     shift 2 ;;
        -v | --verbose )     p_verbose=true;     shift ;;
        -d | --dry-run )     p_dryrun=true;      shift ;;
        -h | --help )        fail_help;          break ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

if [[ -z $p_host ]]; then fail_usage "required parameter <host> missing"; fi;
if [[ "$p_host" =~ [\"\'\ \\] ]]; then fail_usage "parameter <host> cannot contain \" \' [SPACE] [BACKSLASH]"; fi;

if [[ -z $p_command ]]; then fail_usage "required parameter <command> missing"; fi;

if [[ "$p_command" == "get" || "$p_command" == "delete" || "$p_command" == "list" || "$p_command" == "inbox" ]]; then
    if [[ "$p_queue" != "in" && "$p_queue" != "out" && "$p_queue" != "failout" ]]; then
        fail_usage "unknown queue type";
    fi;
    if [[ "$p_command" == "get" || "$p_command" == "delete" ]]; then
        if ! isNum "$isNum_notEmpty_hexNumber" "$p_identifier"; then fail_usage "parameter <identifier> must be a hex-number"; fi;
    fi;
fi;

bario_url="/app/api/api.php?apiCommand="
case "$p_command" in
    list | inbox )
        bario_url="${bario_url}SmsListMessages&SmsQueue=$p_queue";
        ;;
    get )
        bario_url="${bario_url}SmsGetMessage&SmsQueue=$p_queue&SmsIdentifier=$p_identifier";
        if [[ $p_delete == true ]]; then bario_url="${bario_url}&Delete"; fi;
        ;;
    delete )
        bario_url="${bario_url}SmsDeleteMessage&SmsQueue=$p_queue&SmsIdentifier=$p_identifier";
        ;;
    send )
        if [[ -z $p_number ]]; then fail_usage "required parameter <number> missing"; fi;
        if ! isNum "$isNum_notEmpty_phoneNumber" "$p_number"; then fail_usage "parameter <number> is not a valid phone number (Allowed chars: 0-9 +)"; fi;
        if ! isNum "$isNum_notEmpty_notNeg" "$p_port"; then fail_usage "parameter <port> must be numeric"; fi;
        if (( $p_port < 0 )) || (( $p_port > 4 )); then fail_usage "parameter <port> is out of range 0 - 4"; fi;
        if [[ -z $p_message ]]; then fail_usage "required parameter <message> missing"; fi;
        bario_url="${bario_url}SmsSendMessage&GsmPort=$p_port&PhoneNumber=$(urle "$p_number")&Message=$(urle "$p_message")";
        ;;
    * )
        fail_usage "unknown command specified";
        ;;
esac

curlcmd="curl"
wgetcmd="wget -O -"
if [[ -n $p_user && -n $p_pass ]]; then
    curlcmd="${curlcmd} -u '$p_user:$p_pass'"
    wgetcmd="${wgetcmd} --user $p_user --password $p_pass"
fi;
curlcmd="${curlcmd} http://${p_host}${bario_url}"
wgetcmd="${wgetcmd} http://${p_host}${bario_url}"

command="${curlcmd}"
if [[ "$use_command" == "wget" ]]; then command="${wgetcmd}"; fi;

if [[ $p_dryrun == true || $p_verbose == true ]]; then
    echo "=== Generated API-URL is: $bario_url";
    echo "=== Generated $use_command command is: $command";
    if [[ $p_dryrun == true ]]; then exit 0; fi;
fi;

unset t_std t_err;

eval "$( $command \
      2> >(t_err=$(cat); typeset -p t_err) \
       > >(t_std=$(cat); typeset -p t_std) )"
if [[ $p_verbose == true ]]; then printf "=== $use_command stdout:\n%s\n" "$t_std"; fi;
if [[ $p_verbose == true ]]; then printf "=== $use_command stderr:\n%s\n=== END\n" "$t_err"; fi;

if [[ "$t_std" != *"success"* ]]; then
    fail "$t_std";
fi;

if [[ "$p_command" == "inbox" ]]; then
    #t_std="SmsListMessages:success:596cf76d01dfe;596cf69b7719b;"
    elements="${t_std#*success}" # get all after success
    elements="${elements//:}" # remove :
    if [[ -z "$elements" ]]; then
        printf "No messages found\n";
        exit 0;
    fi;
    export IFS=";"
    #echo "--------------"
    for t_id in $elements; do
        unset t_std t_err;
        eval "$( $0 -H $p_host -u $p_user -p $p_pass -c get -q $p_queue -i $t_id \
          2> >(t_err=$(cat); typeset -p t_err) \
           > >(t_std=$(cat); typeset -p t_std) )"
        if [[ -n "$t_err" ]]; then
            printf "Failed to query $t_id: STDERR=%s STDOUT=%s\n" "$t_err" "t_std";
        else
            #EXAMPLE: t_std=$(printf "SmsGetMessage:success\nnum=+436645286076\nport=0\nmsg=Test0")
            t_std="$(printf "message=%s\n%s\n" "$t_id" "$t_std" | grep -v 'SmsGetMessage:success')"
            echo "${t_std//$'\n'/$'\t'}"
        fi;
    done
else
    printf "%s\n" "$t_std";
fi;
exit 0;

