# 打开镜像选择界面
termux-change-repo

pkg update
pkg install -y termux-auth expect android-tools openssh

expect <<'EOF'
spawn passwd
expect "New password:" { send "..Qq1ssh..\r" }
expect "Retype new password:" { send "..Qq1ssh..\r" }
expect eof
EOF
