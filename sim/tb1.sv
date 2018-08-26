/* Testbench */

//`define ENABLE_DDR2LP
//`define ENABLE_HSMC_XCVR
//`define ENABLE_SMA
//`define ENABLE_REFCLK
`define ENABLE_GPIO

`default_nettype none

module tb1;
   timeunit 1ns;
   timeprecision 1ps;

   /* ADC (1.2 V) */
   wire        ADC_CONVST;
   wire        ADC_SCK;
   wire        ADC_SDI;
   bit         ADC_SDO;

   /* AUD (2.5 V) */
   bit         AUD_ADCDAT;
   wire        AUD_ADCLRCK;
   wire        AUD_BCLK;
   wire        AUD_DACDAT;
   wire        AUD_DACLRCK;
   wire        AUD_XCK;

   /* CLOCK */
   bit         CLOCK_125_p;    // LVDS
   bit         CLOCK_50_B5B;   // 3.3-V LVTTL
   bit         CLOCK_50_B6A;
   bit         CLOCK_50_B7A;   // 2.5 V
   bit         CLOCK_50_B8A;

   /* CPU */
   bit         CPU_RESET_n;    // 3.3V LVTTL

`ifdef ENABLE_DDR2LP
   /* DDR2LP (1.2-V HSUL) */
   wire [9:0]  DDR2LP_CA;
   wire [1:0]  DDR2LP_CKE;
   wire        DDR2LP_CK_n;    // DIFFERENTIAL 1.2-V HSUL
   wire        DDR2LP_CK_p;    // DIFFERENTIAL 1.2-V HSUL
   wire [1:0]  DDR2LP_CS_n;
   wire [3:0]  DDR2LP_DM;
   wire [31:0] DDR2LP_DQ;
   wire [3:0]  DDR2LP_DQS_n;   // DIFFERENTIAL 1.2-V HSUL
   wire [3:0]  DDR2LP_DQS_p;   // DIFFERENTIAL 1.2-V HSUL
   bit         DDR2LP_OCT_RZQ; // 1.2 V
`endif

`ifdef ENABLE_GPIO
   /* GPIO (3.3-V LVTTL) */
   wire [35:0] GPIO;
`else
   /* HEX2 (1.2 V) */
   wire [6:0]  HEX2;

   /* HEX3 (1.2 V) */
   wire [6:0]  HEX3;


`endif

   /* HDMI */
   wire        HDMI_TX_CLK;
   wire [23:0] HDMI_TX_D;
   wire        HDMI_TX_DE;
   wire        HDMI_TX_HS;
   bit         HDMI_TX_INT;
   wire        HDMI_TX_VS;

   /* HEX0 */
   wire [6:0]  HEX0;

   /* HEX1 */
   wire [6:0]  HEX1;


   /* HSMC (2.5 V) */
   bit         HSMC_CLKIN0;
   bit  [2:1]  HSMC_CLKIN_n;
   bit  [2:1]  HSMC_CLKIN_p;
   wire        HSMC_CLKOUT0;
   wire [2:1]  HSMC_CLKOUT_n;
   wire [2:1]  HSMC_CLKOUT_p;
   wire [3:0]  HSMC_D;
`ifdef ENABLE_HSMC_XCVR
   bit  [3:0]  HSMC_GXB_RX_p;  //  1.5-V PCML
   wire [3:0]  HSMC_GXB_TX_p;  //  1.5-V PCML
`endif
   wire [16:0] HSMC_RX_n;
   wire [16:0] HSMC_RX_p;
   wire [16:0] HSMC_TX_n;
   wire [16:0] HSMC_TX_p;


   /* I2C (2.5 V) */
   wire        I2C_SCL;
   wire        I2C_SDA;

   /* KEY (1.2 V) */
   bit  [3:0]  KEY;

   /* LEDG (2.5 V) */
   wire [7:0]  LEDG;

   /* LEDR (2.5 V) */
   wire [9:0]  LEDR;

`ifdef ENABLE_REFCLK
   /* REFCLK (1.5-V PCML) */
   bit         REFCLK_p0;
   bit         REFCLK_p1;
`endif

   /* SD (3.3-V LVTTL) */
   wire        SD_CLK;
   wire        SD_CMD;
   wire [3:0]  SD_DAT;

`ifdef ENABLE_SMA
   /* SMA (1.5-V PCML) */
   bit         SMA_GXB_RX_p;
   wire        SMA_GXB_TX_p;
`endif

   /* SRAM (3.3-V LVTTL) */
   wire [17:0] SRAM_A;
   wire        SRAM_CE_n;
   wire [15:0] SRAM_D;
   wire        SRAM_LB_n;
   wire        SRAM_OE_n;
   wire        SRAM_UB_n;
   wire        SRAM_WE_n;

   /* SW (1.2 V) */
   bit  [9:0]  SW;

   /* UART (2.5 V) */
   bit         UART_RX;
   wire        UART_TX;

   wire \CLOCK_125_p(n) ; // added for j1_wb.vo

   defparam tb1.dut.wb_rom.waitcycles = 0;
   defparam tb1.dut.wb_ram.waitcycles = 0;
   defparam tb1.dut.wb_io1.waitcycles = 0;
   defparam tb1.dut.wb_io2.waitcycles = 0;
   defparam tb1.dut.wb_io3.waitcycles = 0;

   top_c5gx dut(.*);

`ifdef ASSERT_ON
   bind dut wb_checker wbm_checker(wbm);
   bind dut wb_checker wbs1_checker(wbs1);
   bind dut wb_checker wbs2_checker(wbs2);
   bind dut wb_checker wbs3_checker(wbs3);
   bind dut wb_checker wbs4_checker(wbs4);
   bind dut wb_checker wbs5_checker(wbs5);
`endif

   assign GPIO[31:16] = $random;

   always #10ns CLOCK_50_B5B = ~CLOCK_50_B5B;

   initial
     begin:main
	$timeformat(-9, 3, " ns");

        /* load ROM image */
	$readmemh("j1.hex", tb1.dut.wb_rom.rom.mem); // comment when using j1_wb.vo

	CPU_RESET_n = 1'b0;
        KEY         = 4'b1111;
        SW          = 10'h35a;
        #30ns;
	CPU_RESET_n = 1'b1;

	#30us $finish;
     end:main
endmodule

`resetall
