/* SPRAM interface wrapper */

module spram_wrapper
  (input wire    clk,
   if_dbus.slave dbus);

   spram
     #(.size('h1000))
   spram
     (.clock   (clk),
      .address (dbus.adr[11:0]),
      .data    (dbus.dat_m),
      .q       (dbus.dat_s),
      .wren    (dbus.we),
      .cen     (dbus.re | dbus.we));
endmodule
