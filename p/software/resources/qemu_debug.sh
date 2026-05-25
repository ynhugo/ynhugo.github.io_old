linux="linux-4.4.232";
# linux="linux-4.4.76";
busybox="busybox-1.32.0";
uboot="u-boot-2017.05"
# uboot="u-boot-2020.07"
file_linux="${linux}.tar.xz";
file_busybox="${busybox}.tar.bz2";
file_uboot="${uboot}.tar.bz2"
work_dir_name="yenao_qemu_test";
work_dir="${HOME}/${work_dir_name}";
Operate_Net_File="/etc/network/interfaces"
uboot_config_file="${work_dir}/${uboot}/include/configs/vexpress_common.h"
mkdir -p ${work_dir};
cd ${work_dir};

sudo apt-get install gcc-arm-linux-gnueabi -y; # 该交叉编译工具链与 gcc-multilib 不能共存，因此如果电脑之前有安装并且需要 gcc-multilib 的话，可以再运行完脚本后重新安装 gcc-multilib
sudo apt-get install python-dev -y;
sudo apt-get install qemu qemu-kvm libvirt-bin bridge-utils virt-manager -y;
sudo apt-get install uml-utilities bridge-utils -y;
sudo apt-get install u-boot-tools -y;
sudo apt-get install ed -y;
sudo apt-get install tftp-hpa tftpd-hpa xinetd -y; sudo chmod 777 /etc/default/tftpd-hpa;
sudo apt-get install  nfs-kernel-server -y;
sudo apt install device-tree-compiler -y;

# 配置/etc/default/tftpd-hpa
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
if [ -f "${work_dir}/$file_linux" ]; then
	echo "$file_linux exists."
else
	# wget https://cdn.kernel.org/pub/linux/kernel/v4.x/${file_linux}
	# wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.232.tar.xz
	wget https://cdn.kernel.org/pub/linux/kernel/v4.x/${file_linux}
fi

# 判断busybox文件是否准备好
if [ -f "${work_dir}/$file_busybox" ]; then
	echo "$file_busybox exists."
else
	# wget https://busybox.net/downloads/busybox-1.32.0.tar.bz2
	wget https://busybox.net/downloads/${file_busybox}
fi

# 判断u-boot文件是否准备好
if [ -f "${work_dir}/$file_uboot" ]; then
	echo "$file_uboot exists."
else
	# wget https://ftp.denx.de/pub/u-boot/u-boot-2017.05.tar.bz2
	# wget https://ftp.denx.de/pub/u-boot/u-boot-2020.07.tar.bz2
	wget https://ftp.denx.de/pub/u-boot/${file_uboot}
fi

# 临时配置交叉编译环境
export ARCH=arm && export CROSS_COMPILE=arm-linux-gnueabi-;

# 判断linux内核是否解压
# kernel
if [ -d "${work_dir}/$linux" ]; then
	echo "$linux exists."
else
	tar xvf ${work_dir}/$file_linux -C ${work_dir};
fi

# 判断busybox文件是否解压
if [ -d "${work_dir}/$busybox" ]; then
	echo "$busybox exists."
else
	tar xvf ${work_dir}/$file_busybox -C ${work_dir};
fi

# 判断u-boot文件是否解压
if [ -d "${work_dir}/${uboot}" ]; then
	echo "$uboot exists."
else
	tar xvf ${work_dir}/$file_uboot -C ${work_dir};
	if [ -f "${work_dir}/${uboot}/include/configs/vexpress_common.h" ]; then
		cp ${uboot_config_file} ${uboot_config_file}.old
	fi
fi

cpu_cores=$(nproc)
jobs=$((cpu_cores * 2))

# 编译linux内核
cd  ${work_dir}/${linux};
make distclean -j${jobs};
make vexpress_defconfig -j${jobs};
make zImage -j${jobs};
make modules -j${jobs};
make LOADADDR=0x60003000 uImage -j${jobs};
make dtbs -j${jobs};
# mkimage -n 'mini2440' -A arm -O linux -T kernel -C none -a 0x30008000 -e 0x30008040 -d  ${work_dir}/$linux/arch/arm/boot/zImage  ${work_dir}/$linux/arch/arm/boot/uImage

# 编译busybox，编译之后把"${busybox}/_install/*"拷贝到rootfs目录下
cd  ${work_dir}/${busybox};
make distclean -j${jobs};
make defconfig -j${jobs};
make -j${jobs};
make install -j${jobs};

# 编译u-boot，编译之后会在${uboot}目录下出现u-boot，传真u-boot示例：sudo qemu-system-arm -M vexpress-a9 -m 256 -kernel ./u-boot -nographic
cd  ${work_dir}/${uboot};
make distclean -j${jobs};
make vexpress_ca9x4_defconfig -j${jobs};
make -j${jobs};

# 搭建网络开发环境
if [ -f "$Operate_Net_File.old" ]; then
	echo "$Operate_Net_File.old is exists."
else
	sudo cp $Operate_Net_File $Operate_Net_File.old
fi
result=$(cat /etc/network/interfaces | grep "br0")
if [ "$result" != "" ]; then
	echo "br0 exists."
else
	sudo chown ${USER}:${USER} $Operate_Net_File
	cat $Operate_Net_File > $Operate_Net_File
	result=$(ip addr | grep "ens33")
	if [ "$result" != "" ]; then
		echo "auto lo" >> $Operate_Net_File
		echo "iface lo inet loopback" >> $Operate_Net_File
		echo "" >> $Operate_Net_File
		echo "auto ens33" >> $Operate_Net_File
		echo "" >> $Operate_Net_File
		echo "auto br0" >> $Operate_Net_File
		echo "iface br0 inet dhcp" >> $Operate_Net_File
		echo "	bridge_ports ens33" >> $Operate_Net_File
		sudo chown ${root}:${root} $Operate_Net_File
		sudo /etc/init.d/networking restart
	else
		result=$(ip addr | grep "eth0")
		if [ "$result" != "" ]; then
			echo "auto lo" >> $Operate_Net_File
			echo "iface lo inet loopback" >> $Operate_Net_File
			echo "" >> $Operate_Net_File
			echo "auto eth0" >> $Operate_Net_File
			echo "" >> $Operate_Net_File
			echo "auto br0" >> $Operate_Net_File
			echo "iface br0 inet dhcp" >> $Operate_Net_File
			echo "	bridge_ports eth0" >> $Operate_Net_File
			sudo chown ${root}:${root} $Operate_Net_File
			sudo /etc/init.d/networking restart
		fi
	fi
fi
if [ $(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | grep ":") ]; then
	of_ip_var1=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr ':' ' ' | tr '.' ' ' | awk '{print $2}')
	of_ip_var2=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr ':' ' ' | tr '.' ' ' | awk '{print $3}')
	of_ip_var3=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr ':' ' ' | tr '.' ' ' | awk '{print $4}')
	of_ip_var4=$(ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr ':' ' ' | tr '.' ' ' | awk '{print $5}')
else
	of_ip_var1=$( ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr '.' ' ' | awk '{print $1}')
	of_ip_var2=$( ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr '.' ' ' | awk '{print $2}')
	of_ip_var3=$( ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr '.' ' ' | awk '{print $3}')
	of_ip_var4=$( ifconfig | grep -w -A 1 "br0" | grep -v "br0" | awk '{print $2}' | grep "[0-9]" | tr '.' ' ' | awk '{print $4}')
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

# 准备根文件系统
cd ${work_dir};
mkdir -p ${work_dir}/rootfs/{dev,etc/init.d,lib,mnt};
cp -avf ${work_dir}/${busybox}/_install/* ${work_dir}/rootfs/;
cp -avf /usr/arm-linux-gnueabi/lib/* ${work_dir}/rootfs/lib/;
cd ${work_dir}/rootfs/dev;
# 创建字符设备类型的设备节点，这些设备节点的主设备号为4,次设备号为1..11
sudo mknod -m 666 console c 4 1; sudo mknod -m 666 null c 4 2; sudo mknod -m 666 tty1 c 4 3; sudo mknod -m 666 tty2 c 4 4; sudo mknod -m 666 tty3 c 4 5; sudo mknod -m 666 tty4 c 4 6; sudo mknod -m 666 tty5 c 4 7; sudo mknod -m 666 tty6 c 4 8; sudo mknod -m 666 tty7 c 4 9; sudo mknod -m 666 tty8 c 4 10; sudo mknod -m 666 tty9 c 4 11;
# 在rootfs目录下准备挂载NFS脚本
touch ${work_dir}/rootfs/mountNFS.sh
cat mountNFS.sh > ${work_dir}/rootfs/mountNFS.sh
echo "ifconfig eth0 ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.223" >> ${work_dir}/rootfs/mountNFS.sh 
echo "mount -t nfs -o nolock ${of_ip_var1}.${of_ip_var2}.${of_ip_var3}.${of_ip_var4}:${work_dir} /mnt" >> ${work_dir}/rootfs/mountNFS.sh
# 进入qemu运行的虚拟机后通过以下命令运行脚本进行挂载nfs："sh mountNFS.sh"

cd ${work_dir};
# 制作rootfs.ext3，格式化rootfs.ext3为ext3文件系统类型，将rootfs.ext3挂载到/mnt，再将根文件系统拷贝到/mnt，然后解除/mnt挂载的rootfs.ext3，此时rootfs.ext3中已经有根文件系统了
dd if=/dev/zero of=rootfs.ext3 bs=1M count=32; mkfs.ext3 rootfs.ext3; sudo mount -t ext3 rootfs.ext3 /mnt -o loop; sudo cp -avf ${work_dir}/rootfs/* /mnt; sudo umount /mnt;

# tftpboot
# sudo chmod 775 $work_dir/$uboot/uImage;
sudo cp -avf ${work_dir}/${linux}/arch/arm/boot/zImage /tftpboot;
sudo cp -avf ${work_dir}/${linux}/arch/arm/boot/uImage /tftpboot;
sudo cp -avf ${work_dir}/${linux}/arch/arm/boot/dts/vexpress-v2p-ca9.dtb /tftpboot;
sudo cp -avf ${work_dir}/${uboot}/u-boot /tftpboot;
sudo cp -avf ${work_dir}/rootfs.ext3 /tftpboot;

# QEMU运行虚拟机，加载linux内核
# qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/$linux/arch/arm/boot/zImage -dtb ${work_dir}/$linux/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append "root=/dev/mmcblk0 rw console=ttyAMA0" -sd ${work_dir}/rootfs.ext3;

# 该命令使用 QEMU 模拟器运行 ARM 架构的虚拟机，并根据指定参数进行配置。下面是各个参数的含义：
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

# 在脚本外部执行，进入yenao_qemu_test目录执行下面的语句 
# qemu-system-arm -M vexpress-a9 -m 512M -kernel linux-4.4.232/arch/arm/boot/zImage -dtb linux-4.4.232/arch/arm/boot/dts/vexpress-v2p-ca9.dtb -nographic -append "root=/dev/mmcblk0 rw console=ttyAMA0" -sd rootfs.ext3

# QEMU运行虚拟机，只加载u-boot
# qemu-system-arm -M vexpress-a9 -m 256M -kernel ${work_dir}/${uboot}/u-boot  -nographic

# 通过 u-boot 加载内核
cd /tftpboot
sudo qemu-system-arm -M vexpress-a9 -kernel u-boot -nographic -m 128M -net nic,vlan=0 -net tap,vlan=0,ifname=tap0 -sd rootfs.ext3
