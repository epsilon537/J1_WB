/* J1 Forth CPU with Wishbone interface
 *
 * based on
 *     http://excamera.com/sphinx/fpga-j1.html
 *     https://github.com/ros-drivers/wge100_driver
 *     jamesb@willowgarage.com
 */

`default_nettype none

module j1_wb
  #(parameter dstack_depth = 32, // data stack depth (max. 32)
    parameter rstack_depth = 32) // return stack depth (max. 32)
   (input wire   clk,            // clock
    input wire   reset,          // reset
    if_wb.master wb);            // Wishbone bus

   import types::*;

   /* instruction fetch */
   logic [15:0]  instr, instr_r;         // instruction
   logic [12:0] _npc, npc,              // processor counter
                pc;

   /* select instruction types */
   logic is_lit, is_ubranch, is_zbranch, is_call, is_alu;


   /* data stack */
   logic [4:0]  _dsp, dsp;            // data stack pointer
   logic [15:0] _st0, st0;            // top of data stack
   logic [15:0] st1;                  // next of data stack
   logic        _dstkW;               // data stack write

   /* return stack */
   logic [4:0]  _rsp, rsp;            // return stack pointer
   logic [15:0] rst0;                 // top of return stack
   logic [15:0] _rstkD;               // return stack data
   logic        _rstkW;               // return stack write

   /* memory access control */
   logic        is_ld, is_ld_r,
                is_st, is_st_r,
                is_mem, is_mem_r;

   /* work around missing modport expressions */
   wire  [15:0] wb_dat_i;
   logic [15:0] wb_dat_o;

`ifdef NO_MODPORT_EXPRESSIONS
   assign wb_dat_i = wb.dat_s;
   assign wb.dat_m = wb_dat_o;
`else
   assign wb_dat_i = wb.dat_i;
   assign wb.dat_o = wb_dat_o;
`endif

   /* data stack */
   register_file
     #(dstack_depth)
   dstack
     (.clk,
      .wen (_dstkW),
      .wa  (_dsp),
      .ra  (dsp),
      .d   (st0),
      .q   (st1));

   /* return stack */
   register_file
     #(rstack_depth)
   rstack
     (.clk,
      .wen (_rstkW),
      .wa  (_rsp),
      .ra  (rsp),
      .d   (_rstkD),
      .q   (rst0));

   /* select instruction types */
   always_comb
     begin
	is_lit     = instr[15];
	is_ubranch = instr[15:13] == TAG_UBRANCH;
	is_zbranch = instr[15:13] == TAG_ZBRANCH;
	is_call    = instr[15:13] == TAG_CALL;
	is_alu     = instr[15:13] == TAG_ALU;
        is_ld      = is_alu && instr[11:8] == OP_AT;
        is_st      = is_alu & instr[5];
        is_mem     = is_ld | is_st;
        is_mem_r   = is_ld_r | is_st_r;
     end

   /* calculate next TOS value */
   always_comb
     if (is_lit)
       _st0 = {1'b0, instr[14:0]};
     else if (is_ld_r && wb.ack)
       _st0 = wb_dat_i;
     else
       begin
	  var op_t op;

	  unique case (1'b1)
	    is_ubranch:  op = OP_T;
	    is_zbranch:  op = OP_N;
	    is_call   :  op = OP_T;
	    is_alu    :  op = op_t'(instr[11:8]);
	    default      op = op_t'('x);
	  endcase

	  case (op)
            OP_T         : _st0 = st0;
            OP_N         : _st0 = st1;
            OP_T_PLUS_N  : _st0 = st0 + st1;
            OP_T_AND_N   : _st0 = st0 & st1;
            OP_T_IOR_N   : _st0 = st0 | st1;
            OP_T_XOR_N   : _st0 = st0 ^ st1;
            OP_INV_T     : _st0 = ~st0;
            OP_N_EQ_T    : _st0 = {16{(st1 == st0)}};
            OP_N_LS_T    : _st0 = {16{($signed(st1) < $signed(st0))}};
            OP_N_RSHIFT_T: _st0 = st1 >> st0[3:0];
            OP_T_MINUS_1 : _st0 = st0 - 16'd1;
            OP_R         : _st0 = rst0;
            OP_AT        : _st0 = st0; // delayed due to bus sharing
            OP_N_LSHIFT_T: _st0 = st1 << st0[3:0];
            OP_DEPTH     : _st0 = {3'b0, rsp, 3'b0, dsp};
            OP_N_ULS_T   : _st0 = {16{(st1 < st0)}};
            default        _st0 = 'x;
	  endcase
       end

   /* data and return stack control */
   always_comb
     begin
	_dsp   = dsp;
	_dstkW = 1'b0;
	_rsp   = rsp;
	_rstkW = 1'b0;
	_rstkD = 16'hx;

	/* literals */
	if (is_lit)
	  begin
	     _dsp   = dsp + 5'd1;
	     _dstkW = 1'b1;
	  end
	/* ALU operations */
	else if (is_alu)
	  begin
	     logic signed [4:0] dd, rd; // stack delta

	     dd     = instr[1:0];
	     rd     = instr[3:2];
	     _dsp   = dsp + dd;
	     _dstkW = instr[7];
	     _rsp   = rsp + rd;
	     _rstkW = instr[6];
	     _rstkD = st0;
	  end
	else
	  /* branch/call */
	  begin
	     if (is_zbranch)
	       /* predicated jump is like DROP */
               _dsp = dsp - 5'd1;

	     if (is_call)
	       begin
		  _rsp   = rsp + 5'd1;
		  _rstkW = 1'b1;
		  _rstkD = npc << 1;
	       end
	  end
     end

   /* control PC */
   always_comb
     if (is_ubranch || (is_zbranch && (st0 == 16'h0)) || is_call)
       pc = instr[12:0];
     else if (is_alu && instr[12])
       pc = rst0[13:1];
     else
       pc = npc;
   
   always_comb _npc = is_mem ? pc : pc + 13'd1;

   /* update PC and stacks */
   always_ff @(posedge clk or posedge reset)
     if (reset)
       begin
	  npc  <= 13'h0;
	  dsp <=  5'd0;
	  st0 <= 16'h0;
	  rsp <=  5'd0;
       end
     else
       begin
	  npc  <= _npc;
	  dsp <= _dsp;
	  st0 <= _st0;
	  rsp <= _rsp;
       end

   /* Wishbone */
   always_ff @(posedge clk)
     if (reset)
       is_ld_r <= 1'b0;
     else
       if (is_ld)
         is_ld_r <= 1'b1;
       else if (wb.ack)
         is_ld_r <= 1'b0;
   
   always_ff @(posedge clk)
     if (reset)
       is_st_r <= 1'b0;
     else
       if (is_st)
         is_st_r <= 1'b1;
       else if (wb.ack)
         is_st_r <= 1'b0;
   
   always_comb
     begin
        wb.cyc   = ~reset;
        wb.stb   = ~reset;
 	wb_dat_o = st1;

        if (is_mem)
          begin
	     wb.adr = {1'b0, st0[15:1]};
             wb.we  = is_st;
          end
        else
          begin
             wb.adr = {3'b0, pc};
             wb.we  = 1'b0;
          end

        if (is_mem_r)
          instr = 16'h6000; // NOOP
        else
          instr = wb_dat_i;
     end
endmodule

`resetall
