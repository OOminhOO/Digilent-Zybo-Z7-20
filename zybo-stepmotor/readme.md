# Zybo_StepMotor

## Standalone Step Motor Controller : StepMotor(28BYJ-48) 5V - ULN2003

### ⚙️ 1.회로

<img width="357" height="241" alt="002" src="https://github.com/user-attachments/assets/e3528fc4-6645-4929-b022-2307864cf76e" />
<br>
<img width="608" height="186" alt="003" src="https://github.com/user-attachments/assets/e3575f39-af0e-401a-8ddc-dfcf0dacb800" />
<br>

---
https://cookierobotics.com/042/

<img width="284" height="185" alt="001" src="https://github.com/user-attachments/assets/a0466c38-e394-4f88-85ea-c284e5b2f055" />
<img width="384" height="185" alt="002" src="https://github.com/user-attachments/assets/1b102543-878c-488b-a975-708d9e810989" />
<br>
<img width="296" height="134" alt="003" src="https://github.com/user-attachments/assets/c6bcccd2-034f-4bcf-b247-cc0b3bcb0c4e" />
<img width="292" height="201" alt="004" src="https://github.com/user-attachments/assets/471f5e82-0914-4f7d-a2f8-f7d2527c72af" />
<br>
<img width="457" height="195" alt="KakaoTalk_20251110_094901305" src="https://github.com/user-attachments/assets/11e6cdb6-47d6-4c78-9909-bd67a80e4a05" />
<br>  

---

### ⚙️ 2. Full-Step (풀스텝) 구동

한 번에 두 코일씩(예: A + B, B + C, C + D, D + A) 에 전류를 흘립니다.

|스텝 순서	|코일 상태	|출력 비트 (A,B,C,D)|
|:----:|:----:|:----:|
|1	|A+B	|1100|
|2	|B+C	|0110|
|3	|C+D	|0011|
|4	|D+A	|1001|

* 특징
  * ✅ 장점
     * 두 코일이 동시에 자력을 내므로 토크가 크다.
     * 단순한 제어(4패턴).
   * ⚠️ 단점
     * 스텝 각도가 큼 → 해상도 낮음.
     * 진동이 커서 소음이 날 수 있음.

* 28BYJ-48의 풀스텝 모터 기준 기계적 스텝각 ≈ 11.25°,
* 기어비(64:1) 적용 시 출력축 1스텝 ≈ 0.1758°

### ⚙️ 3. Half-Step (하프스텝) 구동

* 한 코일만 켜는 스텝과 두 코일을 동시에 켜는 스텝을 교대로 실행합니다.

|스텝 순서	|코일 상태	|출력 비트 (A,B,C,D)|
|:----:|:----:|:----:|
|1	|A	|1000|
|2	|A+B	|1100|
|3	|B	|0100|
|4	|B+C	|0110|
|5	|C	|0010|
|6	|C+D	|0011|
|7	|D	|0001|
|8	|D+A	|1001|

* 특징
   * ✅ 장점
      * 스텝 해상도 2배 증가 (Full-Step의 절반 각도).
      * 움직임이 부드럽고 진동 적음.
    * ⚠️ 단점
      * 단일 코일 구간에서는 토크가 조금 떨어짐.
      * 제어가 약간 복잡(8패턴).

* 28BYJ-48의 하프스텝 스텝각 ≈ 5.625°,
* 기어비(64:1) 적용 시 출력축 1스텝 ≈ 0.0879°

### 🧩 디바운스

* 1)카운트 기준 계산 → 2)입력 신호 동기화 (메타스테이블 방지) → 3)안정 상태 판정 로직

* 🔍 동작 예시 (파형으로 이해)

| 시간	|din (입력)	|din_q2 (동기화)|	cnt	|dout (출력)	|설명|
|:---:|:---:|:---:|:---:|:---:|:---:| 
| t0	|0	|0	|0	|0	|초기 상태|
| t1	|1	|1	|↑	|0	|입력이 변해서 카운트 시작|
| t2~t3	|1	|1	|→ CNT_MAX 도달|	0→1|	10ms 이상 유지 → 출력 반영|
| t4	|1→0 (노이즈)	|0	|리셋	|1	|노이즈 순간은 무시됨|
| t5	|0	|0	|↑	|1	|10ms 이상 유지 시 다음 반전 허용|

### ⚙️ 4. 타이밍 설정 팁
| 목표	| 설정 예시| 
|:---:|:---:| 
| 버튼	| 10~20ms| 
| 토글 스위치	| 5~10ms| 
| 리셋 신호	| 1ms 이하 (빠르게 반응)| 

```verilog
// zybo_z720_stepper_top.v
module zybo_z720_stepper_top #(
    parameter integer CLK_HZ        = 125_000_000, 
    parameter integer STEPS_PER_SEC = 600         // 초당 스텝 수(half-step 기준). 28BYJ-48은 200~600 정도 무난
    //parameter         HALF_STEP     = 1            // 1: half-step(8패턴), 0: full-step(4패턴)
)(
    input wire HALF_STEP,   //full_step = 0 , half step = 1 구분 
    input  wire clk,         // 보드 클럭
    input  wire rst_n,       // Active-Low Reset
    input  wire sw_run,      // RUN/STOP 스위치 (1=RUN, 0=STOP)
    input  wire sw_dir,      // 1=Forward, 0=Backward
    output wire [3:0] coils  // ULN2003 IN1..IN4 로 연결 (논리 '1'이면 해당 코일 ON)
);

    // -------- 스위치 동기화/디바운스 --------
    wire run_clean, dir_clean;
  
   
   

    debounce #(
        .CLK_HZ(CLK_HZ),
        .MS(10)             // 10ms 디바운스
    ) u_db_run (
        .clk(clk), .rst_n(rst_n),
        .din(sw_run),
        .dout(run_clean)
    );

    debounce #(
        .CLK_HZ(CLK_HZ),
        .MS(10)
    ) u_db_dir (
        .clk(clk), .rst_n(rst_n),
        .din(sw_dir),
        .dout(dir_clean)
    );

    // -------- 스텝 타이머 --------
    localparam integer TICKS_PER_STEP = (CLK_HZ / STEPS_PER_SEC);
    reg [31:0] tick_cnt;
    wire step_pulse = (tick_cnt == 0);

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            tick_cnt <= TICKS_PER_STEP - 1;
        end else if (run_clean) begin
            tick_cnt <= (tick_cnt == 0) ? (TICKS_PER_STEP - 1) : (tick_cnt - 1);
        end else begin
            tick_cnt <= TICKS_PER_STEP - 1; // STOP 상태에선 주기 카운터 정지/유지
        end
    end

    // -------- 스텝 인덱스 (0..7 half-step) --------
    //localparam integer MAX_IDX = (HALF_STEP ? 7 : 3);
    wire [2:0] MAX_IDX = (HALF_STEP ? 7 : 3);
    reg [2:0] step_idx; // 충분한 비트 폭
    

    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            step_idx <= 0;
        end else if (run_clean && step_pulse) begin
            if (dir_clean) begin
                // Forward
                if (step_idx == MAX_IDX) step_idx <= 0;
                else                     step_idx <= step_idx + 1'b1;
            end else begin
                // Backward
                if (step_idx == 0)       step_idx <= MAX_IDX[2:0];
                else                     step_idx <= step_idx - 1'b1;
            end
        end
    end

    // -------- 시퀀스 ROM: 28BYJ-48 권장 패턴 --------
    // 코일 순서: [A,B,C,D] = [3,2,1,0] 비트로 가정. ULN2003 IN1=A, IN2=B, IN3=C, IN4=D 에 맞춰 배선하세요.
    reg [3:0] patt;

    always @(*) begin
        if (HALF_STEP) begin
            // Half-step (8-step) : A, A+B, B, B+C, C, C+D, D, D+A
            case (step_idx)
                3'd0: patt = 4'b1000; // A
                3'd1: patt = 4'b1100; // A+B
                3'd2: patt = 4'b0100; // B
                3'd3: patt = 4'b0110; // B+C
                3'd4: patt = 4'b0010; // C
                3'd5: patt = 4'b0011; // C+D
                3'd6: patt = 4'b0001; // D
                3'd7: patt = 4'b1001; // D+A
                default: patt = 4'b0000;
            endcase
        end else begin
            // Full-step (4-step) : A+B, B+C, C+D, D+A
            case (step_idx[1:0])
                2'd0: patt = 4'b1100; // A+B
                2'd1: patt = 4'b0110; // B+C
                2'd2: patt = 4'b0011; // C+D
                2'd3: patt = 4'b1001; // D+A
                default: patt = 4'b0000;
            endcase
        end
    end

    assign coils = run_clean ? patt : 4'b0000; // STOP 시 모든 코일 OFF

endmodule

// ---------------------- 디바운스 모듈 ----------------------
module debounce #(
    parameter integer CLK_HZ = 125_000_000,
    parameter integer MS     = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    output reg  dout
);
    localparam integer CNT_MAX = (CLK_HZ/1250)*MS;
    reg din_q1, din_q2;
    reg [31:0] cnt;

    // 2FF 동기화
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            din_q1 <= 1'b0;
            din_q2 <= 1'b0;
        end else begin
            din_q1 <= din;
            din_q2 <= din_q1;
        end
    end

    // 안정 시간 카운트
    always @(posedge clk or posedge rst_n) begin
        if (rst_n) begin
            cnt  <= 0;
            dout <= 0;
        end else if (din_q2 == dout) begin
            cnt <= 0; // 상태 유지
        end else begin
            if (cnt >= CNT_MAX) begin
                dout <= din_q2; // 충분히 유지되면 상태 갱신
                cnt  <= 0;
            end else begin
                cnt <= cnt + 1;
            end
        end
    end
endmodule
```

```xdc
## This file is a general .xdc for the Zybo Z7 Rev. B
## It is compatible with the Zybo Z7-20 and Zybo Z7-10
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

##Clock signal
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

##Switches
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw_run }]; #IO_L19N_T3_VREF_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw_dir }]; #IO_L24P_T3_34 Sch=sw[1]
#set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; #IO_L4N_T0_34 Sch=sw[2]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { rst_n }]; #IO_L9P_T1_DQS_34 Sch=sw[3]
                                                                                                                                 
##Pmod Header JE                                                                                                                  
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports { coils[0] }]; #IO_L4P_T0_34 Sch=je[1]						 
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports { coils[1] }]; #IO_L18N_T2_34 Sch=je[2]                     
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { coils[2] }]; #IO_25_35 Sch=je[3]                          
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports { coils[3] }]; #IO_L19P_T3_35 Sch=je[4]                     
#set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports { je[4] }]; #IO_L3N_T0_DQS_34 Sch=je[7]                  
#set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports { je[5] }]; #IO_L9N_T1_DQS_34 Sch=je[8]                  
#set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { je[6] }]; #IO_L20P_T3_34 Sch=je[9]                     
#set_property -dict { PACKAGE_PIN Y17   IOSTANDARD LVCMOS33 } [get_ports { je[7] }]; #IO_L7N_T1_34 Sch=je[10]                    

```

---

#  AXI 인터페이스

* 1) 스텝 코어 (AXI 외부용, 런타임 제어 핀 방식)
   * 아래는 기존 코드를 런타임 제어 신호로 간소화한 코어입니다.
   * half_step_i, run_i, dir_i, ticks_per_step_i 입력으로 동작
   * 디바운스 제거(리눅스에서 제어하므로 불필요)
   * Active-Low reset (rst_n)
* Tools -> Create and Package New IP
   * Vivado에서는 이 파일들을 Create and Package IP 로 묶어 AXI4-Lite Slave Peripheral 로 등록한 뒤,
   * Zynq PS와 AXI SmartConnect/Interconnect에 연결.
   * coils[3:0]는 기존 XDC(ULN2003) 핀에 매핑합니다.
   * s_axi_aclk 는 PS의 FCLK_CLK0(예: 100MHz 또는 125MHz) 를 사용.

```
// stepper_core.v : runtime-controllable stepper engine (no AXI here)
module stepper_core #(
    parameter integer CLK_HZ = 125_000_000
)(
    input  wire        clk,
    input  wire        rst_n,             // Active-Low Reset
    input  wire        run_i,             // 1=RUN, 0=STOP
    input  wire        dir_i,             // 1=Forward, 0=Backward
    input  wire        half_step_i,       // 1=half-step(8), 0=full-step(4)
    input  wire [31:0] ticks_per_step_i,  // reload value: clk_hz / steps_per_sec
    output wire [3:0]  coils,             // ULN2003 IN1..IN4
    output wire        step_pulse_o,      // 디버깅용(한 스텝 경계 펄스)
    output wire [2:0]  step_idx_o         // 현재 스텝 인덱스
);

    // -------- 타이머 --------
    reg [31:0] tick_cnt;
    wire step_pulse = (tick_cnt == 0);
    assign step_pulse_o = step_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= (ticks_per_step_i>0) ? (ticks_per_step_i-1) : 32'd0;
        end else if (run_i) begin
            tick_cnt <= (tick_cnt==0)
                ? ((ticks_per_step_i>0)?(ticks_per_step_i-1):32'd0)
                : (tick_cnt-1);
        end else begin
            tick_cnt <= (ticks_per_step_i>0) ? (ticks_per_step_i-1) : 32'd0;
        end
    end

    // -------- 스텝 인덱스 --------
    wire [2:0] max_idx = half_step_i ? 3'd7 : 3'd3;
    reg  [2:0] step_idx;
    assign step_idx_o = step_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step_idx <= 3'd0;
        end else if (run_i && step_pulse) begin
            if (dir_i) begin
                step_idx <= (step_idx == max_idx) ? 3'd0 : (step_idx + 1'b1);
            end else begin
                step_idx <= (step_idx == 3'd0) ? max_idx : (step_idx - 1'b1);
            end
        end
    end

    // -------- 패턴 ROM --------
    reg [3:0] patt;
    always @(*) begin
        if (half_step_i) begin
            case (step_idx)
                3'd0: patt = 4'b1000; // A
                3'd1: patt = 4'b1100; // A+B
                3'd2: patt = 4'b0100; // B
                3'd3: patt = 4'b0110; // B+C
                3'd4: patt = 4'b0010; // C
                3'd5: patt = 4'b0011; // C+D
                3'd6: patt = 4'b0001; // D
                3'd7: patt = 4'b1001; // D+A
                default: patt = 4'b0000;
            endcase
        end else begin
            case (step_idx[1:0])
                2'd0: patt = 4'b1100; // A+B
                2'd1: patt = 4'b0110; // B+C
                2'd2: patt = 4'b0011; // C+D
                2'd3: patt = 4'b1001; // D+A
                default: patt = 4'b0000;
            endcase
        end
    end

    assign coils = run_i ? patt : 4'b0000;

endmodule
```

