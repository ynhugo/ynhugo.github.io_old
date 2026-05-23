# coding: utf-8
#
import uiautomator2 as u2
import os
import time

# 连接手机adb
# connect='192.168.3.178:5555'
connect='192.168.1.102:5555'
d = u2.connect(connect)

# 清除app的数据
d.app_clear('com.termux')

# 直接通过包名打开app
d.app_start('com.termux')
time.sleep(1)
d(resourceId="com.termux:id/drawer_layout").click()

# 获取存储访问的权限
os.system(f'adb -s {connect} shell input text "termux-setup-storage"')
os.system(f'adb -s {connect} shell input keyevent 66')  # 发送回车键
# 弹窗请求允许，点击允许
d(resourceId="com.android.permissioncontroller:id/permission_allow_button").click()

# 拷贝脚本
os.system(f'adb -s {connect} push cfg.sh /storage/self/primary/Download/'),
time.sleep(1)
cmd = "cp -a storage\/shared\/Download\/cfg.sh ~/".replace(" ", "%s")
os.system(f'adb -s {connect} shell input text "{cmd}"')
os.system(f'adb -s {connect} shell input keyevent 66')  # 回车

# 运行脚本
cmd = "bash ~/cfg.sh".replace(" ", "%s")
os.system(f'adb -s {connect} shell input text "{cmd}"')
os.system(f'adb -s {connect} shell input keyevent 66')  # 回车

# 换源
# 模拟按键操作（需根据实际UI调整延迟）
# time.sleep(2)
os.system(f'adb -s {connect} shell input keyevent KEYCODE_SPACE')  # 全选
# time.sleep(2)
d.shell('input keyevent KEYCODE_ENTER')  # 确认
# time.sleep(2)
os.system(f'adb -s {connect} shell input keyevent KEYCODE_DPAD_DOWN 2')  # 选择中国镜像（按2次方向键下）
# time.sleep(2)
os.system(f'adb -s {connect} shell input keyevent KEYCODE_ENTER')  # 确认
time.sleep(30)
