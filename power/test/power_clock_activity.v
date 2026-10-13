module power_clock_activity (clk, other, select, data, q, observe);
  input clk, other, select, data;
  output q, observe;
  wire mux_clk;

  MUX2_X1 mux1 (.A(clk), .B(other), .S(select), .Z(mux_clk));
  DFF_X1 reg1 (.D(data), .CK(mux_clk), .Q(q));
  INV_X1 inv1 (.A(mux_clk), .ZN(observe));
endmodule
