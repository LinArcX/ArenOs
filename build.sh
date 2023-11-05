#!/bin/bash

# Depenendencies
#   build.sh:
#     bash
#     curl
#     gnupg2
#   Linux:
#     bc
#     openssl-devel

# Define colors using ANSI escape codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'  # No Color (to reset the color)

DOWNLOADER=curl

LINUX_VERSION=6.6
LINUX_MAJOR_VERSION=$(echo $LINUX_VERSION | grep -o '^[0-9]*' | cut -d$'\n' -f1)
LINUX_SRC_URL=https://mirrors.edge.kernel.org/pub/linux/kernel/v$LINUX_MAJOR_VERSION.x/linux-$LINUX_VERSION.tar.xz
LINUX_SIG_URL=https://mirrors.edge.kernel.org/pub/linux/kernel/v$LINUX_MAJOR_VERSION.x/linux-$LINUX_VERSION.tar.sign

BUSYBOX_VERSION=1.36.1
BUSYBOX_SRC_URL=https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
BUSYBOX_SIG_URL=https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2.sig
BUSYBOX_SHA256_URL=https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2.sha256

build_src_output_dir() {
  echo -e "\n${GREEN}>>> Creating src/ and output/ directories.${NC}"
  mkdir -p src
  mkdir -p output
}

check_url() {
  URL="$1"
  response=$($DOWNLOADER --head --silent --output /dev/null --write-out "%{http_code}" "$URL")
  
  if [ "$response" = "200" ]; then
    return 0
  else
    return 1
  fi
}

extract_build_linux() {
  # To reduce compile time during linux compilation:
  # - only use features/modules that your system really need. disable all other modules/features.
  #
  # To reduce cpu usage during linux compilation:
  # - Use Fewer Cores by specifying less cores(-j). maybe half of your cores are enough.
  # - Use ccache: This way, repeated compilations only need to compile changed portions, reducing overall CPU usage
  # - Nice and Ionice: Prioritize the process using nice and ionice commands. nice adjusts the process priority, and ionice assigns I/O priority. For example, you could use nice -n 19 make -j4 to lower the priority of the compilation.
  echo -e "\n${GREEN}>>> Extracting linux-$LINUX_VERSION.tar.xz into src/ ...${NC}"
  tar -xvf linux-$LINUX_VERSION.tar -C .

  echo -e "\n${GREEN}>>> Building linux-$LINUX_VERSION ...${NC}"
  cd linux-$LINUX_VERSION 
    make defconfig
    time make -j"$(($(nproc) / 2))" && echo -e "\n${GREEN}>>> linux-${LINUX_VERSION} successfully built.${NC}" || echo -e "\n${RED}!!! linux-${LINUX_VERSION} build failed!${NC}" && exit
  cd ..
}

verify_linux_signature() {
  echo -e "\n${GREEN}>>> Import keys belonging to Linus Torvalds and Greg Kroah-Hartman.(Linux developers)${NC}"
  gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org

  echo -e "\n${GREEN}>>> Trust keys belonging Greg Kroah-Hartman.(Linux developer)${NC}"
  gpg2 --tofu-policy good 38DBBDC86092693E

  echo -e "\n${GREEN}>>> Downloading signature ...${NC}"
  $DOWNLOADER -o linux-$LINUX_VERSION.tar.sign $LINUX_SIG_URL

  echo -e "\n${GREEN}>>> Verifing signature ...${NC}"
  if [ -f "linux-$LINUX_VERSION.tar.xz" ]; then
    unxz linux-$LINUX_VERSION.tar.xz
  fi
  gpg --trust-model tofu --verify linux-$LINUX_VERSION.tar.sign linux-$LINUX_VERSION.tar

  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}>>> linux-$LINUX_VERSION.tar.sign is valid.${NC}"
    return 0
  else
    echo -e "\n${RED}!!! linux-$LINUX_VERSION.tar.sign is invalid!${NC}"
    return 1
  fi
}

download_extract_build_linux() {
  cd src/

  if [ -f "linux-$LINUX_VERSION.tar" ]; then
    if verify_linux_signature; then
      extract_build_linux
      return 0
    else
      echo -e "\n${RED}!!! Signature verification failed: linux-${LINUX_VERSION}.tar${NC}"
      return 1
    fi
  else
    if check_url $LINUX_SRC_URL; then
      echo -e "\n${GREEN}>>> linux-${LINUX_VERSION}.tar.xz URL is valid.${NC}"

      echo -e "\n${GREEN}>>> Downloading linux-$LINUX_VERSION.tar.xz ...${NC}"
      $DOWNLOADER -o linux-$LINUX_VERSION.tar.xz $LINUX_SRC_URL

      if verify_linux_signature; then
        extract_build_linux
        return 0
      else
        echo -e "\n${RED}!!! Signature verification failed: linux-${LINUX_VERSION}.tar${NC}"
        return 1
      fi
    else
      echo -e "\n${RED}!!! linux-${LINUX_VERSION}.tar.xz URL is not valid.${NC}"
      return 2
    fi
  fi

  cd ..
}

extract_build_busybox() {
  echo -e "\n${GREEN}>>> Extracting busybox-$BUSYBOX_VERSION.tar.bz2 ...${NC}"
  tar -xjf busybox-$BUSYBOX_VERSION.tar.bz2 -C .

  echo -e "\n${GREEN}>>> Building busybox-$BUSYBOX_VERSION ...${NC}"
  cd busybox-$BUSYBOX_VERSION
    make defconfig
    sed 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' -i .config
    time make -j"$(($(nproc) / 2))" && echo -e "\n${GREEN}>>> busybox-$BUSYBOX_VERSION successfully built.${NC}" || echo -e "\n${RED}!!! busybox-$BUSYBOX_VERSION build failed!${NC}" && exit
  cd ..
  return 0
}


verify_busybox_signature() {
  echo -e "\n${GREEN}>>> Downloading busybox-$BUSYBOX_VERSION.tar.bz2.sig ...${NC}"
  $DOWNLOADER -o busybox-$BUSYBOX_VERSION.tar.bz2.sha256 $BUSYBOX_SHA256_URL

  echo -e "\n${GREEN}>>> Verifing busybox-$BUSYBOX_VERSION.tar.bz2.sha256 ...${NC}"
  sha256sum -c busybox-$BUSYBOX_VERSION.tar.bz2.sha256

  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}>>> busybox-$BUSYBOX_VERSION.tar.bz2.sig is valid.${NC}"
    return 0
  else
    echo -e "\n${RED}!!! busybox-$BUSYBOX_VERSION.tar.bz2.sig is invalid!${NC}"
    return 1
  fi
}

download_extract_build_busybox() {
  cd src/

  if [ -f "busybox-$BUSYBOX_VERSION.tar.bz2" ]; then
    if verify_busybox_signature; then
      extract_build_busybox
      return 0
    else
      echo -e "\n${RED}!!! Signature verification failed: busybox-$BUSYBOX_VERSION.tar.bz2${NC}"
      return 1
    fi
  else
    if check_url $BUSYBOX_SRC_URL; then
      echo -e "\n${GREEN}>>> busybox-$BUSYBOX_VERSION.tar.bz2 URL is valid.${NC}"

      echo -e "\n${GREEN}>>> Downloading busybox-$BUSYBOX_VERSION.tar.bz2 ...${NC}"
      $DOWNLOADER -o busybox-$BUSYBOX_VERSION.tar.bz2 $BUSYBOX_SRC_URL

      if verify_busybox_signature; then
        extract_build_busybox
        return 0
      else
        echo -e "\n${RED}!!! Signature verification failed: busybox-$BUSYBOX_VERSION.tar.bz2${NC}"
        return 1
      fi
    else
      echo -e "\n${RED}!!! BusyBox URL is not valid.${NC}"
      return 2
    fi
  fi

  cd ..
}

create_distro() {
  cd output/
    cp ../src/linux-$LINUX_VERSION/arch/x86_64/boot/bzImage ./
    mkdir -p initrd
    cd initrd
      echo -e "\n${GREEN}>>> Setup initrd ...${NC}"
      mkdir -p apps bin etc kernel dev home mnt proc root sys tmp
      cd bin
        cp ../../../src/busybox-$BUSYBOX_VERSION/busybox ./
        for prog in $(./busybox --list); do
          ln -s ./busybox ./$prog
        done

        #cp ../../../scripts/init.sh ./
        #chmod +x init.sh
  
        #cp ../../../scripts/login.sh ./
        #chmod +x login.sh

        cp ./init ../

      cd ..

      host="ArenOs"
      echo $host > etc/hostname
      echo "/bin/sh" > etc/shells
      echo "127.0.0.1		localhost.localdomain	localhost" > etc/hosts
      echo "::1			localhost.localdomain	localhost ip6-localhost" >> etc/hosts

      echo -e "\n${GREEN}>>> Generating /etc/init.d/rcS ...${NC}"
      cp ../../src/busybox-$BUSYBOX_VERSION/examples/inittab ./etc/
      mkdir -p etc/init.d
      cd etc/init.d/
        echo "#!/bin/sh" > rcS
        ## To see the available file system types supported by the mount: cat /proc/filesystems
        echo 'mount -t sysfs sysfs /sys' >> rcS
        echo 'mount -t proc proc /proc' >> rcS
        echo 'mount -t devtmpfs udev /dev' >> rcS
        echo 'mount -t tmpfs none /tmp' >> rcS
        echo 'sysctl -w kernel.printk="0 0 0 0"' >> rcS
        echo "/bin/login" >> rcS
        
        #echo "/bin/init" >> init
        ##echo "setsid sh -c 'exec sh </dev/tty1 >/dev/tty1 2>&1'" >> init
        ##echo 'mknod -m 622 /dev/console c 5 1' >> init
        ##echo 'mknod -m 666 /dev/tty c 5 0' >> init
        ##echo "/bin/init.sh" >> init
        ### run the shell on a normal tty(tty1) instead of running it on: /dev/console.
      cd ../..
 

      echo "root:x:0:" > etc/group
      echo "bin:x:1:" >> etc/group
      echo "sys:x:2:" >> etc/group
      echo "wheel:x:4:" >> etc/group
      echo "daemon:x:7:" >> etc/group
      echo "disk:x:9:" >> etc/group
      echo "audio:x:12:" >> etc/group
      echo "video:x:13:" >> etc/group
      echo "mail:x:18:" >> etc/group
      echo "storage:x:19:" >> etc/group
      echo "scanner:x:20:" >> etc/group
      echo "network:x:21:" >> etc/group
      echo "input:x:25:" >> etc/group
      echo "nogroup:x:99:" >> etc/group
      echo "users:x:100:" >> etc/group

      echo "root:x:0:0:root:/root:/bin/sh" > etc/passwd

      # ArenOs uses SHA-512 encryption algorithms. to generate a hash for this algorithm:
      # echo -n "toor" | openssl dgst -sha512
      #echo "root:2b64f2e3f9fee1942af9ff60d40aa5a719db33b8ba8dd4864bb4f11e25ca2bee00907de32a59429602336cac832c8f2eeff5177cc14c864dd116c8bf6ca5d9a9:17743:18635:0:99999:7:::" > etc/shadow
      echo "root:mKhhqXFCdhNiA:17743::::::" > etc/shadow

     
      chmod -R 777 .
      chmod +x init
      find . | cpio -o -H newc > ../initrd.img
    cd ..
  cd ..
}

lunch_qemu() {
  cd output/

  echo -e "\n${GREEN}>>> Lunching in qemu ...${NC}"
  qemu-system-x86_64 -kernel bzImage -initrd initrd.img

  cd ..
}

build_src_output_dir
create_distro
lunch_qemu

#if download_extract_build_linux; then
#  download_extract_build_busybox
#
#  arch/x86/boot/bzImage
#fi


# Garbage
# Ensure terminal setup: Create /dev/console and /dev/tty
#echo 'mknod -m 622 /dev/console c 5 1' >> init
#echo 'mknod -m 666 /dev/tty c 5 0' >> init
#echo '/bin/sh +m' >> init
#echo 'setsid sh -c "exec sh </dev/tty1 >/dev/tty1 2>&1"' >> init
#echo 'mknod -m 666 /dev/tty0 c 5 0' >> init
