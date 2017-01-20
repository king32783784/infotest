#!/usr/bin/bash
##############################################################
# Author : peng.li@i-soft.com.cn                            ##
# usage: To detect system and hardware platform information ##
# Date : 2017.1.18                                          ##
##############################################################

REPORT="info.html"

usage()
{   
    cat <<-EOF >&2

    usage: ${0##*/} [ -t TEST TYPE ] [ -o OS TYPE ]
    
    -t TESTTYPE Test type support : ALL|HW|SW
                                    ALL include HW and SW
                                    HW:MB/BIOS/CPU/MEM/NB/SB/GRAPHIC/AUDIO/LAN/WLAN/SATA/HDD/ODD/RAID/BLUE/
                                    KB/MS/USB
                                    SW:OS/KERNEL/FS/GCC/GLIBC/LLVM/QT/XORG/MESA/JAVA/CHORMIUM/FIREFOX/SWAP

    -h help
    -v version
   example: ${0##*/} -t "ALL"
EOF
exit 0
}

while getopts "t:o:hv" arg 
do
        case $arg in
             t)
                 TESTTYPE=($OPTARG) # 测试类型
                 if [ ${#TESTTYPE[@]} -gt 1 ]
                 then
                     echo " -d:Error You can specify only one test type !"
                     exit 1
                 elif [ ${#TESTTYPE[@]} -eq 0 ]
                 then
                     TYPE="ALL"
                 else
                     TYPE=${TESTTYPE[0]}   
                 fi
                 ;;
             h)
                 usage
                 ;;
             v)
                 echo "infotest-v1.0"
                 exit 1
                 ;;
             ?)
                 echo "unkonw argument"
                 usage
                 exit 1
               ;;
             esac
done

#####################################################################################
# 硬件信息抓取                                                                     ##
# 包括info_cpu、info_mb、info_bios、info_mem、info_northbridge、info_sorthbridge   ##
# info_graphic、info_audio、info_lan、info_wlan、info_sata、info_odd、info_raid    ##
# info_bluetooth、info_keyboard、info_mouse、info_usb                              ##
#####################################################################################

# 处理器信息
info_cpu()
{
    if [ -e /proc/cpuinfo ]
    then
        if cat /proc/cpuinfo | grep -i 'model name' >/dev/null 2>&1
        then 
            cpuinfo=`cat /proc/cpuinfo | grep -i 'model name'| awk -F: '{print $2}'| sort | uniq | tr -d "\n"`
        elif cat /proc/cpuinfo | grep -i 'model' >/dev/null 2>&1
        then
            cpuinfo=`cat /proc/cpuinfo | grep -i 'model'| awk -F: '{print $2}'| sort | uniq | tr -d "\n"`
        fi
        cpucores=`cat /proc/cpuinfo | grep processor | wc -l`
        echo -e "型号:$cpuinfo \\n 核数: $cpucores "
    else
        echo "unknow"
    fi
}

# 主板信息
info_mb()
{
    if [ -e /proc/boardinfo ] 
    then
        MBINFO=`cat /proc/boardinfo | grep -i "board name" |awk '{print $4}'`
        echo "$MBINFO"
    elif dmidecode -t system | grep -i System >/dev/null 2>&1; then
        MBVR=`dmidecode -t system | grep -i Manufacturer | awk '{print $2}' | head -n 1`
        MBIF=`dmidecode -t system | grep -i "Product Name" | awk '{$1 = ""; $2 = "" ; print }'`
        MBINFO="$MBVR -$MBIF"
        echo "$MBINFO"
    else
        echo "unknow" 
    fi
}

# BIOS信息
info_bios()
{
    if [ -e /proc/boardinfo ]
    then
        BIOSINFO=`cat /proc/boardinfo | awk '$1=="Version" {print $3}'`
        echo "$BIOSINFO"
    elif dmidecode -t bios | grep Version >/dev/null 2>&1; then
        BIOSVR=`dmidecode -t bios | grep -i vendor | awk '{print $2}'`
        BIOSVE=`dmidecode -t bios | grep -i version | awk '{print $2}'`
        BIOSDT=`dmidecode -t bios | grep -i "release date:" | awk '{print $3}'`
        echo "$BIOSVR-$BIOSVE-$BIOSDT"
    else
        echo "unknow"
    fi
}

# 内存信息
info_mem()
{
    if dmidecode -t memory >/dev/null 2>&1
    then
        MEMTYPE=`dmidecode -t memory | grep -w DDR[0-9] | uniq | awk '{print $2}'`
        MEMSPEED=`dmidecode -t memory | grep -w "Speed:" | grep -w MHz | grep -v "Clock Speed" | sort|uniq | awk '{print $2,$3}'
`
        MEMSIZE=`dmidecode -t memory  | grep -w "Size:" | grep "MB" | grep -v "Maximum" | grep -v "Connection" | awk '{print $2,$3}' | sort | uniq`
        MEMNUM=`dmidecode -t memory | grep "Rank: 1" | wc -l`
        if [ $MEMNUM -ge 1 ];then
            MEMNAME=`dmidecode -t memory | grep Manufacturer: | grep -v "Empty" | sort | uniq | awk '{print $2}'`
            NAMENUM=`echo $MEMNAME | awk '{print NF}'`
            if [ $NAMENUM -eq 1 ];then
                echo "$MEMNAME-$MEMTYPE-$MEMSPEED-$MEMSIZE*$MEMNUM"
            else
                OLD_IFS="$IFS"
                IFS=' '
                arr=($MEMNAME)
                IFS="$OLD_IFS"
                for s in ${arr[@]}
                do
                    echo "$s-$MEMTYPE-$MEMSPEED-$MEMSIZE"
                done
            fi
        fi
    else
        MEMSIZE=`free -m | grep -w "Mem:" | awk '{print $2}'`
        MEM=`echo "$MEMSIZE/1024 + 1" | bc`
        echo "$MEM GB" 
    fi
} 

# North bridge信息
info_northbridge()
{
    if lspci | grep "00:00.0"| awk -F: '{print $3}' >/dev/null 2>&1
    then
        HOST=`lspci |grep "00:00.0"|awk -F: '{print $3}'`
        echo "$HOST"
    else
        echo "unknow"
    fi
}

# Sorth bridge信息 
info_sorthbridge()
{
    if lspci |grep "ISA bridge:"|awk -F: '{print $3}' >/dev/null 2>&1
    then
        SB=`lspci |grep "ISA bridge:"|awk -F: '{print $3}' | sed s/"LPC"/""/ | sed s/"host"/""/ | sed s/"[C|c]ontroller"/""/`
        echo "$SB"
    else
        echo "unknow"
    fi
}

# 显卡信息
info_graphic()
{
    if lspci | grep "VGA" > /dev/null 2>&1
    then
        VGANO=`lspci | grep "VGA" | awk -F: '{print $3}' | wc -l`
        num=1
        while [ $num -le $VGANO ]
        do
            CARD=`lspci | grep "VGA"| awk -F: '{print $3}' | head -n $num | tail -n 1`
            echo "$CARD"
            num=$(($num + 1))
        done
    fi
    if lspci | grep "Display controller:" > /dev/null 2>&1
    then
        CARD=`lspci |grep "Display"| awk -F: '{print $3}'`
        echo "$CARD"
    fi
}

# 声卡信息
info_audio()
{
    lspci |grep "Audio" >> /dev/null
    if [ "$?" -eq 0 ]
    then
        AUDNO=`lspci |grep "Audio"|awk -F: '{print $3}' |wc -l`
        num=1
        while [ $num -le $AUDNO ]
        do
            AUDCARD=`lspci |grep "Audio"|awk -F: '{print $3}' | head -n $num | tail -n 1`
            echo "$AUDCARD"
            num=$(($num + 1))
        done
    else
        echo "unknow"
    fi
}

# 网卡信息
info_lan()
{
    lspci |grep -E 'Network|Ethernet' >> /dev/null
    if [ "$?" -eq 0 ]
    then
        NETNO=`lspci |grep -E 'Network|Ethernet' | grep -v "Wireless" |awk -F: '{print $3}' |wc -l`
        num=1
        while [ $num -le $NETNO ]
        do
            NET=`lspci |grep -E 'Network|Ethernet' | grep -v "Wireless" | awk -F: '{print $3}' | head -n $num | tail -n 1`
            echo "$NET"
            num=$(($num + 1))
        done
    else
        echo "unknow"
    fi 
}

# 无线网卡信息
info_wlan()
{
    lspci | grep "Wireless" >> /dev/null
    if [ $? -eq 0 ]
    then 
         WLAN=`lspci | grep "Wireless" | awk -F: '{print $3}'`
         echo "$WLAN"
    else
        echo "unknow"
    fi
}


# SATA控制器
info_sata()
{
    lspci |grep SATA >> /dev/null
    if [ "$?" -eq 0 ]
    then
        SATANO=`lspci |grep SATA |awk -F: '{print $3}' |wc -l`
        num=1
        while [ $num -le $SATANO ]
        do
            SATA=`lspci |grep SATA | awk -F: '{print $3}' | head -n $num | tail -n 1`
            echo "$SATA"
            num=$(($num + 1))
        done
    else
        echo "unknow"
    fi
}

# 硬盘信息
info_hdd()
{
if cat /proc/scsi/scsi | grep ATA >/dev/null 2>&1;then
    HDDNUM=`cat /proc/scsi/scsi |grep ATA | wc -l`
    num=1
    while [ $num -le $HDDNUM ]
    do
        HDDTYPE=`cat /proc/scsi/scsi |grep ATA | awk -F: '{print $3}' | tr -d "Rev" | head -n $num | tail -n 1`
        echo "$HDDTYPE"
        num=$(($num + 1))
        done
elif cat /proc/scsi/scsi | grep "Vendor" >/dev/null 2>&1;then
    HDDNUM=`cat /proc/scsi/scsi | grep -E "Vendor" |  sed -n '/Vendor/,/Rev/p' |wc -l`
    num=1
    while [ $num -le $HDDNUM ]
    do
        HDDTYPE=`cat /proc/scsi/scsi | grep -E "Vendor" | grep -v 'DVD'| awk -F: '{print $3}' | tr -d "Rev" | head -n $num | tail -n 1`
        num=$(($num + 1))
        echo "$HDDTYPE"
    done
else
    echo "unknow"
fi
}

# ODD信息
info_odd()
{
    if cat /proc/scsi/scsi | grep -E "Vendor"  | grep -E "DVD|CD" | awk  '{print $2,$4,$5}' >/dev/null 2>&1
    then
        ODD=`cat /proc/scsi/scsi | grep -E "Vendor"  | grep -E "DVD|CD" | awk  '{print $2,$4,$5}'`
        echo "$ODD"
    else
        echo "unknow"
    fi
}
# RAID
info_raid()
{
    if lspci | grep RAID >/dev/null;then
        RAIDNO=`lspci | grep -i raid |wc -l`
        N=1
        while [ $N -le $RAIDNO ]
        do
            RAIDINFO=`lspci |grep -i 'RAID'|awk -F: '{print $3}' | head -n $N | tail -n 1`
            echo "$RAIDINFO"
            N=$(($N + 1))
        done
    else
        echo "unknow"
    fi
}

# 蓝牙信息
info_bluetooth()
{
    dmesg | grep -i bluetooth >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        BLUE=`dmesg | grep -i bluetooth | grep -v initialized | awk -F: '{print $2}' | tr -d "\n"`
        echo "$BLUE"
    else
        echo "unknow" 
    fi
}

# 键盘信息
info_keyboard()
{
    cat /proc/bus/input/devices  | grep -i keyboard | grep Name >>/dev/null
    if [ $? -eq 0 ]
    then
        KB=`cat /proc/bus/input/devices  | grep -v Virtual| grep -i keyboard | grep Name |uniq | awk -F= '{print $2}'`
        echo "$KB"
    else
        echo "unknow"
    fi
}

# 鼠标信息()
info_mouse()
{
    cat /proc/bus/input/devices  | grep -i mouse | grep Name >>/dev/null
    if [ $? -eq 0 ]
        then
        MS=`cat /proc/bus/input/devices  | grep -v Virtual| grep -i mouse | grep Name |uniq | awk -F= '{print $2}'`
        echo "$MS"
    else
        echo "unknow"
    fi
}

# USB设备信息
info_usb()
{
    ls /proc/scsi/usb-storage/ >>/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        usbno=`ls /proc/scsi/usb-storage/ |wc -l`
        i=1
        while [ $i -le $usbno ]
        do  
            scsino=`ls /proc/scsi/usb-storage | awk '{print $1}' |head -n $i| tail -n 1`
            usbVendor=`cat /proc/scsi/usb-storage/$scsino | awk '$1=="Vendor:" {print $2}'`
            if [ "$usbVendor" = "Unknown" ];then
                echo "unknow " 
            else
            usbProduct=`cat /proc/scsi/usb-storage/$scsino | grep "Product:"| awk -F: '{print $2}'`
            echo "$usbVendor-$usbProduct"
            fi
            i=$(($i + 1))
        done
    else
        echo "unknow"
    fi
}

# 全部硬件信息

hw_all()
{
    info_cpu
    info_mb
    info_bios
    info_mem
    info_northbridge
    info_sorthbridge
    info_graphic
    info_audio
    info_lan
    info_wlan
    info_sata
    info_odd
    info_raid
    info_bluetooth
    info_keyboard
    info_mouse
    info_usb
}

#####################################################################################################
# 软件信息抓取　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　　 ##
# 软件信息抓取包括：info_os/info_kernel/info_fs/info_gcc/info_glibc/info_env/info_qt/              ##
#                   info_xorg/info_mesa/info_java/info_browser/info_nbdriver/info_sbdriver/        ##
#                   info_gfcdriver/info_audiodriver/info_landriver/info_wlandriver/info_raidriver/ ##
#####################################################################################################

# 系统版本信息
info_os()
{
    if cat /etc/issue | head -n 1 | tr -d '\\' > /dev/null 2>&1
    then
        OSINFO=`cat /etc/issue | head -n 1`
        echo "$OSINFO"
    else
        echo "unknow"
    fi
}

# 内核版本信息
info_kernel()
{
    if uname -a | awk '{print $3}' >/dev/null 2>&1
    then
        KERNEL=`uname -a | awk '{print $3}'`
        echo "$KERNEL"
    else
        echo "unknow"
    fi
}

# 文件系统信息
info_fs()
{
    if df -T | awk '{if ($7 == "/") {print $2} else if($6 == "/") {print $1}}' >/dev/null 2>&1
    then
        FSINFO=`df -T | awk '{if ($7 == "/") {print $2} else if ($6 == "/") {print $1}}'`
        echo "$FSINFO"
    else
        echo "unknow"
    fi
}

# gcc版本信息
info_gcc()
{
    if gcc -dumpversion >/dev/null 2>&1
    then
        GCCINFO=`gcc -dumpversion 2>&1`
        echo "$GCCINFO"
    else
        echo "unknow"
    fi
}

# Glibc版本信息

info_glibc()
{
    if ls -l `ldd /bin/sh | awk '/libc/{print $3}'` | sed -e 's/\.so$//' | awk -F'[.-]' '{print "" $(NF-2)"."$(NF-1)"."$NF}' >/dev/null 2>&1
    then
       LDD=`ldd /bin/sh | awk '/libc/{print $3}'`
       LIBC=`ls -l $LDD | sed -e 's/\.so$//' | awk -F'[.-]'   '{print "" $(NF-2)"."$(NF-1)"."$NF}'`
       echo "$LIBC"
    else
       echo "unknow"
    fi
}
        
# 桌面环境()
info_env()
{
    if gnome-shell --version >/dev/null 2>&1;then
        DTENV=`gnome-shell --version 2>/dev/null`
        echo "$DTENV"
    elif gnome-about --version >/dev/null 2>&1;then
        DTENV=`gnome-about --version 2> /dev/null`
        echo "$DTENV"
    elif gnome-session --version > /dev/null 2>&1;then
        DTENV=`gnome-session --version >/dev/null 2>&1`
        echo "$DTENV"
    elif unity --version > /dev/null 2>&1;then
        DTENV=`unity --version 2> /dev/null`
        echo "$DTENV"
    elif mate-about --version >/dev/null 2>&1;then
        DTENV=`mate-about --version 2> /dev/null`
        echo "$DTENV"
    elif plasmashell -v >/dev/null 2>&1;then
        DTENV=`plasmashell -v 2> /dev/null`
        echo "KDE-$DTENV"
    else
        echo "unknow"
    fi
}

# QT版本信息
info_qt()
{
    if qmake-qt5 -v >/dev/null 2>&1;then
        QTINFO=`qmake-qt5 -v | tail -n 1 | awk '{print $4}'`
        echo "$QTINFO"
    elif qmake-qt4 -v >/dev/null 2>&1;then
        QTINFO=`qmake-qt4 -v | tail -n 1 | awk '{print $4}'`
        echo "$QTINFO"
    else
        echo "unknow"
    fi
}

# xorg版本信息
info_xorg()
{
    if cat /var/log/Xorg.0.log | grep -w "X.Org X Server" >/dev/null 2>&1
    then
        XORG=`cat /var/log/Xorg.0.log | grep -w "X.Org X Server"`
        echo "$XORG"
    else
        echo "unknow"
    fi
}

# Mesa版本信息

info_mesa()
{
   if dnf info mesa-dri-drivers | grep "版本" | awk -F: '{print $2}' >/dev/null 2>&1
   then
      MESA=`dnf info mesa-dri-drivers | grep "版本" | awk -F: '{print $2}'`
      echo "$MESA"
   elif rpm -qa | grep mesa-libgbm | awk -F- '{print $3}' >/dev/null 2>&1
   then
      MESA=`rpm -qa | grep mesa-libgbm | awk -F- '{print $3}'`
      echo "$MESA"
   else
      echo "unknow"
   fi
}

# Java版本信息
info_java()
{
    if java -version >/dev/null 2>&1
    then
        JAVA=`java -version 2>&1 | head -n 1`
        echo "$JAVA"
    else
        echo "unknow"
    fi
}

# 浏览器版本信息
info_browser()
{
   if google-chrome -v >/dev/null 2>&1;then
       CHROME="TRUE"
   elif chromium-browser -version --user-data-dir "/tmp" >/dev/null 2>&1;then
       CHROME="TRUE"
   else
       CHROME="FALSE"
   fi
   if firefox -v >/dev/null 2>&1;then
       FIREFOX="TRUE"
   else
       FIREFOX="FALSE"
   fi
   if [[ $CHROME = "TRUE" && $FIREFOX = "TRUE" ]]
   then
       if google-chrome -v >/dev/null 2>&1;then
           BROSERA=`goole-chrome -v 2>/dev/null`
           echo "Chrome-$BROSERA"
       elif chromium-browser -version --user-data-dir "/tmp" >/dev/null 2>&1;then
           BROSERA=`chromium-browser -version --user-data-dir "/tmp" 2>/dev/null`
           echo "Chrome-$BROSERA"
       fi
       BROSERB=`firefox -v 2>/dev/null`
       echo "firefox-$BROSERB"
   elif [ $CHROME = "TRUE" ];then
       BROSERA=`goole-chrome -v 2>/dev/null`
       echo "chrome-$BROSERA"
   elif [ $FIREFOX = "TRUE" ]; then
       BROSERB=`firefox -v 2>/dev/null`
       echo "firefox-$BROSERB"
   else
       echo "unknow"
   fi
}

info_nbdriver()
{
    if lspci |grep "00:00.0"|awk -F: '{print $3}' >/dev/null 2>&1
    then
        DRIVER=`lspci -v | sed -n -e '/00:00.0/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
        echo "$DRIVER"
    else
        echo "unknow"
    fi
}

# sorth bridge 驱动信息
info_sbdriver()
{
    if lspci |grep "ISA bridge:"|awk -F: '{print $3}' >/dev/null 2>&1
    then
        IRQ=`lspci |grep "ISA bridge:"|awk '{print $1}'`
        DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
        echo "$DRIVER"
    else
        echo "$DRIER"
    fi
}

#显卡驱动
info_gfcdriver()
{
    if lspci | grep "VGA" > /dev/null 2>&1
    then
        VGANO=`lspci | grep "VGA" | awk -F: '{print $3}' | wc -l`
        num=1
        while [ $num -le $VGANO ]
        do
            CARD=`lspci | grep "VGA"| awk -F: '{print $3}' | head -n $num | tail -n 1`
            IRQ=`lspci |grep "VGA"|awk '{print $1}' | head -n $num | tail -n 1`
            DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
            echo "$DRIVER"
            num=$(($num + 1))
        done
    fi
    if lspci | grep "Display controller:" > /dev/null 2>&1
    then
        CARD=`lspci |grep "Display"| awk -F: '{print $3}'`
        IRQ=`lspci | grep "Display" | awk '{print $1}' | tail -n 1`
        DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
        echo "$DRIVER"
    fi
}

# 声卡驱动

info_audiodriver()
{
    lspci |grep "Audio" >> /dev/null
    if [ "$?" -eq 0 ]
    then
        AUDNO=`lspci |grep "Audio"|awk -F: '{print $3}' |wc -l`
        num=1
        while [ $num -le $AUDNO ]
        do
            AUDCARD=`lspci |grep "Audio"|awk -F: '{print $3}' | head -n $num | tail -n 1`
            IRQ=`lspci |grep "Audio"|awk '{print $1}' | head -n $num | tail -n 1`
            DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
            echo "$DRIVER"
            num=$(($num + 1))
        done
    else
        echo "unknow"
    fi
}

# 网卡驱动

info_landriver()
{
    lspci |grep -E 'Network|Ethernet' >> /dev/null
    if [ "$?" -eq 0 ]
    then
        NETNO=`lspci |grep -E 'Network|Ethernet' | grep -v "Wireless" |awk -F: '{print $3}' |wc -l`
        num=1
        while [ $num -le $NETNO ]
        do
            NET=`lspci |grep -E 'Network|Ethernet' | grep -v "Wireless" | awk -F: '{print $3}' | head -n $num | tail -n 1`
            IRQ=`lspci |grep -E 'Network|Ethernet' | awk '{print $1}' | head -n $num | tail -n 1`
            DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'` 
            echo "$DRIVER"
            num=$(($num + 1))
        done
    else
        echo "unknow"
    fi
}

# 无线网卡驱动

info_wlandriver()
{
    lspci |grep "Wireless" >> /dev/null
    if [ $? -eq 0 ]
    then 
         WLAN=`lspci | grep "Wireless" | awk -F: '{print $3}'`
         IRQ=`lspci | grep "Wireless" | awk '{print $1}'`
         WLANDRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
         echo "$WLANDRIVER"
    else
        echo "unknow"
    fi
}

# RAID卡驱动
info_raidriver()
{
    if lspci | grep RAID >/dev/null;then
        RAIDNO=`lspci | grep -i raid |wc -l`
        N=1
        while [ $N -le $RAIDNO ]
        do
            RAIDINFO=`lspci |grep -i 'RAID'|awk -F: '{print $3}' | head -n $N | tail -n 1`
            IRQ=`lspci |grep -i 'RAID'|awk '{print $1}' | head -n $N | tail -n 1`
            DRIVER=`lspci -v | sed -n -e '/'$IRQ'/,/Kernel/p' | grep "driver" | awk '{print $NF}'`
            echo "$DRIVER"
            N=$(($N + 1))
        done
    else
        echo "unknow"
    fi
}

sw_all()
{
    info_os
    info_kernel
    info_fs
    info_gcc
    info_glibc
    info_env
    info_qt
    info_xorg
    info_mesa
    info_java
    info_browser
    info_nbdriver
    info_sbdriver
    info_gfcdriver
    info_audiodriver
    info_landriver
    info_wlandriver
    info_raidriver
}


# CSS样式及html头部

html_head()
{
echo "<HTML>
<HEAD>
<style>
.titulo{font-size: 1em; color: white; background:#0863CE; padding: 0.1em 0.2em;}
table
{
border-collapse:collapse;
border="1" width="50%";
}
table, td, th
{
border:1px solid black;
}
html{text-align:center;}
</style>
<meta http-equiv='Content-Type' content='text/html; charset=UTF-8' />
</HEAD>
<BODY align=center>" > $REPORT

HOST=$(hostname)
echo "<strong>系统信息</strong><br><br>
<strong>时间：$(date)</strong><br><br>

</tr>" >> $REPORT
}

html_font()
{
    echo "</table></BODY></HTML>" >> $REPORT
}

html_hw()
{
# 表头
echo "</table>

<br>
<br>

<table border='1'>
<table align=center>
<tr>
<th class='titulo'> 硬件类型</td>
<th class='titulo'> 信息内容 </td>
</tr>" >> $REPORT

# 处理器
echo "<tr><td align='center'>" >> $REPORT
echo -e "处理器" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
CPU=$(info_cpu)
echo "$CPU" >> $REPORT
echo "</td></tr>" >> $REPORT

# 主板
echo "<tr><td align='center'>" >> $REPORT
echo -e "主板" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
MB=$(info_mb)
echo "$MB" >> $REPORT
echo "</td></tr>" >> $REPORT

# BIOS
echo "<tr><td align='center'>" >> $REPORT
echo -e "BIOS" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
BIOS=$(info_bios)
echo "$BIOS" >> $REPORT
echo "</td></tr>" >> $REPORT

# 内存
echo "<tr><td align='center'>" >> $REPORT
echo -e "内存" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
MEM=$(info_mem)
echo "$MEM" >> $REPORT
echo "</td></tr>" >> $REPORT

# 北桥
echo "<tr><td align='center'>" >> $REPORT
echo -e "北桥" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
NORTH=$(info_northbridge)
echo "$NORTH" >> $REPORT
echo "</td></tr>" >> $REPORT

# 南桥
echo "<tr><td align='center'>" >> $REPORT
echo -e "南桥" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
SORTH=$(info_sorthbridge)
echo "$SORTH" >> $REPORT
echo "</td></tr>" >> $REPORT

# 显卡
echo "<tr><td align='center'>" >> $REPORT
echo -e "显卡" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
GFC=$(info_graphic)
echo "$GFC" >> $REPORT
echo "</td></tr>" >> $REPORT

# 声卡
echo "<tr><td align='center'>" >> $REPORT
echo -e "声卡" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
AUDIO=$(info_audio)
echo "$AUDIO" >> $REPORT
echo "</td></tr>" >> $REPORT

# 网卡
echo "<tr><td align='center'>" >> $REPORT
echo -e "网卡" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
NET=$(info_lan)
echo "$NET" >> $REPORT
echo "</td></tr>" >> $REPORT

# 无线网卡
echo "<tr><td align='center'>" >> $REPORT
echo -e "无线网卡" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
WLAN=$(info_wlan)
echo "$WLAN" >> $REPORT
echo "</td></tr>" >> $REPORT


# SATA控制器
echo "<tr><td align='center'>" >> $REPORT
echo -e "SATA控制器" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
SATA=$(info_sata)
echo "$SATA" >> $REPORT
echo "</td></tr>" >> $REPORT

# 硬盘信息
echo "<tr><td align='center'>" >> $REPORT
echo -e "硬盘" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
HDD=$(info_hdd)
echo "$HDD" >> $REPORT
echo "</td></tr>" >> $REPORT

#光驱
echo "<tr><td align='center'>" >> $REPORT
echo -e "光驱" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
ODD=$(info_odd)
echo "$ODD" >> $REPORT
echo "</td></tr>" >> $REPORT

# RAID
echo "<tr><td align='center'>" >> $REPORT
echo -e "RAID" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
RAID=$(info_raid)
echo "$RAID" >> $REPORT
echo "</td></tr>" >> $REPORT

# 蓝牙信息
echo "<tr><td align='center'>" >> $REPORT
echo -e "蓝牙" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
BLUE=$(info_bluetooth )
echo "$BLUE" >> $REPORT
echo "</td></tr>" >> $REPORT 

# 键盘
echo "<tr><td align='center'>" >> $REPORT
echo -e "键盘" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
KB=$(info_keyboard)
echo "$KB" >> $REPORT
echo "</td></tr>" >> $REPORT

# 鼠标
echo "<tr><td align='center'>" >> $REPORT
echo -e "鼠标" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
MS=$(info_mouse)
echo "$MS" >> $REPORT
echo "</td></tr>" >> $REPORT

# USB
echo "<tr><td align='center'>" >> $REPORT
echo -e "USB设备" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
USB=$(info_usb)
echo "$USB" >> $REPORT
echo "</td></tr>" >> $REPORT
}

html_sw()
{
echo "</table>

<br>
<br>

<table border='1'>
<table align=center>
<tr>
<th class='titulo'> 软件类别</td>
<th class='titulo'> 信息内容 </td>
</tr>" >> $REPORT

# 系统版本
echo "<tr><td align='center'>" >> $REPORT
echo -e "系统版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
OS=$(info_os)
echo "$OS" >> $REPORT
echo "</td></tr>" >> $REPORT

# 内核版本
echo "<tr><td align='center'>" >> $REPORT
echo -e "内核版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
KERNEL=$(info_kernel)
echo "$KERNEL" >> $REPORT
echo "</td></tr>" >> $REPORT

# 文件系统类型
echo "<tr><td align='center'>" >> $REPORT
echo -e "文件系统类型" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
FS=$(info_fs)
echo "$FS" >> $REPORT
echo "</td></tr>" >> $REPORT

#GCC版本
echo "<tr><td align='center'>" >> $REPORT
echo -e "GCC版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
GCC=$(info_gcc)
echo "$GCC" >> $REPORT
echo "</td></tr>" >> $REPORT

# Glibc版本
echo "<tr><td align='center'>" >> $REPORT
echo -e "Glibc库版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
GLIBC=$(info_glibc)
echo "$GLIBC" >> $REPORT
echo "</td></tr>" >> $REPORT

# 桌面管理器
echo "<tr><td align='center'>" >> $REPORT
echo -e "桌面管理器" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
ENV=$(info_env)
echo "$ENV" >> $REPORT
echo "</td></tr>" >> $REPORT

# QT版本
echo "<tr><td align='center'>" >> $REPORT
echo -e "QT版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
QT=$(info_fs)
echo "$QT" >> $REPORT
echo "</td></tr>" >> $REPORT

# XORG
echo "<tr><td align='center'>" >> $REPORT
echo -e "XORG版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
XORG=$(info_xorg)
echo "$XORG" >> $REPORT
echo "</td></tr>" >> $REPORT

# mesa
echo "<tr><td align='center'>" >> $REPORT
echo -e "MESA版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
MESA=$(info_fs)
echo "$MESA" >> $REPORT
echo "</td></tr>" >> $REPORT

# java
echo "<tr><td align='center'>" >> $REPORT
echo -e "JAVA版本" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
JAVA=$(info_java)
echo "$JAVA" >> $REPORT
echo "</td></tr>" >> $REPORT

#　浏览器
echo "<tr><td align='center'>" >> $REPORT
echo -e "浏览器信息" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
BROWSER=$(info_browser)
echo "$BROWSER" >> $REPORT
echo "</td></tr>" >> $REPORT

#　北桥驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "北桥驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
NBDRIVER=$(info_nbdriver)
echo "$NBDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# 南桥驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "南桥驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
SBDRIVER=$(info_sbdriver)
echo "$SBDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# 显卡驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "显卡驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
GFCDRIVER=$(info_gfcdriver)
echo "$GFCDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# 声卡驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "声卡驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
AUDIODRIVER=$(info_audiodriver)
echo "$AUDIODRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# 网卡驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "网卡驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
LANDRIVER=$(info_landriver)
echo "$LANDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# 无线网卡驱动
echo "<tr><td align='center'>" >> $REPORT
echo -e "无线网卡驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
WLANDRIVER=$(info_wlandriver)
echo "$WLANDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT

# RAID
echo "<tr><td align='center'>" >> $REPORT
echo -e "RAID驱动" >> $REPORT
echo "</td><td align='center'>" >> $REPORT
RAIDDRIVER=$(info_raidriver)
echo "$RAIDDRIVER" >> $REPORT
echo "</td></tr>" >> $REPORT
}

make_html_all()
{
    html_head
    html_hw
    html_sw
    html_font
}

make_html_hw()
{
html_head
html_hw
html_font
mv $REPORT hw_info.html
}

make_html_sw()
{
html_head
html_sw
html_font
mv $REPORT sw_info.html
}

main()
{
    if [ $TYPE == "ALL" ] 2>/dev/null;then
        make_html_all
    elif [ $TYPE == "HW" ] 2>/dev/null; then
        make_html_hw
    elif [ $TYPE == "SW" ] 2>/dev/null; then
        make_html_sw
    else
       usage
    fi
}
        
main
