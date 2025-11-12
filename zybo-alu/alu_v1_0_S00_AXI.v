`timescale 1 ns / 1 ps

module alu_v1_0_S00_AXI #
(
  // Users to add parameters here

  // User parameters ends
  // Do not modify the parameters beyond this line

  // Width of S_AXI data bus
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  // Width of S_AXI address bus
  parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
  // Users to add ports here

  // User ports ends
  // Do not modify the ports beyond this line

  // Global Clock Signal
  input  wire                          S_AXI_ACLK,
  // Global Reset Signal. This Signal is Active LOW
  input  wire                          S_AXI_ARESETN,
  // Write address (issued by master, acceped by Slave)
  input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
  // Write channel Protection type.
  input  wire [2:0]                    S_AXI_AWPROT,
  // Write address valid.
  input  wire                          S_AXI_AWVALID,
  // Write address ready.
  output wire                          S_AXI_AWREADY,
  // Write data (issued by master, acceped by Slave) 
  input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
  // Write strobes.
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
  // Write valid.
  input  wire                          S_AXI_WVALID,
  // Write ready.
  output wire                          S_AXI_WREADY,
  // Write response.
  output wire [1:0]                    S_AXI_BRESP,
  // Write response valid.
  output wire                          S_AXI_BVALID,
  // Response ready.
  input  wire                          S_AXI_BREADY,
  // Read address (issued by master, acceped by Slave)
  input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
  // Protection type.
  input  wire [2:0]                    S_AXI_ARPROT,
  // Read address valid.
  input  wire                          S_AXI_ARVALID,
  // Read address ready.
  output wire                          S_AXI_ARREADY,
  // Read data (issued by slave)
  output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
  // Read response.
  output wire [1:0]                    S_AXI_RRESP,
  // Read valid.
  output wire                          S_AXI_RVALID,
  // Read ready.
  input  wire                          S_AXI_RREADY
);

  // AXI4LITE signals
  reg  [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
  reg                           axi_awready;
  reg                           axi_wready;
  reg  [1:0]                    axi_bresp;
  reg                           axi_bvalid;
  reg  [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
  reg                           axi_arready;
  reg  [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
  reg  [1:0]                    axi_rresp;
  reg                           axi_rvalid;

  // local parameter for addressing 32/64 bit
  localparam integer ADDR_LSB          = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 1;

  //----------------------------------------------
  //-- User logic register space
  //----------------------------------------------
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // ★ ALU 결과를 래치(읽기 전용)
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;

  wire                         slv_reg_rden;
  wire                         slv_reg_wren;
  reg  [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
  integer                      byte_index;
  reg                          aw_en;

  // I/O Connections assignments
  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RDATA   = axi_rdata;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;

  // ---------------------------------------------
  // Write address channel
  // ---------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awready <= 1'b0;
      aw_en       <= 1'b1;
    end else begin
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awready <= 1'b1;
        aw_en       <= 1'b0;
      end else if (S_AXI_BREADY && axi_bvalid) begin
        aw_en       <= 1'b1;
        axi_awready <= 1'b0;
      end else begin
        axi_awready <= 1'b0;
      end
    end
  end

  // latch AWADDR
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awaddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
    end else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
      axi_awaddr <= S_AXI_AWADDR;
    end
  end

  // ---------------------------------------------
  // Write data channel
  // ---------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_wready <= 1'b0;
    end else begin
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
        axi_wready <= 1'b1;
      end else begin
        axi_wready <= 1'b0;
      end
    end
  end

  // ---------------------------------------------
  // Write logic to slave regs
  // ---------------------------------------------
  assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      slv_reg0 <= {C_S_AXI_DATA_WIDTH{1'b0}};
      slv_reg1 <= {C_S_AXI_DATA_WIDTH{1'b0}}; // ★ reset
      slv_reg2 <= {C_S_AXI_DATA_WIDTH{1'b0}};
      slv_reg3 <= {C_S_AXI_DATA_WIDTH{1'b0}};
    end else begin
      // AXI write strobes
      if (slv_reg_wren) begin
        case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
          2'h0: begin
            for (byte_index=0; byte_index<=(C_S_AXI_DATA_WIDTH/8)-1; byte_index=byte_index+1)
              if (S_AXI_WSTRB[byte_index])
                slv_reg0[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
          end
          2'h1: begin
            // ★ CHANGED: slv_reg1는 읽기 전용(ALU 결과 래치 전용). AXI로 쓰기 금지.
            // (아무 동작 안 함)
          end
          2'h2: begin
            for (byte_index=0; byte_index<=(C_S_AXI_DATA_WIDTH/8)-1; byte_index=byte_index+1)
              if (S_AXI_WSTRB[byte_index])
                slv_reg2[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
          end
          2'h3: begin
            for (byte_index=0; byte_index<=(C_S_AXI_DATA_WIDTH/8)-1; byte_index=byte_index+1)
              if (S_AXI_WSTRB[byte_index])
                slv_reg3[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];
          end
          default: begin
            // no-op
          end
        endcase
      end

      // ★ CHANGED:
      // 같은 always 블록(단일 드라이브)에서 ALU 결과를 래치
      // enable (slv_reg0[3])이 1이면 결과를 slv_reg1[15:0]에 저장
      // 상위 16비트는 0으로 확장
      if (slv_reg0[3]) begin
        slv_reg1 <= {16'h0000, alu_result};
      end
    end
  end

  // ---------------------------------------------
  // Write response channel
  // ---------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_bvalid <= 1'b0;
      axi_bresp  <= 2'b00;
    end else begin
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
        axi_bvalid <= 1'b1;
        axi_bresp  <= 2'b00; // OKAY
      end else if (S_AXI_BREADY && axi_bvalid) begin
        axi_bvalid <= 1'b0;
      end
    end
  end

  // ---------------------------------------------
  // Read address channel
  // ---------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_arready <= 1'b0;
      axi_araddr  <= {C_S_AXI_ADDR_WIDTH{1'b0}}; // ★ CHANGED: 폭 정렬
    end else begin
      if (~axi_arready && S_AXI_ARVALID) begin
        axi_arready <= 1'b1;
        axi_araddr  <= S_AXI_ARADDR;
      end else begin
        axi_arready <= 1'b0;
      end
    end
  end

  // ---------------------------------------------
  // Read data channel
  // ---------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rvalid <= 1'b0;
      axi_rresp  <= 2'b00;
    end else begin
      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
        axi_rvalid <= 1'b1;
        axi_rresp  <= 2'b00; // OKAY
      end else if (axi_rvalid && S_AXI_RREADY) begin
        axi_rvalid <= 1'b0;
      end
    end
  end

  // ---------------------------------------------
  // Read mux (combinational)
  // ---------------------------------------------
  assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

  always @(*) begin
    // ★ CHANGED: 블로킹 할당 사용
    case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
      2'h0: reg_data_out = slv_reg0;
      2'h1: reg_data_out = slv_reg1;                 // 래치된 ALU 결과 읽기
      // 2'h1: reg_data_out = {16'h0, alu_result};   // (대안) 라이브 읽기 원하면 이렇게
      2'h2: reg_data_out = slv_reg2;
      2'h3: reg_data_out = slv_reg3;
      default: reg_data_out = {C_S_AXI_DATA_WIDTH{1'b0}};
    endcase
  end

  // read data out (registered)
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
    end else if (slv_reg_rden) begin
      axi_rdata <= reg_data_out;
    end
  end

  // ---------------------------------------------
  // User logic: ALU instance
  // ---------------------------------------------
  wire [15:0] alu_result;

  ALU alu_inst (
    .a      (slv_reg0[31:24]), // 8-bit
    .b      (slv_reg0[23:16]), // 8-bit
    .opcode (slv_reg0[2:0]),   // 3-bit
    .ena    (slv_reg0[3]),     // 1-bit
    .result (alu_result)       // 16-bit
  );

endmodule
