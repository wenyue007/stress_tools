#! /bin/bash -
#Author: Jianwei.Hu@windriver.com
#Date: 1/10/2016

pre_path="/sys/fs/cgroup/systemd/system.slice/"
suf_path="/tasks"

[ $# -lt 2 -o $# -gt 3 ] && {
cat <<EOF
Usage: $0 process duration(minute) interval(second)
       eg: $0 systemd 5 10
EOF
exit 1;}

pname=$1
duration=$(($2 * 60 ))
interval=${3:-1}
[ $interval -gt $duration ]&& { echo -e "\033[31mThe interval should be less than duration.\033[0m"; exit 1; }

total_time=$duration
#total_times=$(($duration / $interval))
logfile=${pname}_${duration}_`date +%y_%m_%d_%H_%M`.log
touch $logfile

get_pid()
{
    pid=`systemctl status $pname| grep "Main PID"| awk -F" " '{print $3}'`
    [ -n "$pid" -a `ps -p $pid &>/dev/null;echo $?` -eq 1 ]&& { echo -e "\033[31mExited PID\033[0m"; exit 1; }
    [ -z "$pid" ]&& { pid=`pgrep -x $pname|head -1`; is_process=1; }
    [ -z "$pid" ]&& { echo -e "\033[31mCan not find active $pname service or process on current OS\033[0m"; exit 1; }
}

ppp=""
is_process=0
get_pid
index=1
index2=$(($interval*1000))
sum=0
max=0
times=1
time1=`date +%s%N`
echo "Waiting $interval s"
echo "Running..."

while [ $index -lt $total_time ]
do
   time3=`date +%s%N`
   temp=0
   temp_sum=0
   if [ $is_process -eq 1 ];then 
       top=`top -bn1 -p $pid|sed "/^$/d"|tail -1|grep $pid`
       [ -n "$top" ]&& { echo $top >> $logfile;
                         temp_sum=`cat $logfile |sed "/^$/d"|tail -1|grep $pid|awk -F" " '{print $9}'`; }||
                       temp_sum=0
   else
       ppp=${pre_path}${pname}.service${suf_path}
       for pids in `cat $ppp`
       do
           top=`top -bn1 -p $pids|sed "/^$/d"|tail -1|grep $pids`
           child_pid=`ps -e |awk -F" " '{print $1}' | grep $pids &>/dev/null;echo $?`
           lwp=`ps -eL |awk -F" " '{print $2}' | grep $pids &>/dev/null;echo $?`
           if [ -n "$top" ]; then
               [ "$child_pid" -eq 0 -a "$lwp" -eq 0 ] && { echo $top >> $logfile;
                              temp=`cat $logfile |sed "/^$/d"|tail -1|grep $pids|awk -F" " '{print $9}'`; } ||
                            temp=0
           else
               temp=0
           fi
           temp_sum=`echo $temp_sum $temp| awk '{print $1+$2}'` 
       done
   fi

   cpu=$temp_sum
   if [ -n "$cpu" ];then
       [ `echo "$max < $cpu" | bc` -eq 1 ] && max=${cpu}
   fi
   sum=`cat $logfile|awk -F" " '{sum+=$9}END{print sum}'`
   [ x"$sum" = x"0.0" -o x"$sum" = x"0" ]&& average=0 || average=`cat $logfile|awk -v t="$times" -F" " '{sum+=$9}END{print sum/t}'`
   time2=`date +%s%N`
   index1=$(($(($time2 - $time3))/1000000))

   good=`echo "$index1 < $index2" | bc`
   left_interval=`echo $index2 $index1 | awk '{print ($1-$2)/1000}'`
   [ "$good" -eq 1 ] && sleep $left_interval
   [ "$good" -eq 0 ] && sleep 0
   time8=`date +%s%N`
   index=$(($(($time8 - $time1))/1000000000))
   echo -e "\033[2J\033[0m" ;
   echo -e "\033[200A\033[0m"
   echo -e "\033[34m$pname's Main PID: $pid\033[0m"
   echo  "$pname's current %CPU MAX: ${max}%"
   echo  "${index}s, $pname current %CPU Average: ${average}%"
   echo  "Current sampling times: ${times}"
   echo  "P extra consumption: $index1 ms"
   echo -e "\033[34m$pname's child PID:\033[0m"
   [ -n "$ppp" ] && cat $ppp 2>/dev/null || echo $pid
   times=$(($times + 1))
done 

fin_times=$(($times -1))
average=`cat $logfile|awk -v times="$fin_times" -F" " '{sum+=$9}END{print sum/times}'`
sample=$fin_times
cat <<EOF >> $logfile
-------------------------------------------------------------------------
Brief Report:
Service/Process:${pname}
$pname's Main PID: $pid
Duration=${duration}s
Interval=${interval}s
Sampling times=${sample}
MAX=${max}%
Sum=$sum
Average=${average}%
EOF

echo -e "\033[34m--------------------------------------------\033[0m"
echo -e "\033[34mBrief Report:\033[0m"
echo -e "\033[34mService/Process:${pname}\033[0m"
echo -e "\033[34m$pname's Main PID: $pid\033[0m"
echo -e "\033[34mDuration=${duration}s\033[0m"
echo -e "\033[34mInterval=${interval}s\033[0m"
echo -e "\033[34mSampling times=${sample}\033[0m"
echo -e "\033[34mMAX=${max}%\033[0m"
echo -e "\033[34mAverage=${average}%\033[0m"
