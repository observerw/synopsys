module counter_tb;

  logic       clk   = 1'b0;
  logic       rst_n = 1'b0;
  logic [7:0] count;

  counter dut (
      .clk   (clk),
      .rst_n (rst_n),
      .count (count)
  );

  always #5 clk = ~clk;

  initial begin
    #12 rst_n = 1'b1;
    repeat (10) @(posedge clk);
    #1;
    $display("count=%0d", count);
    if (count !== 8'd10) $fatal(1, "unexpected count");
    $finish;
  end

endmodule
