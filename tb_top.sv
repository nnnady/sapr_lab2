
`timescale 1ns/1ps

module tb_top;

// провода шины APB
logic pclk;
logic presetn;
logic psel;
logic penable;
logic pwrite;
logic [31:0] paddr;
logic [31:0] pwdata;
wire [31:0] prdata;
wire pready;
wire pslverr;

parameter BASE   = 32'h7000_0000;   // адрес устройства
parameter DATA   = BASE + 32'h0;    // добавляемое значение
parameter CTRL   = BASE + 32'h4;    // контрольный регистр
parameter RESULT = BASE + 32'h8;    // результат

// биты контрольного регистра
parameter START = 32'h1;
parameter CLEAR = 32'h2;
parameter AUTO  = 32'h4;

logic [31:0] rd;           // прочитанное значение
int errors = 0;            // счетчик ошибок

// мастер из ЛР1
apb_master master
(
  .pclk, .presetn,
  .psel, .penable, .pwrite, .paddr, .pwdata,
  .prdata, .pready, .pslverr
);

// проверяемое устройство
apb_and_acc DUT
(
  .pclk, .presetn,
  .psel, .penable, .pwrite, .paddr, .pwdata,
  .prdata, .pready, .pslverr
);

// чтение регистра и сравнение с ожидаемым значением
task check(input logic [31:0] addr, input logic [31:0] expected);
  master.apb_read(addr, rd);
  if (rd === expected)
    $display("OK:     addr 0x%h = 0x%h", addr, rd);
  else begin
    $display("ERROR:  addr 0x%h = 0x%h, expected 0x%h", addr, rd, expected);
    errors++;
  end
endtask

// тактовый сигнал, период 20 нс
always
  #10ns pclk = ~pclk;

initial
begin
  $timeformat(-9, 0, " ns", 8);
  pclk = 0;
  presetn = 1'b1;
  repeat (2) @(posedge pclk);
  presetn = 1'b0;                 // сброс
  repeat (3) @(posedge pclk);
  presetn = 1'b1;
  repeat (2) @(posedge pclk);

  // после сброса результат = FFFF_FFFF
  check(RESULT, 32'hFFFF_FFFF);

  //первое накопление: FFFF_FFFF & F0F0_FFFF = F0F0_FFFF
  master.apb_write(DATA, 32'hF0F0_FFFF);
  master.apb_write(CTRL, START);
  check(RESULT, 32'hF0F0_FFFF);

  //второе накопление: F0F0_FFFF & FF00_FF0F = F000_FF0F
  master.apb_write(DATA, 32'hFF00_FF0F);
  master.apb_write(CTRL, START);
  check(RESULT, 32'hF000_FF0F);

  //сброс результата командой CLEAR
  master.apb_write(CTRL, CLEAR);
  check(RESULT, 32'hFFFF_FFFF);

  if (errors == 0)
    $display("TEST PASSED");
  else
    $display("TEST FAILED, errors: %0d", errors);

  repeat (5) @(posedge pclk);
`ifdef VERILATOR
  $finish;                        // для подсчета покрытия нужно нормальное завершение
`else
  $stop;                          // в ModelSim - остановка моделирования
`endif
end

endmodule
