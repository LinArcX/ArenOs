# ArenOs
A minimal linux distribution based on suckless/openbsd/busybox ideas. it consists of:
- us: user-space applications including:
  init, login, lastlog, cat, etc..
- ks: linux kernel.
- cryptography: monocypher.

# How to build?
You can use `scc` as the c compiler and `musl` as c lib. there is a `build.sh` in the root of the project. just:
```
chmod +x build.sh
./build.sh
```

# Design decisions
- There is just one user. yes you are the ROOT! (no need for sudo, useradd, userdel, usermod, etc..)
- There is no concept of permission. (You are the owner of your computer, why you need to request with sude every fucking time?)
- Security concerns should handle by userspace applications/kernel.(not by creating permissions, groups.)
- There is no traditional file hierarchy. just these directories exists:
  - /dev
  - /info
  - /mnt
  - /pkgs
  - /proc
  - /sys
  - /tmp

- All applications(including kernel) will goes into /pkgs. there is no /bin, /sbin/, /run.
  - Each application will responsible to maintains his own configurations inside. (so no need for /etc)
  - There is no /lib directory. if you want to use a library, you should refer to it's package in /pkg.

## License
![License](https://img.shields.io/github/license/LinArcX/ArenOs.svg?style=flat-square)
