#! /bin/sh -
#Author: Jianwei.Hu@windriver.com
#Date:1/21/2016

rr=`tty`
rr=`basename $rr`
if [[ $rr = tty[0-7] ]]; then
    :
elif [[ $rr = ttyS[0-3] ]]; then
    :
else
    echo -e "\033[31mPleasse run $0 on local TTY\033[0m" 
    exit 1
fi
[ $# -ne 1 ] && { echo "Usage: $0 [wan|wlan|lan|wwan]"; exit 1; }

dmesg -n 1
rm -rf npipe*
mkfifo -m 777 npipe1
mkfifo -m 777 npipe2
mkfifo -m 777 npipe3
mkfifo -m 777 npipe4

nic_up_time()
{ 
    #wan/wwan/wlan/lan
    if=$1
    cmd1="ifdown"
    cmd2="ifup"
    case $if in
        wan) iff="eth0" ;;
       wwan) iff="3g-wwan" ;;
       wlan) iff="wlan0" ;;
        lan) iff="br-lan" ;;
          *) { echo -e "\033[31mIncorrect logical interface name\033[0m";exit 1;} 
    esac
    [ `ifstatus $if &> /dev/null; echo $?` -ne 0 ]&& { echo -e "\033[31mUn-existing interface $if\033[0m";exit 1;}
    echo -e "\033[34mTry to down $if interface firstly...\033[0m"
    $cmd1 $if 
    if_status=`ifstatus $if| grep up| awk -F": " '{print $2}'| awk -F"," '{print $1}'`
    while [ x$if_status != xfalse ]
    do
        sleep 0.5
        if_status=`ifstatus $if| grep up| awk -F": " '{print $2}'| awk -F"," '{print $1}'`
    done
    [ x$if_status = xfalse ]  && echo -e "\033[32mSuccess to down $if\033[0m" || echo -e "\033[31mFail to down $if\033[0m"
    echo -e "\033[34mTry to up $if interface...\033[0m"
    time1=`date +%s%N`
    time2=$time1
    time_up=$time1
    time_running=$time1
    $cmd2 $if

    (if_up=`ifconfig $iff 2> /dev/null| grep UP &> /dev/null; echo $?`
    [ "$if_up" -eq 0 ] &&time_up=`date +%s%N`
    echo $time_up > npipe1 &
    echo $if_up > npipe3 &)

    (if_running=`ifconfig $iff 2> /dev/null| grep RUNNING &> /dev/null; echo $?`
    [ "$if_running" -eq 0 ] && time_running=`date +%s%N`
    echo $time_running > npipe2 &
    echo $if_running > npipe4 &)
    
    ip_addr=`ip ad show $iff 2> /dev/null| grep -w inet| awk -F" " '{print $2}'|cut -d"/" -f 1`
    [ -n "$ip_addr" ] &&time2=`date +%s%N`

    read time_up < npipe1
    read time_running < npipe2
    read if_up < npipe3
    read if_running < npipe4
    kkk=0

    while [ -z "$ip_addr" -o "$if_running" -ne 0 -o "$if_up" -ne 0 ]
    do
        sleep 0.01
        (if_up=`ifconfig $iff 2>/dev/null| grep UP &> /dev/null; echo $?`
        [ "$if_up" -ne 0 ] &&time_up=`date +%s%N`
        echo $time_up > npipe1 &
        echo $if_up > npipe3 &)

        (if_running=`ifconfig $iff 2> /dev/null| grep RUNNING &> /dev/null; echo $?`
        [ "$if_running" -ne 0 ] && time_running=`date +%s%N`
        echo $time_running > npipe2 &
        echo $if_running > npipe4 &)

        read time_up < npipe1
        read time_running < npipe2
        read if_up < npipe3
        read if_running < npipe4

        ip_addr=`ip ad show $iff 2> /dev/null| grep -w inet| awk -F" " '{print $2}'|cut -d"/" -f 1`
        time2=`date +%s%N`
        [ -z "$ip_addr" ] &&time2=`date +%s%N`

        kkk=$(($kkk + 1)) 
        [ $kkk -gt 600 ]&& { 
                            [ "$if_up" -ne 0 ] && { echo -e "\033[31mInactivated NIC\033[0m";time_up=$time1; } 
                            [ "$if_running" -ne 0 ] && { echo -e "\033[31mNo link detected\033[0m";time_running=$time1; } 
                            [ -z "$ip_addr" ]&& { echo -e "\033[31mNo ip found\033[0m"; time2=$time1; }
                            break; }
    done 
    time_upp=$(($time_up-$time1))
    time_runningg=$(($time_running-$time1))
    time=$(($time2-$time1))
    echo "_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+_+"
    echo "Got \"UP\" time     : $(($time_upp/1000000)) ms"
    echo "Got \"RUNNING\" time: $(($time_runningg/1000000)) ms"
    echo "Got \"IP addr\" time: $(($time/1000000)) ms"
    echo "Got \"IP addr\" time: $(($time/1000000000)) s"
}

nic_up_time $1

echo "Done"
dmesg -n 8
rm -rf npipe*
