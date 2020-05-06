# rsyslog_impstats_centreon

## introduction

this scripts is developed for a rsyslog centralization server to analyze statistics from the rsyslog impstats module. It is use for monitoring dynafile, omfile, omrelp and main queue action.

## setup

Copy the script ( check_stats_rsyslog.sh ) or clone this repository with git where you want.

feel free to execute in active (nagios-nrpe for exemple) or in passive mode (nsca ...) for centreon.

tips:
* think about have a good synchronisation between your impstats interval parameters in rsyslog configuration and the interval of execution of this script.
* i do not use delta counters in impstats because i chose to do it in this script, if you use delta for some reasons maybe you will need to do some test to validate this script for your use.

## execution right

you need to have access to the imtats log file in reading so set correctly the right in rsyslog or execute with sudo or with root account. (default is 644 for root/adm in my version of rsyslog for the logs files)

## parameters

| parameter  | Default Value  |  Description |
| :------------: | :------------: | :------------: |
| $1 | 10 (as Ryslog conf) | dynaFileCacheSize parameter that can be define in rsyslog global or action configuration (max value 1000) |
| $2 | 90% | %use of dynaFileCacheSize that will generate warning state for centreon  |
| $3 | /var/log/rsyslog_stats | absolute path to impstats log file |
| $4 | $script_folder+/tmp | local storage directory for this script  |
| $5 | 0 / none | active debug that will active verbose if set to "1"  |
| $6 | 1 |  to desactivate omrelp supervision set to "0" |

All parameters are optional (default values are set if not defined or not correctly defined). You need to define all precedents parameters before set one.

exemple:
`sudo ./check_stats_rsyslog.sh 10 90 /var/log/rsyslog_stats_file.log /home/myuser/rsyslog_impstats_centreon/tmp 1 0`

## queue name in centreon

You can use descriptive name for action with this script with "type:name" syntax for exemple:
`action( name="omfile:Fortigate" ... )`

## development

this script was created by Fabien Stéfaniak in is work of Network and Systems Administrator at the university of Angers.

the code is validated by [shellcheck](http://www.shellcheck.net "shellcheck")

[![Université d'Angers](http://marque.univ-angers.fr/_resources/Logos/_GENERIQUE/HORIZONTAL/ECRAN/PNG/ua_h_couleur_ecran.png "Université d'Angers")](https://www.univ-angers.fr "Université d'Angers")
