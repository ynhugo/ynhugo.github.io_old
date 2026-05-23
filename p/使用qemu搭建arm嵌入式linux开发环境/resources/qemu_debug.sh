linux="linux-4.4.232";
# linux="linux-4.4.76";
busybox="busybox-1.32.0";
uboot="u-boot-2017.05"
# uboot="u-boot-2020.07"
vuboot="v2017.05"
git_uboot="v"
file_linux="${linux}.tar.xz";
file_busybox="${busybox}.tar.bz2";
file_uboot="${uboot}.tar.bz2"
file_vuboot="${vuboot}.tar.gz"
bz2_uboot="${file_uboot}"
gz_uboot="${file_vuboot}"
work_dir_name="yenao_qemu_test";
work_dir="${HOME}/${work_dir_name}";
Operate_Net_File="/etc/network/interfaces"
uboot_config_file="${work_dir}/${uboot}/include/configs/vexpress_common.h"
mkdir -p ${work_dir};
cd ${work_dir};
cpu_cores=$(nproc)
jobs=$((cpu_cores * 2))

package_array=(gcc-arm-linux-gnueabi  python-dev  qemu  qemu-kvm  libvirt-bin  bridge-utils  virt-manager  uml-utilities  bridge-utils  u-boot-tools  ed  tftp-hpa  tftpd-hpa  xinetd  nfs-kernel-server  device-tree-compiler) # gcc-arm-linux-gnueabi 交叉编译工具链与 gcc-multilib 不能共存，因此如果电脑之前有安装并且需要 gcc-multilib 的话，可以再运行完脚本后重新安装 gcc-multilib
package_array_size=${#package_array[@]}
for ((i = 0; i < package_array_size; i++))
do
	# 软件安装
	if [ ! "$(apt list --installed | grep -wo "${package_array[${i}]}" | head -n 1)" = "${package_array[${i}]}" ]; then
		echo -e "\e[34m"
		sudo apt-get install ${package_array[${i}]} -y
		echo -e "\e[0m"
		if [ ! "$(apt list --installed | grep -wo "${package_array[${i}]}" | head -n 1)" = "${package_array[${i}]}" ]; then
			echo -e "\e[31m${package_array[${i}]} 未安装\e[0m"
		else
			echo -e "\e[32m${package_array[${i}]} 已安装\e[0m"
		fi		  
	else
		echo -e "\e[32m${package_array[${i}]} 已安装\e[0m"
	fi
done	

# 配置/etc/default/tftpd-hpa
sudo chmod 777 /etc/default/tftpd-hpa;
cat /etc/default/tftpd-hpa > /etc/default/tftpd-hpa
sudo chown ${USER}:${USER} -R /etc/default/tftpd-hpa
echo 'TFTP_USERNAME="tftp"' >> /etc/default/tftpd-hpa
echo "TFTP_DIRECTORY=\"/tftpboot\"" >> /etc/default/tftpd-hpa
# echo "TFTP_DIRECTORY=\"/tftpboot /tftpboot/${work_dir_name}\"" >> /etc/default/tftpd-hpa
echo 'TFTP_ADDRESS="0.0.0.0:69"' >> /etc/default/tftpd-hpa
echo 'TFTP_OPTIONS="-l -c -s"' >> /etc/default/tftpd-hpa # 如果要设置多个目录就不能添加"-s"选项
# echo 'TFTP_OPTIONS="-l -c"' >> /etc/default/tftpd-hpa
sudo chown root:root -R /etc/default/tftpd-hpa
# 判断/tftpboot是否存在
if [ -d "/tftpboot/" ]; then
	echo "tftpboot exists.";
	tftpboot_access=$(stat /tftpboot/ | grep -w "Uid" | tr '(' ' ' | tr '/' ' ' | awk '{print $2}')
	if [ "$tftpboot_access" != "0777" ]; then
		sudo chmod 777 /tftpboot;
		echo "/tftpboot的权限已设置为0777"
	fi
else
	sudo mkdir /tftpboot;
	sudo chmod 777 /tftpboot;
	echo "/tftpboot的权限已设置为0777"
fi
# 判断/tftpboot/${work_dir_name}是否存在，想要配置多个文件夹的话可以取消注释
# if [ -d "/tftpboot/${work_dir_name}" ]; then
# 	echo "tftpboot/${work_dir_name} exists.";
# 	work_dir_name_access=$(stat /tftpboot/ | grep -w "Uid" | tr '(' ' ' | tr '/' ' ' | awk '{print $2}')
# 	if [ "$work_dir_name_access" != "0777" ]; then
# 		sudo chmod 777 /tftpboot/${work_dir_name};
# 		echo "/tftpboot/${work_dir_name}的权限已设置为0777"
# 	fi
# else
# 	sudo mkdir /tftpboot/${work_dir_name};
# 	sudo chmod 777 /tftpboot/${work_dir_name};
# 	echo "/tftpboot/${work_dir_name}的权限已设置为0777"
# fi

# 允许开发板通过NFS访问Ubuntu的/home/${USER}目录，当然你可以加其他目录
result=$(grep -w "${work_dir} \*(rw,nohide,insecure,no_subtree_check,async,no_root_squash)" /etc/exports | grep -v "#")

if [ $? -eq 0 ]; then
	# 查找并注释匹配行
	# sudo sed -i "s/${work_dir} \*(rw,nohide,insecure,no_subtree_check,async,no_root_squash)/#\/home\/${USER} \*(rw,nohide,insecure,no_subtree_check,async,no_root_squash)/g" /etc/exports
	# echo "已注释匹配行：$result"

	sudo /etc/init.d/nfs-kernel-server restart
	echo "匹配行已存在，并且重启了nfs服务"
else
	power=$(ls -l /etc/exports | awk '{print $4}')
	if [ "$power" == "root" ]; then
		sudo chown ${USER}:${USER} -R /etc/exports
		echo "${work_dir} *(rw,nohide,insecure,no_subtree_check,async,no_root_squash)" >> /etc/exports
		sudo chown root:root -R /etc/exports
	else
		echo "${work_dir} *(rw,nohide,insecure,no_subtree_check,async,no_root_squash)" >> /etc/exports
		sudo chown root:root -R /etc/exports
	fi
	sudo /etc/init.d/nfs-kernel-server restart
	echo "匹配行已添加，并且重启了nfs服务"
fi

# 判断linux内核是否准备好
while true;
do
	result=$(curl ipinfo.io | grep "country" | tr '"' ' ' | awk '{print $3}')
	if [ -z "${result}" ]; then
		continue
	else
		echo -e "\e[32mcountry: ${result}\e[0m"
		break
	fi
done

while true;
do
	if [ ! -f "${work_dir}/$file_linux" ]; then		  
		echo -e "\e[32m"
		if [ ${result} != "CN" ]; then				  
			# wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.232.tar.xz
			wget https://cdn.kernel.org/pub/linux/kernel/v4.x/${file_linux}
		else
			# wget https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v4.x/linux-4.4.232.tar.xz
			wget https://mirrors.ustc.edu.cn/kernel.org/linux/kernel/v4.x/${file_linux}
		fi
	else
		if [ "$(sha256sum ${file_linux})" != "4eae8865deaf03f0d13bf5056e258d451a468cabc5158757b247b0e43518fd34  ${file_linux}" ]; then
			rm -rf ${file_linux}
			continue
		else
			echo -e "\e[32m${file_linux} 已下载\e[0m"
			break;
		fi
	fi
	echo -e  "\e[0m"
done

# 判断busybox文件是否准备好
while true;
do
	if [ ! -f "${work_dir}/$file_busybox" ]; then
		echo -e  "\e[33m"
		# wget --no-check-certificate https://busybox.net/downloads/busybox-1.32.0.tar.bz2
		wget --no-check-certificate https://busybox.net/downloads/${file_busybox}
		echo -e  "\e[0m"
	else
		if [ "$(sha256sum ${file_busybox})" != "c35d87f1d04b2b153d33c275c2632e40d388a88f19a9e71727e0bbbff51fe689  ${file_busybox}" ]; then
			rm -rf ${file_busybo}
			continue
		else
			echo -e "\e[32m$file_busybox 已下载\e[0m"
			break;
		fi
	fi	  	  
done

# 判断u-boot文件是否准备好
while true;
do
	result=$(curl ipinfo.io | grep "country" | tr '"' ' ' | awk '{print $3}')
	if [ -z "${result}" ]; then
		continue
	else
		echo -e "\e[32mcountry: ${result}\e[0m"
		break
	fi
done

file_uboot=${file_vuboot}
# echo "https://codeload.github.com/u-boot/u-boot/tar.gz/refs/tags/v2017.05" | awk -F '/' '{print $5"-"$9"."$6}' | tr -d 'v'

while true;
do
	if [ ! -f "${work_dir}/$file_uboot" ]; then
		echo -e  "\e[34m"
		if [ ${result} != "CN" ]; then
			# wget --no-check-certificate https://ftp.denx.de/pub/u-boot/u-boot-2017.05.tar.bz2 
			# wget --no-check-certificate https://ftp.denx.de/pub/u-boot/u-boot-2020.07.tar.bz2
			# wget --no-check-certificate https://ftp.denx.de/pub/u-boot/${file_uboot}
			# wget https://github.com/u-boot/u-boot/archive/refs/tags/v2017.05.tar.gz
			wget  https://github.com/u-boot/u-boot/archive/refs/tags/${file_uboot}
		else
			wget https://hub.nuaa.cf/u-boot/u-boot/archive/refs/tags/${file_uboot}
		fi

	else
		if [ "$(sha256sum ${file_uboot})" != "0f94a62c460fc136aeca9bcd9fde3bb1d3f25b953e1bee96be4497a06a39ae81  ${file_uboot}" ]; then
			rm -rf ${file_uboot}
			continue
		else
			echo -e "\e[32m$file_uboot 已下载\e[0m"
			break
		fi
	fi
	echo -e  "\e[0m"
done  

# 临时配置交叉编译环境
export ARCH=arm && export CROSS_COMPILE=arm-linux-gnueabi-;

# 判断linux内核是否解压
echo -e  "\e[32m"
# kernel
if [ -d "${work_dir}/$linux" ]; then
	echo "$linux exists."
else
	tar xvf ${work_dir}/$file_linux -C ${work_dir};
fi
echo -e  "\e[0m"

# 判断busybox文件是否解压
echo -e  "\e[33m"
if [ -d "${work_dir}/$busybox" ]; then
	echo "$busybox exists."
else
	tar xvf ${work_dir}/$file_busybox -C ${work_dir};
fi
echo -e  "\e[0m"

# 判断u-boot文件是否解压
echo -e "\e[34m"
if [ -d "${work_dir}/${uboot}" ]; then
	echo "$uboot exists."
else
	if [ -f "${bz2_uboot}"  ]; then
		tar xvf ${work_dir}/$file_uboot -C ${work_dir};
		if [ -f "${work_dir}/${uboot}/include/configs/vexpress_common.h" ]; then
			cp ${uboot_config_file} ${uboot_config_file}.old
		fi
	elif [ -f "${gz_uboot}" ]; then
		tar zxvf ${work_dir}/$file_uboot -C ${work_dir};
		if [ -f "${work_dir}/${uboot}/include/configs/vexpress_common.h" ]; then
			cp ${uboot_config_file} ${uboot_config_file}.old
		fi
	fi
	echo -e "\e[0m"
fi

# 编译linux内核
echo -e  "\e[32m"
cd  ${work_dir}/${linux};
make distclean -j${jobs};
make vexpress_defconfig -j${jobs};
make zImage -j${jobs};
make modules -j${jobs};
make LOADADDR=0x60003000 uImage -j${jobs};
make dtbs -j${jobs};
# mkimage -n 'mini2440' -A arm -O linux -T kernel -C none -a 0x30008000 -e 0x30008040 -d  ${work_dir}/$linux/arch/arm/boot/zImage  ${work_dir}/$linux/arch/arm/boot/uImage
echo -e  "\e[0m"

# 编译busybox，编译之后把"${busybox}/_install/*"拷贝到rootfs目录下
echo -e  "\e[33m"
cd  ${work_dir}/${busybox};
make distclean -j${jobs};
make defconfig -j${jobs};
make -j${jobs};
make install -j${jobs};
echo -e  "\e[0m"

# 搭建网络开发环境
echo -e  "\e[95m"

if [ ! -f "$Operate_Net_File" ]; then
	sudo touch ${Operate_Net_File}
else
	echo "${uboot_config_file} is exists."
	if [ ! -f "$Operate_Net_File.old" ]; then
		sudo cp ${Operate_Net_File} {$Operate_Net_File}.old
	else
		echo "${Operate_Net_File}.old is exists."
	fi
fi

sudo chown ${USER}:${USER} ${Operate_Net_File}
if [ ! "$(cat /etc/network/interfaces | grep -o "br0" | head -n 1)" = "br0" ]; then
	echo "debug_1"
	cat ${Operate_Net_File} > ${Operate_Net_File}
	if [ "$(ip addr | grep -o "ens33" | head -n 1)" = "ens33" ]; then
		echo "auto lo" >> ${Operate_Net_File}
		echo "iface lo inet loopback" >> ${Operate_Net_File}
		echo "" >> ${Operate_Net_File}
		echo "auto ens33" >> ${Operate_Net_File}
		echo "" >> ${Operate_Net_File}
		echo "auto br0" >> ${Operate_Net_File}
		echo "iface br0 inet dhcp" >> ${Operate_Net_File}
		echo "	bridge_ports ens33" >> ${Operate_Net_File}
		sudo chown ${root}:${root} ${Operate_Net_File}
		sudo /etc/init.d/networking restart
	else
		if [ "$(ip addr | grep -o "eth0")" = "eth0" ]; then
			echo "auto lo" >> ${Operate_Net_File}
			echo "iface lo inet loopback" >> ${Operate_Net_File}
			echo "" >> ${Operate_Net_File}
			echo "auto eth0" >> ${Operate_Net_File}
			echo "" >> ${Operate_Net_File}
			echo "auto br0" >> ${Operate_Net_File}
			echo "iface br0 inet dhcp" >> ${Operate_Net_File}
			echo "	bridge_ports eth0" >> ${Operate_Net_File}			  
			sudo /etc/init.d/networking restart
		fi
	fi
else
	echo "br0 exists."
fi  

if [ "$(ifconfig | grep -wo "br0")" = "br0" ]; then
	of_ip_var1=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '$1=="inet" {print $2}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | awk -F '.' '{print $1}'); echo ${of_ip_var1} 
	of_ip_var2=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '$1=="inet" {print $2}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | awk -F '.' '{print $2}'); echo ${of_ip_var2} 
	of_ip_var3=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '$1=="inet" {print $2}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | awk -F '.' '{print $3}'); echo ${of_ip_var3} 
	of_ip_var4=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '$1=="inet" {print $2}' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | awk -F '.' '{print $4}'); echo ${of_ip_var4} 
else
	echo "The br0 not exists."
fi
sudo chown ${USER}:${USER} ${Operate_Net_File}

if [ ! -f "${uboot_config_file}.old" ]; then
	cp ${uboot_config_file} ${uboot_config_file}.old
else
	cat ${uboot_config_file}.old >  ${uboot_config_file}
fi

uboot_config_file_var1=$(grep -n "\/\* Basic environment settings \*\/" ${uboot_config_file}.old | tr ':' ' ' | awk '{print $1}')
uboot_config_file_var2=$((uboot_config_file_var1 + 1))
cat ${uboot_config_file}.old > ${uboot_config_file}
sed -i '/CONFIG_BOOTCOMMAND\b/d' ${uboot_config_file}
sed -i '/run distro_bootcmd\b/d' ${uboot_config_file}
sed -i '/run bootflash\b/d' ${uboot_config_file}
sed -i  "${uboot_config_file_var2}i\#define CONFIG_SERVERIP ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.${of_ip_var4}" ${uboot_config_file}
sed -i  "${uboot_config_file_var2}i\#define CONFIG_NETMASK 255.255.255.0" ${uboot_config_file}
sed -i  "${uboot_config_file_var2}i\#define CONFIG_IPADDR ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.223" ${uboot_config_file}
sed -i  "${uboot_config_file_var2}i\/* netmask */" ${uboot_config_file}
sed -i  "${uboot_config_file_var2}i\#define CONFIG_BOOTCOMMAND \"tftp 0x60003000 uImage;tftp 0x60500000 vexpress-v2p-ca9.dtb;setenv bootargs 'root=/dev/mmcblk0 console=ttyAMA0';bootm 0x60003000 - 0x60500000;\" \\" ${uboot_config_file}
echo -e  "\e[0m"

# 编译u-boot，编译之后会在${uboot}目录下出现u-boot，传真u-boot示例：sudo qemu-system-arm -M vexpress-a9 -m 256 -kernel ./u-boot -nographic
echo -e  "\e[34m"
cd  ${work_dir}/${uboot};
make distclean -j${jobs};
make vexpress_ca9x4_defconfig -j${jobs};
make -j${jobs};
echo -e  "\e[0m"

# 准备根文件系统
echo -e  "\e[33m"
cd ${work_dir};
mkdir -p ${work_dir}/rootfs/{dev,etc/init.d,lib,mnt};
sudo cp -vrf ${work_dir}/${busybox}/_install/* ${work_dir}/rootfs/;
sudo cp -vrf /usr/arm-linux-gnueabi/lib/* ${work_dir}/rootfs/lib/;
cd ${work_dir}/rootfs/dev;
# 创建字符设备类型的设备节点，这些设备节点的主设备号为4,次设备号为1..11
sudo mknod -m 666 console c 4 1;
sudo mknod -m 666 null c 4 2;
sudo mknod -m 666 tty1 c 4 3;
sudo mknod -m 666 tty2 c 4 4;
sudo mknod -m 666 tty3 c 4 5;
sudo mknod -m 666 tty4 c 4 6;
sudo mknod -m 666 tty5 c 4 7;
sudo mknod -m 666 tty6 c 4 8;
sudo mknod -m 666 tty7 c 4 9;
sudo mknod -m 666 tty8 c 4 10;
sudo mknod -m 666 tty9 c 4 11;

# 在rootfs目录下准备挂载NFS脚本
sudo touch ${work_dir}/rootfs/mountNFS.sh
sudo chown ${USER}:${USER} ${work_dir}/rootfs/mountNFS.sh
cat ${work_dir}/rootfs/mountNFS.sh > ${work_dir}/rootfs/mountNFS.sh
echo "ifconfig eth0 ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.223" >> ${work_dir}/rootfs/mountNFS.sh 
echo "mount -t nfs -o nolock ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.${of_ip_var4}:${work_dir} /mnt" >> ${work_dir}/rootfs/mountNFS.sh
sudo chown ${root}:${root} ${work_dir}/rootfs/mountNFS.sh
# 进入qemu运行的虚拟机后通过以下命令运行脚本进行挂载nfs："sh mountNFS.sh"

cd ${work_dir};
# 制作rootfs.ext3，格式化rootfs.ext3为ext3文件系统类型，将rootfs.ext3挂载到/mnt，再将根文件系统拷贝到/mnt，然后解除/mnt挂载的rootfs.ext3，此时rootfs.ext3中已经有根文件系统了
sudo dd if=/dev/zero of=rootfs.ext3 bs=1M count=32
sudo mkfs.ext3 rootfs.ext3
sudo mount -t ext3 rootfs.ext3 /mnt -o loop
sudo cp -vrf ${work_dir}/rootfs/* /mnt
sudo umount /mnt
echo -e  "\e[0m"

# tftpboot
echo -e  "\e[96m"
# sudo chmod 775 $work_dir/$uboot/uImage;
sudo rm -rf /tftpboot/*  
sudo cp -f ${work_dir}/${linux}/arch/arm/boot/zImage /tftpboot;
sudo cp -f ${work_dir}/${linux}/arch/arm/boot/uImage /tftpboot;
sudo cp -f ${work_dir}/${linux}/arch/arm/boot/dts/vexpress-v2p-ca9.dtb /tftpboot;
sudo cp -f ${work_dir}/${uboot}/u-boot /tftpboot;
sudo cp -f ${work_dir}/rootfs.ext3 /tftpboot;
echo -e  "\e[0m"

# QEMU运行虚拟机，通过sd卡加载linux内核
echo -e  "\e[92m"
# qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/$linux/arch/arm/boot/zImage -dtb ${work_dir}/$linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append "root=/dev/mmcblk0 rw console=ttyAMA0" -sd ${work_dir}/rootfs.ext3;

# 在脚本外部执行，进入yenao_qemu_test目录执行下面的语句 
# qemu-system-arm -M vexpress-a9 -m 512M -kernel linux-4.4.232/arch/arm/boot/zImage -dtb linux-4.4.232/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append "root=/dev/mmcblk0 rw console=ttyAMA0" -sd rootfs.ext3

# QEMU运行虚拟机，只加载u-boot
# qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/${uboot}/u-boot  -nographic

# 通过 u-boot 加载内核
# cd /tftpboot
# sudo qemu-system-arm -M vexpress-a9 -kernel u-boot -nographic -m 128M -net nic,vlan=0 -net tap,vlan=0,ifname=tap0 -sd rootfs.ext3

if [ "$1" = "sd" ]; then
	# QEMU运行虚拟机，通过sd卡加载linux内核	  
	sudo qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/$linux/arch/arm/boot/zImage -dtb ${work_dir}/$linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append "root=/dev/mmcblk0 rw console=ttyAMA0" -sd ${work_dir}/rootfs.ext3;	  
elif [ "$1" = "u-boot" ]; then
	cd /tftpboot
	sudo qemu-system-arm -M vexpress-a9 -kernel u-boot -nographic -m 128M -net nic,vlan=0 -net tap,vlan=0,ifname=tap0 -sd rootfs.ext3
elif [ "$1" = "help" ]; then
	echo "sd start: ${cmdself} sd"
	echo "u-boot start: ${cmdself} u-boot"
	echo "out sd start var: ${cmdself} out sd"
	echo "out u-boot start var: ${cmdself} out u-boot"
elif [ "$1" = "out" ] && [ "$2" = "sd" ]; then
	echo " qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/$linux/arch/arm/boot/zImage -dtb ${work_dir}/$linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append \"root=/dev/mmcblk0 rw console=ttyAMA0\" -sd ${work_dir}/rootfs.ext3;"
elif [ "$1" = "out" ] && [ "$2" = "u-boot" ]; then
	echo "sudo qemu-system-arm -M vexpress-a9 -kernel u-boot -nographic -m 128M -net nic,vlan=0 -net tap,vlan=0,ifname=tap0 -sd rootfs.ext3"
else
	# 默认通过u-boot加载linux内核
	cd /tftpboot
	sudo qemu-system-arm -M vexpress-a9 -kernel u-boot -nographic -m 128M -net nic,vlan=0 -net tap,vlan=0,ifname=tap0 -sd rootfs.ext3
fi
echo -e  "\e[0m"
# 部分参数说明
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | 参数                                                           | 含义                                                                                 |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | M vexpress-a9`                                                 | 指定虚拟机的机型为 `vexpress-a9`，即使用 ARMv7 架构的 Versatile Express 开发板模型。 |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | m 512M`                                                        | 设置虚拟机的内存大小为 512MB。                                                       |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | kernel ${work_dir}/$linux/arch/arm/boot/zImage`                | 指定 Linux 内核镜像的路径和文件名。                                                  |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | dtb ${work_dir}/$linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb` | 指定设备树二进制文件（Device Tree Blob）的路径和文件名。                             |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | nographic`                                                     | 以无图形界面的方式运行虚拟机。                                                       |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | append "root=/dev/mmcblk0 rw console=ttyAMA0"`                 | 指定 Linux 内核启动参数，包括根文件系统的设备路径、读写权限和控制台终端。            |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
# | sd ${work_dir}/rootfs.ext3`                                    | 指定虚拟机的根文件系统镜像路径和文件名。                                             |
# |----------------------------------------------------------------+--------------------------------------------------------------------------------------|
