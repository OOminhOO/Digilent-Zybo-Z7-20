# Zybo Z7-020 PL GPIO를 이용한 stepmotor 제어 가이드

Zybo Z7-020에서 PL(Programmable Logic) 영역의 GPIO를 사용하여 LED를 제어하는 전체 프로세스를 단계별로 설명합니다.

<img width="495" height="488" alt="023" src="https://github.com/user-attachments/assets/a28c80bb-bb28-4b34-8b94-fa75e9859d27" />


## 📋 목차
1. [Vivado에서 하드웨어 설계](#1️⃣-vivado에서-하드웨어-설계-windows)
2. [PetaLinux 프로젝트 생성 및 빌드](#2️⃣-petalinux-프로젝트-생성-ubuntu-2204)
3. [쉘스크립트로 LED 제어](#3️⃣-쉘스크립트로-led-제어)
4. [C 언어로 LED 제어](#4️⃣-c-언어로-led-제어)
5. [문제 해결](#-문제-해결-troubleshooting)
6. [추가 개선 사항](#-추가-개선-사항)

## 🛠️ 개발 환경

- **FPGA 보드**: Digilent Zybo Z7-020
- **Vivado**: 2022.2 (Windows)
- **PetaLinux**: 2022.2 (Ubuntu 22.04.5 LTS)
- **제어 대상**: PL GPIO 4개 → LED 4개

---

## 1️⃣ Vivado에서 하드웨어 설계 (Windows)

### 1.1 새 프로젝트 생성

1. Vivado 2022.2 실행
2. "Create Project" 클릭
3. 프로젝트 이름: `zybo_gpio_led`
4. 프로젝트 위치 지정
5. "RTL Project" 선택, "Do not specify sources at this time" 체크
6. Board 선택: **Digilent Zybo Z7-20** 선택
   - 보드가 목록에 없으면 [Digilent Board Files](https://github.com/Digilent/vivado-boards) 설치 필요

### 1.2 Block Design 생성

1. "Create Block Design" 클릭
2. Design 이름: `system`

### 1.3 IP 추가 및 연결

#### Step 0: zybo_z720_stepper_top IP로 만들기
tools -> create and packege new ip  
<img width="545" height="97" alt="image" src="https://github.com/user-attachments/assets/f03b4514-1abe-4024-956c-725a6322cf8e" />


#### Step 1: ZYNQ7 Processing System 추가
1. IP Catalog에서 "ZYNQ7 Processing System" 검색
2. 블록 다이어그램에 추가
3. "Run Block Automation" 클릭하여 자동 설정 적용

#### Step 2: AXI GPIO 추가
1. IP Catalog에서 "AXI GPIO" 검색
2. 블록 다이어그램에 추가
3. AXI GPIO를 더블클릭하여 설정:
   - **GPIO Width**: 4 (LED 4개 사용)
   - **All Outputs** 체크
   - **Enable Dual Channel**: 비활성화

#### Step 3: 연결하기
1. "Run Connection Automation" 클릭
2. 모든 옵션 체크하고 OK
   - AXI GPIO가 ZYNQ PS의 M_AXI_GP0에 자동 연결됨
   - AXI Interconnect와 Processor System Reset이 자동 추가됨

#### Step 4: stepmotor ip 추가
1. 새로 만들었던 ip 추가후 gpio_io_o out put 을 stepmotor ip 입력에 연결
2. clk는 zynq의 fclk_clk0로 연결 (혹은 새로 하나 만들어서 125M로 설정가능)
3. 이전에 코드의 파라미터 50M로 바꿔주기(업데이트)
  

#### Step 5:  stepmotor 포트를 외부로 연결
1. stepmotor IP 포트를 우클릭
2. "Make External" 선택
3. 생성된 포트 이름: `coils` (또는 유사한 이름)

<img width="1209" height="448" alt="image" src="https://github.com/user-attachments/assets/f984f7b9-f1d6-4de9-acf7-f99a6b0d21b6" />



### 1.4 주소 할당 확인

1. "Address Editor" 탭 클릭
2. `axi_gpio_0`의 주소 확인 (예: `0x41200000`)
   - ⚠️ 이 주소는 나중에 소프트웨어에서 사용됩니다

### 1.5 제약 파일(Constraints) 생성

#### Step 1: XDC 파일 생성
1. Sources 창에서 "Add Sources" 클릭
2. "Add or create constraints" 선택
3. "Create File" 클릭
4. 파일명: `zybo_constraints.xdc`

#### Step 2: coils[3:0] 핀 매핑 작성


**`zybo_constraints.xdc` 파일 내용:**
```tcl##Pmod Header JE                                                                                                                  
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { coils[0] }]; #IO_L4P_T0_34 Sch=je[1]						 
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { coils[1] }]; #IO_L18N_T2_34 Sch=je[2]                     
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { coils[2] }]; #IO_25_35 Sch=je[3]                          
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { coils[3] }]; #IO_L19P_T3_35 Sch=je[4]                     
#set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { je[4] }]; #IO_L3N_T0_DQS_34 Sch=je[7]                  
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { je[5] }]; #IO_L9N_T1_DQS_34 Sch=je[8]                  
#set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { je[6] }]; #IO_L20P_T3_34 Sch=je[9]                     
#set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { je[7] }]; #IO_L7N_T1_34 Sch=je[10]   
```

> ⚠️ **주의**: 실제로 Block Design에서 생성된 포트 이름을 확인하고 위의 `gpio_rtl_0_tri_o`를 실제 이름으로 변경하세요.

### 1.6 HDL Wrapper 생성 및 비트스트림 생성

1. Sources 창에서 Block Design (`system.bd`) 우클릭
2. "Create HDL Wrapper" 선택
3. "Let Vivado manage wrapper..." 선택
4. "Generate Bitstream" 클릭
5. 합성 및 구현이 완료될 때까지 대기 (⏱️ 10-20분 소요)

### 1.7 하드웨어 내보내기

1. File → Export → Export Hardware 클릭
2. "Include bitstream" 선택
3. 파일 저장: `system_wrapper.xsa`
4. 이 파일을 Ubuntu로 전송 (USB, 네트워크 등)

---

## 2️⃣ PetaLinux 프로젝트 생성 (Ubuntu 22.04)

### 2.1 PetaLinux 환경 설정

```bash
# XSA 파일 준비
cp /mnt/share/system_wrapper.xsa ~/projects/

# PetaLinux 설치 확인 (2022.2 버전)
source ~/petalinux/2022.2/settings.sh

# 작업 디렉토리 이
cd ~/projects/myproject
```

### 2.3 하드웨어 정보 가져오기

```bash
# Vivado에서 export한 XSA 파일 경로 지정
petalinux-config --get-hw-description=~/projects/
```

### 2.4 Device Tree 수정 (중요!)

PL GPIO를 사용하려면 Device Tree에 GPIO 컨트롤러를 등록해야 합니다.

```bash
# Device Tree 편집
vi project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
```

**`system-user.dtsi` 내용:**
```dts
/include/ "system-conf.dtsi"
/ {
};

&axi_gpio_0 {
    compatible = "xlnx,xps-gpio-1.00.a";
    gpio-controller;
    #gpio-cells = <2>;
    xlnx,all-inputs = <0x0>;
    xlnx,all-outputs = <0x1>;
    xlnx,dout-default = <0x0>;
    xlnx,gpio-width = <0x4>;
    xlnx,tri-default = <0xFFFFFFFF>;
    xlnx,is-dual = <0>;
};
```

**설명:**
- `gpio-controller`: 이 디바이스가 GPIO 컨트롤러임을 선언
- `#gpio-cells = <2>`: GPIO 참조 시 2개의 셀 사용 (핀 번호, 플래그)
- `xlnx,gpio-width = <0x4>`: GPIO 폭 4비트 (LED 4개)
- `xlnx,all-outputs = <0x1>`: 모든 핀이 출력

### 2.5 커널 설정 확인

```bash
petalinux-config -c kernel
```

다음 옵션들이 활성화되어 있는지 확인:
```
Device Drivers --->
    [*] GPIO Support --->
        <*> Memory mapped GPIO drivers --->
            <*> Xilinx GPIO support
        <*> /sys/class/gpio/... (sysfs interface)
```

저장하고 종료 (Save → Exit)

### 2.6 PetaLinux 빌드

```bash
cd ~/projects/myproject

# PetaLinux 환경 확인
source ~/petalinux/2022.2/settings.sh

# 빌드 시작
petalinux-build

petalinux-package --boot \
    --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system_wrapper.bit \
    --u-boot images/linux/u-boot.elf \
    --force

# WIC 이미지 생성
petalinux-package --wic \
    --bootfiles "BOOT.BIN image.ub boot.scr" \
    --images-dir images/linux/
```

---
```
petalinux-build -c kernel

빌드 후 설정 확인
bash# GPIO 설정이 제대로 적용되었는지 확인
grep "CONFIG_GPIO" build/tmp/work/zynq_generic-xilinx-linux-gnueabi/linux-xlnx/*/linux-zynq_generic-standard-build/.config | grep "=y"


**예상 출력:**
CONFIG_GPIOLIB=y
CONFIG_GPIO_SYSFS=y
CONFIG_GPIO_XILINX=y
CONFIG_OF_GPIO=y
CONFIG_GPIO_GENERIC=y
```
---

## 3️⃣ 쉘스크립트로 LED 제어

### 3.1 Zybo 부팅 및 로그인

1. SD 카드를 Zybo에 삽입
2. UART 연결 (115200 8N1)
3. 전원 켜기
4. 로그인: `root` / `root`

### 3.2 GPIO sysfs 인터페이스 확인

```bash
# GPIO 컨트롤러 확인
ls /sys/class/gpio/

# gpiochip이 보이면 정상 (예: gpiochip496)
# 번호는 시스템마다 다를 수 있음

# GPIO 베이스 번호 확인
cat /sys/class/gpio/gpiochip*/base
cat /sys/class/gpio/gpiochip*/ngpio
```

예를 들어:
- base: 496
- ngpio: 4

그러면 GPIO 번호는 **496, 497, 498, 499**입니다.

### 3.3 수동으로 LED 테스트

```bash
# GPIO export (LED0 = GPIO 496 가정)
echo 496 > /sys/class/gpio/export

# 출력 모드 설정
echo out > /sys/class/gpio/gpio496/direction

# LED 켜기
echo 1 > /sys/class/gpio/gpio496/value

# LED 끄기
echo 0 > /sys/class/gpio/gpio496/value

# GPIO unexport
echo 496 > /sys/class/gpio/unexport
```

### 3.4 LED 제어 쉘스크립트 작성

**`led_control.sh`:**
```bash
#!/bin/bash

# GPIO 베이스 번호 (시스템에 맞게 수정)
GPIO_BASE=496

# LED 번호 (0-3)
LED_NUM=$1
ACTION=$2

# GPIO 번호 계산
GPIO_NUM=$((GPIO_BASE + LED_NUM))

# 사용법 출력
if [ $# -ne 2 ]; then
    echo "사용법: $0 <LED 번호(0-3)> <on|off>"
    exit 1
fi

# GPIO export (이미 export된 경우 무시)
if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
    echo ${GPIO_NUM} > /sys/class/gpio/export
    sleep 0.1
fi

# 출력 모드 설정
echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction

# LED 제어
case $ACTION in
    on)
        echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
        echo "LED${LED_NUM} ON"
        ;;
    off)
        echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
        echo "LED${LED_NUM} OFF"
        ;;
    *)
        echo "잘못된 동작: on 또는 off를 사용하세요"
        exit 1
        ;;
esac
```

### 3.5 LED 순차 점멸 스크립트

**`led_blink.sh`:**
```bash
#!/bin/bash

GPIO_BASE=496

# 모든 LED export
for i in {0..3}; do
    GPIO_NUM=$((GPIO_BASE + i))
    if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
        echo ${GPIO_NUM} > /sys/class/gpio/export
        sleep 0.1
    fi
    echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction
done

echo "LED 순차 점멸 시작 (Ctrl+C로 종료)"

# 무한 루프
while true; do
    # 순차적으로 켜기
    for i in {0..3}; do
        GPIO_NUM=$((GPIO_BASE + i))
        echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
        sleep 0.2
    done
    
    # 순차적으로 끄기
    for i in {0..3}; do
        GPIO_NUM=$((GPIO_BASE + i))
        echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
        sleep 0.2
    done
done
```

### 3.6 실행 방법

```bash
# 실행 권한 부여
chmod +x led_control.sh
chmod +x led_blink.sh

# LED 제어 테스트
./led_control.sh 0 on   # LED0 켜기
./led_control.sh 0 off  # LED0 끄기
./led_control.sh 1 on   # LED1 켜기

# LED 순차 점멸
./led_blink.sh
```

---

## 4️⃣ C 언어로 LED 제어

### 4.1 C 프로그램 작성

**`led_control.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#define GPIO_BASE 496  // 시스템에 맞게 수정
#define MAX_BUF 64

// GPIO export
int gpio_export(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/export", O_WRONLY);
    if (fd < 0) {
        perror("GPIO export 열기 실패");
        return -1;
    }
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    
    usleep(100000);  // 100ms 대기
    return 0;
}

// GPIO unexport
int gpio_unexport(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/unexport", O_WRONLY);
    if (fd < 0) {
        perror("GPIO unexport 열기 실패");
        return -1;
    }
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    
    return 0;
}

// GPIO 방향 설정
int gpio_set_direction(int gpio_num, const char *direction) {
    int fd;
    char path[MAX_BUF];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio_num);
    
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("GPIO direction 열기 실패");
        return -1;
    }
    
    write(fd, direction, strlen(direction));
    close(fd);
    
    return 0;
}

// GPIO 값 설정
int gpio_set_value(int gpio_num, int value) {
    int fd;
    char path[MAX_BUF];
    char val_str[2];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    
    fd = open(path, O_WRONLY);
    if (fd < 0) {
        perror("GPIO value 열기 실패");
        return -1;
    }
    
    snprintf(val_str, sizeof(val_str), "%d", value);
    write(fd, val_str, 1);
    close(fd);
    
    return 0;
}

// GPIO 값 읽기
int gpio_get_value(int gpio_num) {
    int fd;
    char path[MAX_BUF];
    char value;
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    
    fd = open(path, O_RDONLY);
    if (fd < 0) {
        perror("GPIO value 읽기 실패");
        return -1;
    }
    
    read(fd, &value, 1);
    close(fd);
    
    return (value == '0') ? 0 : 1;
}

int main(int argc, char *argv[]) {
    int led_num, gpio_num;
    char action[10];
    
    if (argc != 3) {
        printf("사용법: %s <LED 번호(0-3)> <on|off>\n", argv[0]);
        return 1;
    }
    
    led_num = atoi(argv[1]);
    strcpy(action, argv[2]);
    
    if (led_num < 0 || led_num > 3) {
        printf("LED 번호는 0-3 사이여야 합니다.\n");
        return 1;
    }
    
    gpio_num = GPIO_BASE + led_num;
    
    // GPIO export
    gpio_export(gpio_num);
    
    // 출력 모드 설정
    gpio_set_direction(gpio_num, "out");
    
    // LED 제어
    if (strcmp(action, "on") == 0) {
        gpio_set_value(gpio_num, 1);
        printf("LED%d ON\n", led_num);
    } else if (strcmp(action, "off") == 0) {
        gpio_set_value(gpio_num, 0);
        printf("LED%d OFF\n", led_num);
    } else {
        printf("잘못된 동작: on 또는 off를 사용하세요\n");
        return 1;
    }
    
    return 0;
}
```

### 4.2 LED 순차 점멸 C 프로그램

**`led_blink.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>

#define GPIO_BASE 496
#define NUM_LEDS 4
#define MAX_BUF 64

volatile sig_atomic_t stop = 0;

void sigint_handler(int sig) {
    stop = 1;
}

int gpio_export(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/export", O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    usleep(100000);
    return 0;
}

int gpio_unexport(int gpio_num) {
    int fd;
    char buf[MAX_BUF];
    
    fd = open("/sys/class/gpio/unexport", O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(buf, sizeof(buf), "%d", gpio_num);
    write(fd, buf, strlen(buf));
    close(fd);
    return 0;
}

int gpio_set_direction(int gpio_num, const char *direction) {
    int fd;
    char path[MAX_BUF];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/direction", gpio_num);
    fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    
    write(fd, direction, strlen(direction));
    close(fd);
    return 0;
}

int gpio_set_value(int gpio_num, int value) {
    int fd;
    char path[MAX_BUF];
    char val_str[2];
    
    snprintf(path, sizeof(path), "/sys/class/gpio/gpio%d/value", gpio_num);
    fd = open(path, O_WRONLY);
    if (fd < 0) return -1;
    
    snprintf(val_str, sizeof(val_str), "%d", value);
    write(fd, val_str, 1);
    close(fd);
    return 0;
}

int main() {
    int gpio_nums[NUM_LEDS];
    int i;
    
    // 시그널 핸들러 등록
    signal(SIGINT, sigint_handler);
    
    // GPIO 초기화
    for (i = 0; i < NUM_LEDS; i++) {
        gpio_nums[i] = GPIO_BASE + i;
        gpio_export(gpio_nums[i]);
        gpio_set_direction(gpio_nums[i], "out");
        gpio_set_value(gpio_nums[i], 0);
    }
    
    printf("LED 순차 점멸 시작 (Ctrl+C로 종료)\n");
    
    while (!stop) {
        // 순차적으로 켜기
        for (i = 0; i < NUM_LEDS && !stop; i++) {
            gpio_set_value(gpio_nums[i], 1);
            usleep(200000);  // 200ms
        }
        
        // 순차적으로 끄기
        for (i = 0; i < NUM_LEDS && !stop; i++) {
            gpio_set_value(gpio_nums[i], 0);
            usleep(200000);
        }
    }
    
    // 정리: 모든 LED 끄고 unexport
    printf("\n정리 중...\n");
    for (i = 0; i < NUM_LEDS; i++) {
        gpio_set_value(gpio_nums[i], 0);
        gpio_unexport(gpio_nums[i]);
    }
    
    printf("종료\n");
    return 0;
}
```

### 4.3 컴파일 및 실행

#### 방법 1: Zybo에서 직접 컴파일 (rootfs에 gcc 포함된 경우)

```bash
gcc -o led_control led_control.c
gcc -o led_blink led_blink.c

# 실행
./led_control 0 on
./led_control 1 on
./led_blink
```

#### 방법 2: 크로스 컴파일 (Ubuntu에서)

```bash
# PetaLinux SDK 설정
cd ~/petalinux_projects/zybo_gpio_led
petalinux-build --sdk
petalinux-package --sysroot

# SDK 설치
cd images/linux
./sdk.sh -d ~/petalinux_sdk

# SDK 환경 설정
source ~/petalinux_sdk/environment-setup-cortexa9t2hf-neon-xilinx-linux-gnueabi

# 크로스 컴파일
$CC led_control.c -o led_control
$CC led_blink.c -o led_blink

# Zybo로 파일 전송 (scp 또는 SD 카드)
scp led_control led_blink root@<zybo_ip>:/home/root/
```

---

## 🔧 문제 해결 (Troubleshooting)

### 1. GPIO가 보이지 않는 경우

```bash
# Device Tree 확인
cat /proc/device-tree/amba_pl@0/gpio@*/compatible

# 드라이버 로드 확인
lsmod | grep gpio
dmesg | grep gpio

# GPIO 컨트롤러 찾기
find /sys/class/gpio -name "gpiochip*"
```

### 2. GPIO 베이스 번호 찾기

```bash
# 모든 GPIO 칩 정보 확인
for chip in /sys/class/gpio/gpiochip*; do
    echo "Chip: $chip"
    echo "  Base: $(cat $chip/base)"
    echo "  Ngpio: $(cat $chip/ngpio)"
    echo "  Label: $(cat $chip/label)"
done
```

### 3. Permission denied 오류

```bash
# root로 실행하거나 udev 규칙 추가
sudo su
# 또는
sudo ./led_control 0 on
```

### 4. Device Tree 다시 확인

```bash
# Vivado Address Editor에서 확인한 주소와 매칭되는지 확인
cat /proc/device-tree/amba_pl@0/gpio@*/reg
```

---

## 📝 추가 개선 사항

### 1. UIO (Userspace I/O) 사용

더 빠른 성능이 필요하면 UIO 드라이버 사용:

**`led_control_uio.c`:**
```c
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

#define GPIO_BASE_ADDR 0x41200000  // Vivado Address Editor에서 확인
#define GPIO_DATA_OFFSET 0x0
#define GPIO_TRI_OFFSET 0x4

int main() {
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Cannot open /dev/mem");
        return -1;
    }
    
    void *gpio_addr = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                          MAP_SHARED, fd, GPIO_BASE_ADDR);
    
    if (gpio_addr == MAP_FAILED) {
        perror("mmap failed");
        close(fd);
        return -1;
    }
    
    volatile unsigned int *gpio_data = (unsigned int *)(gpio_addr + GPIO_DATA_OFFSET);
    volatile unsigned int *gpio_tri = (unsigned int *)(gpio_addr + GPIO_TRI_OFFSET);
    
    *gpio_tri = 0x0;  // 모두 출력으로 설정
    
    // LED 순차 점멸
    for (int i = 0; i < 10; i++) {
        *gpio_data = 0xF;  // 모든 LED ON
        usleep(500000);    // 500ms
        *gpio_data = 0x0;  // 모든 LED OFF
        usleep(500000);
    }
    
    munmap(gpio_addr, 4096);
    close(fd);
    
    return 0;
}
```

### 2. 부팅 시 자동 실행

```bash
# systemd 서비스 생성
nano /etc/systemd/system/led-blink.service
```

**`led-blink.service`:**
```ini
[Unit]
Description=LED Blink Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/home/root/led_blink
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# 서비스 활성화
systemctl enable led-blink.service
systemctl start led-blink.service

# 상태 확인
systemctl status led-blink.service
```

### 3. PWM을 이용한 LED 밝기 조절

쉘스크립트로 간단한 소프트웨어 PWM 구현:

**`led_pwm.sh`:**
```bash
#!/bin/bash

GPIO_BASE=496
LED_NUM=$1
BRIGHTNESS=$2  # 0-100

if [ $# -ne 2 ]; then
    echo "사용법: $0 <LED 번호(0-3)> <밝기(0-100)>"
    exit 1
fi

GPIO_NUM=$((GPIO_BASE + LED_NUM))

# GPIO export
if [ ! -d /sys/class/gpio/gpio${GPIO_NUM} ]; then
    echo ${GPIO_NUM} > /sys/class/gpio/export
    sleep 0.1
fi

echo out > /sys/class/gpio/gpio${GPIO_NUM}/direction

# PWM 시뮬레이션
while true; do
    echo 1 > /sys/class/gpio/gpio${GPIO_NUM}/value
    sleep 0.$(printf "%02d" $BRIGHTNESS)
    
    echo 0 > /sys/class/gpio/gpio${GPIO_NUM}/value
    sleep 0.$(printf "%02d" $((100 - BRIGHTNESS)))
done
```

---

## ✅ 체크리스트

- [ ] Vivado에서 Block Design 완성
- [ ] XDC 파일에 LED 핀 할당
- [ ] 비트스트림 생성 및 XSA export
- [ ] PetaLinux 프로젝트 생성
- [ ] Device Tree에 GPIO 추가
- [ ] PetaLinux 빌드 성공
- [ ] SD 카드에 이미지 복사
- [ ] Zybo 부팅 확인
- [ ] GPIO sysfs 인터페이스 확인
- [ ] 쉘스크립트로 LED 제어 성공
- [ ] C 프로그램으로 LED 제어 성공

---

## 📚 참고 자료

- [Xilinx Zynq-7000 Technical Reference Manual](https://www.xilinx.com/support/documentation/user_guides/ug585-Zynq-7000-TRM.pdf)
- [Digilent Zybo Z7 Reference Manual](https://digilent.com/reference/programmable-logic/zybo-z7/reference-manual)
- [PetaLinux Tools Documentation](https://docs.xilinx.com/r/en-US/ug1144-petalinux-tools-reference-guide)
- [Linux GPIO Sysfs Interface](https://www.kernel.org/doc/Documentation/gpio/sysfs.txt)

---

## 📄 라이선스

이 가이드는 교육 목적으로 자유롭게 사용할 수 있습니다.

---

## 🤝 기여

개선 사항이나 오류 발견 시 Issue 또는 Pull Request를 환영합니다!

---

**작성일**: 2024  
**테스트 환경**: Zybo Z7-020, Vivado 2022.2, PetaLinux 2022.2, Ubuntu 22.04.5 LTS
