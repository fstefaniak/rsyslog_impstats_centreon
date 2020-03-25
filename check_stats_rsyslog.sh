#!/bin/bash
# $1 [optional] dynaFileCacheSize parameter that can be define in rsyslog conf (default: 10)
# $2 [optional] %use of dynaFileCacheSize that will generate warning state for centreon (default: 90)
# $3 [optional] absolute path to impstats log file  (default: /var/log/rsyslog_stats)
# $4 [optional] local storage for this script (default: script_folder+/tmp)
# $5 [optional] active debug that will active verbose if set to "1" (default: 0)
# $6 [optional] to desactivate omrelp supervision set to "0" (default: 1)


#find folder where is this script
SOURCE=${BASH_SOURCE[0]}
while [ -h $SOURCE ]; do
 DIR=$( cd -P $( dirname $SOURCE ) && pwd )
 SOURCE=$(readlink $SOURCE)
 [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
done
script_dir=$( cd -P $( dirname $SOURCE ) && pwd )

#arguments set
if [ $# -eq 0 ] ; then
dynaFileCacheSize=10;
dynaFileCacheSize_warning=90;
stats_path='/var/log/rsyslog_stats';
storage_path="$script_dir/tmp";
debug=0;
omrelp_supervision=1;
else
	if [ -z "$1" ] ; then
		dynaFileCacheSize=10;
	else
		dynaFileCacheSize=$1;
	fi
	if [ -z "$2" ] ; then
		dynaFileCacheSize_warning=90;
	else
		dynaFileCacheSize_warning=$2;
	fi
	if [ -z "$3" ] ; then
		stats_path='/var/log/rsyslog_stats';
	else
		stats_path=$3;
	fi
	if [ -z "$4" ] ; then
		storage_path="$script_dir/tmp";
	else
		storage_path=$4;
	fi
	if [ -z "$5" ] ; then
		debug=0;
	else
		if [ $5 -eq 1 ] ; then
			debug=1;
		else
			debug=0;
		fi
	fi
	if [ -z "$6" ] ; then
		omrelp_supervision=1;
	else
		if [ $5 -eq 0 ] ; then
			omrelp_supervision=0;
		else
			omrelp_supervision=1;
		fi
	fi
fi

#define centreon state
# 0= OK ; 1 = Warning ; 2 = Critic ; 3 = Unknow
centreon_state=0
warn_info='';
crit_info='';
unkown_info='';

#check existing of the local storage folder and set variable initialisation if existing
if [[ -d "$storage_path" && ! -L "$storage_path" ]] ; then
	if [[ -f "$storage_path/stats.tmp" ]] ; then
		rm "$storage_path/stats.tmp"
	fi
	#load Counter if existing
	declare -A dynafile_evicted_counter
	if [[ -f "$storage_path/dynafile.evicted.counter" ]] ; then
		dynafile_total=$(wc -l "$storage_path/dynafile.evicted.counter" |awk '{print $1}')
		if [ $debug -eq 1 ] ; then echo "dynaFiles evicted counter:$dynafile_total"; fi
		if [ "$dynafile_total" -gt 0 ] ; then
			for i in `seq 1 $dynafile_total`; do
				name=$(cat "$storage_path/dynafile.evicted.counter" |awk -F ':' "NR==$i {print \$1}")
				dynafile_evicted_counter+=(["$name"]="$(cat "$storage_path/dynafile.evicted.counter" |awk -F ':' "NR==$i {print \$2}")")
			done
			if [ $debug -eq 1 ] ; then
				echo "dynaFiles: ${!dynafile_evicted_counter[@]}";
				echo "c evicted: ${dynafile_evicted_counter[@]}";
			fi
			rm "$storage_path/dynafile.evicted.counter"
		fi
	fi
	declare -A omfile_failed_counter
	if [[ -f "$storage_path/omfile.failed.counter" ]] ; then
		actions_counter_total=$(wc -l "$storage_path/omfile.failed.counter" |awk '{print $1}')
		if [ $debug -eq 1 ] ; then echo "omfile failed counter:$actions_total"; fi
		if [ "$actions_counter_total" -gt 0 ] ; then
			for i in `seq 1 $actions_counter_total`; do
				name=$(cat "$storage_path/omfile.failed.counter" |awk -F ':' "NR==$i {print \$1}")
				omfile_failed_counter+=(["$name"]="$(cat "$storage_path/omfile.failed.counter" |awk -F ':' "NR==$i {print \$2}")")
			done
			if [ $debug -eq 1 ] ; then
				echo "  omfile: ${!omfile_failed_counter[@]}";
				echo "c failed: ${omfile_failed_counter[@]}";
			fi
			rm "$storage_path/omfile.failed.counter"
		fi
	fi
	declare -A mainQ_counter
	if [[ -f "$storage_path/mainQ.counter" ]] ; then
		mainQ_counter_total=$(wc -l "$storage_path/mainQ.counter" |awk '{print $1}')
		if [ $debug -eq 1 ] ; then echo "mainQ counter:$mainQ_counter_total"; fi
		if [ "$mainQ_counter_total" -gt 0 ] ; then
			for i in `seq 1 $mainQ_counter_total`; do
				name=$(cat "$storage_path/mainQ.counter" |awk -F ':' "NR==$i {print \$1}")
				mainQ_counter+=(["$name"]="$(cat "$storage_path/mainQ.counter" |awk -F ':' "NR==$i {print \$2}")")
			done
		fi
		if [ $debug -eq 1 ] ; then
			echo "  mainQ: ${!mainQ_counter[@]}";
			echo "counter: ${mainQ_counter[@]}";
		fi
		rm "$storage_path/mainQ.counter"
	fi
	if [ $omrelp_supervision -eq 1 ] ; then
		declare -A omrelp_failed_counter
		if [[ -f "$storage_path/omrelp.failed.counter" ]] ; then
			omrelp_failed_counter_total=$(wc -l "$storage_path/omrelp.failed.counter" |awk '{print $1}')
			if [ $debug -eq 1 ] ; then echo "omrelp counter:$omrelp_failed_counter_total"; fi
			if [ "$omrelp_failed_counter_total" -gt 0 ] ; then
				for i in `seq 1 $omrelp_failed_counter_total`; do
					name=$(cat "$storage_path/omrelp.failed.counter" |awk -F ':' "NR==$i {print \$1}")
					omrelp_failed_counter+=(["$name"]="$(cat "$storage_path/omrelp.failed.counter" |awk -F ':' "NR==$i {print \$2}")")
				done
			fi
			if [ $debug -eq 1 ] ; then
				echo " omrelp: ${!omrelp_failed_counter[@]}";
				echo "counter: ${omrelp_failed_counter[@]}";
			fi
			rm "$storage_path/omrelp.failed.counter"
		fi
	fi
else
	mkdir "$storage_path"
fi

#calculate the number of line of last segment
start_line=$(grep -n 'global: origin=dynstats' "$stats_path" |tail -n 1 |awk -F ':' '{print $1}')
total_lines=$(wc -l "$stats_path"|awk '{print $1}')
extracted_lines=$(($total_lines -$start_line +1))
tail -n "$extracted_lines" "$stats_path" > "$storage_path/stats.tmp"

###
#Verify DynaFiles stats
###

dynafile_total=$(grep 'dynafile' "$storage_path/stats.tmp" |wc -l)
if [ "$dynafile_total" -gt 0 ] ; then

	# search critics
	#extract last evicted and maxused files logs with dynaFiles
	declare -A dynafile_evicted
	declare -A dynafile_maxused
	for i in `seq 1 "$dynafile_total"`; do
		name=$(grep 'dynafile' "$storage_path/stats.tmp" |awk -F ' ' "NR==$i {print \$8}"| sed 's/://')
		dynafile_evicted+=(["$name"]="$(grep 'dynafile' "$storage_path/stats.tmp" |awk -F ' ' "NR==$i {print \$13}" |awk -F '=' '{print $2}')" )
		dynafile_maxused+=(["$name"]="$(grep 'dynafile' "$storage_path/stats.tmp" |awk -F ' ' "NR==$i {print \$14}" |awk -F '=' '{print $2}')" )
		#if not set counter (exemple: new dynafile template or first script execution)
		if [ -z ${dynafile_evicted_counter["$name"]} ] ; then
			dynafile_evicted_counter+=(["$name"]=0)
		fi
	done
	if [ $debug -eq 1 ] ; then
		echo "dynaFiles: ${!dynafile_evicted[@]}";
		echo "evicted: ${dynafile_evicted[@]}"; 
		echo "maxused: ${dynafile_maxused[@]}";
	fi
	for name in "${!dynafile_evicted[@]}"
	do
		# Warning if maxused pass 90% of dynaFileCacheSize
		if [ $((${dynafile_maxused[$name]} * 100 / $dynaFileCacheSize )) -ge $dynaFileCacheSize_warning ] ; then 
			if [ "$centreon_state" -lt 1 ] ; then centreon_state=1;	fi
			warn_info+=" dynafile $name maxused:${dynafile_maxused[$name]} soit $((${dynafile_maxused[$name]} * 100 / $dynaFileCacheSize ))%"
		fi
		# use Delta to detect evicted
		#test can be negative (if rsyslog restarted) or 0; if positive we have lost some log message
		#if [ $debug -eq 1 ] ; then echo "delta: $((${dynafile_evicted[$name]} - ${dynafile_evicted_counter[$name]} ))"; fi
		if [ "$((${dynafile_evicted[$name]} - ${dynafile_evicted_counter[$name]} ))" -gt 0 ] ; then
			if [ "$centreon_state" -lt 2 ] ; then centreon_state=2;	fi
			crit_info+=" dynafile $name have $((${dynafile_evicted[$name]} - ${dynafile_evicted_counter[$name]} )) new evicted";
		fi
	done
fi

###
# omfile stats
###
actions_total=$(grep 'omfile:' "$storage_path/stats.tmp" |wc -l)
if [ "$actions_total" -gt 0 ] ; then
	declare -A omfile_failed
	for i in `seq 1 "$actions_total"`; do
        name="$(grep 'omfile:' "$storage_path/stats.tmp" |awk -F ':' "NR==$i {print \$5}")"
        #if no description name set number for name
        if [ "$name" == "omfile" ] ; then name=$i ; fi
		omfile_failed+=(["$name"]="$(grep 'omfile:' "$storage_path/stats.tmp" |awk -F ' ' "NR==$i {print \$9}" |awk -F '=' '{print $2}')" )
		#if not set counter (exemple: new dynafile template or first script execution)
		if [ -z ${omfile_failed_counter["$name"]} ] ; then
			omfile_failed_counter+=(["$name"]=0)
		fi
	done
	if [ $debug -eq 1 ] ; then
		echo "omfile: ${!omfile_failed[@]}"
		echo "failed: ${omfile_failed[@]}"
	fi
	for name in "${!omfile_failed[@]}"
	do
		# use Delta to detect failed
		#test can be negative (if rsyslog restarted) or 0; if positive we have lost some log message
		if [ $((${omfile_failed[$name]} - ${omfile_failed_counter[$name]} )) -gt 0 ] ; then
			if [ "$centreon_state" -lt 2 ] ; then centreon_state=2;	fi
			crit_info+=" omfile $name have $((${omfile_failed[$name]} - ${omfile_failed_counter[$name]} )) new failed"
		fi
	done
fi


###
# omrelp stats
###
if [ $omrelp_supervision -eq 1 ] ; then
	relp_total=$(grep 'omrelp:' "$storage_path/stats.tmp" |wc -l)
	if [ "$relp_total" -gt 0 ] ; then
		declare -A omrelp_failed
		for i in `seq 1 "$relp_total"`; do
            name="$(grep 'omrelp:' "$storage_path/stats.tmp" |awk -F ':' "NR==$i {print \$5}")"
            #if no description name set number for name
            if [ "$name" == "omrelp" ] ; then name=$i ; fi
			omrelp_failed+=(["$name"]="$(grep 'omrelp:' "$storage_path/stats.tmp" |awk -F ' ' "NR==$i {print \$9}" |awk -F '=' '{print $2}')" )
			#if not set counter (exemple: new dynafile template or first script execution)
			if [ -z ${omrelp_failed_counter["$name"]} ] ; then
				omrelp_failed_counter+=(["$name"]=0)
			fi
		done
		if [ $debug -eq 1 ] ; then
			echo "omrelp: ${!omrelp_failed[@]}"
			echo "failed: ${omrelp_failed[@]}"
		fi
		for name in "${!omrelp_failed[@]}"
		do
			# use Delta to detect failed
			#test can be negative (if rsyslog restarted) or 0; if positive we have lost some log message
			if [ $((${omrelp_failed[$name]} - ${omrelp_failed_counter[$name]} )) -gt 0 ] ; then
				if [ "$centreon_state" -lt 2 ] ; then centreon_state=2;	fi
				crit_info+=" omrelp $name have $((${omrelp_failed[$name]} - ${omrelp_failed_counter[$name]} )) new failed"
			fi
		done
	fi
fi

###
# main Q
###
mainQ_total=$(grep 'main Q' "$storage_path/stats.tmp" |wc -l)
if [ "$mainQ_total" -eq 1 ] ; then
	declare -A mainQ=(["full"]="$(grep 'main Q' "$storage_path/stats.tmp" |awk -F ' ' '{print $11}' |awk -F '=' '{print $2}')" ["discarded_full"]="$(grep 'main Q' "$storage_path/stats.tmp" |awk -F ' ' '{print $12}' |awk -F '=' '{print $2}')" ["discarded_nf"]="$(grep 'main Q' "$storage_path/stats.tmp" |awk -F ' ' '{print $13}' |awk -F '=' '{print $2}')");
	if [ $debug -eq 1 ] ; then
		echo "mainQ: ${!mainQ[@]}";
		echo "value: ${mainQ[@]}";
	fi
	if [ -z "${mainQ_counter[full]}" ] ; then mainQ_counter+=(["full"]=0); fi
	if [ $((${mainQ["full"]} - ${mainQ_counter["full"]} )) -gt 0 ] ; then
		if [ "$centreon_state" -lt 1 ] ; then centreon_state=1; fi
		warn_info+=" mainQ was full $((${mainQ["full"]} - ${mainQ_counter["full"]} )) new times";
	fi
	if [ -z "${mainQ_counter[discarded_full]}" ] ; then mainQ_counter+=(["discarded_full"]=0); fi
	if [ $((${mainQ["discarded_full"]} - ${mainQ_counter["discarded_full"]} )) -gt 0 ] ; then
		if [ "$centreon_state" -lt 2 ] ; then centreon_state=2; fi
		crit_info+=" mainQ was full and discarded $((${mainQ["discarded_full"]} - ${mainQ_counter["discarded_full"]} )) new times";
	fi
	if [ -z "${mainQ_counter[discarded_nf]}" ] ; then mainQ_counter+=(["discarded_full"]=0); fi
	if [ "$((${mainQ["discarded_nf"]} - ${mainQ_counter["discarded_nf"]} ))" -gt 0 ] ; then
		if [ "$centreon_state" -lt 2 ] ; then centreon_state=2; fi
		crit_info+=" mainQ was nearly full and discarded $((${mainQ["discarded_nf"]} - ${mainQ_counter["discarded_nf"]} )) new times";
	fi
else
	if [ "$centreon_state" -lt 1 ] ; then centreon_state=3; fi
	unkown_info+=" detected main Q is not 1: $mainQ_total"
fi

if [ $debug -eq 1 ] ; then echo "centreon state returned: $centreon_state"; fi

###
# Counter Storage
###
if [ "$dynafile_total" -gt 0 ] ; then
	for i in "${!dynafile_evicted[@]}" ; do
		echo "$i:${dynafile_evicted[$i]}" >> "$storage_path/dynafile.evicted.counter"
	done
fi
if [ "$actions_total" -gt 0 ] ; then
	for i in "${!omfile_failed[@]}" ; do
		echo "$i:${omfile_failed[$i]}" >> "$storage_path/omfile.failed.counter"
	done
fi
if [ $omrelp_supervision -eq 1 ] ; then
	if [ "$relp_total" -gt 0 ] ; then
		for i in "${!omrelp_failed[@]}" ; do
			echo "$i:${omrelp_failed[$i]}" >> "$storage_path/omrelp.failed.counter"
		done
	fi
fi
if [ "$mainQ_total" -eq 1 ] ; then
	for i in "${!mainQ[@]}" ; do
		echo "$i:${mainQ[$i]}" >> "$storage_path/mainQ.counter"
	done
fi

###
#	Format information for centreon
###
perf=''
if [ "$dynafile_total" -gt 0 ] ; then
	perf='|';
	warning=$(($dynaFileCacheSize*$dynaFileCacheSize_warning/100))
	for name in "${!dynafile_evicted[@]}"
	do
		delta_evicted=$((${dynafile_evicted[$name]} - ${dynafile_evicted_counter[$name]} ))
		if [ "$delta_evicted" -lt 0 ] ; then delta_evicted = 0; fi
		perf+="$name.evicted=$delta_evicted;1;1;0;10000;  $name.maxused=${dynafile_maxused[$name]};$warning;$dynaFileCacheSize;0;$dynaFileCacheSize; "
	done
fi
if [ "$mainQ_total" -eq 1 ] ; then
	delta_full="$((${mainQ["full"]} - ${mainQ_counter["full"]} ))"
	delta_discarded_full="$((${mainQ["discarded_full"]} - ${mainQ_counter["discarded_full"]} ))"
	delta_discarded_nf="$((${mainQ["discarded_nf"]} - ${mainQ_counter["discarded_nf"]} ))"
	perf+="mainQ.full=$delta_full;1;1;0;100; mainQ.discarded.full=$delta_discarded_full;1;1;0;10000; mainQ.discarded.nf=$delta_discarded_nf;1;1;0;10000; ";
fi

resource_usage_total="$(grep 'resource-usage' "$storage_path/stats.tmp" |wc -l)"
if [ "$resource_usage_total" -eq 1 ] ; then
	open_files="$(grep 'resource-usage' "$storage_path/stats.tmp" |awk -F ' ' '{print $17}' |awk -F '=' '{print $2}')"
	perf+=" openfiles=$open_files;1500;3000;0;5000;"
else
	if [ "$centreon_state" -lt 1 ] ; then centreon_state=3; fi
	unkown_info+=" detected resource-usage is not 1: $resource_usage_total detected"
fi

case "$centreon_state" in
	0)
		echo "Rsyslog stats OK; $perf"
		;;
	1)
		echo "Warning: Rsyslog limits are almost reach ... $warn_info $unkown_info; $perf"
		;;
	2)
		echo "Critics: Rsyslog is overflow !$crit_info $warn_info $unkown_info; $perf"
		;;
	*)
		echo "Unknow state: $unkown_info; $perf"
		exit 3
		;;
esac
exit $centreon_state
