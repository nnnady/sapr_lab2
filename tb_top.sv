
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
int slverr_cnt = 0;        // сколько раз слейв выставил pslverr
logic [31:0] expected;     // ожидаемый результат для случайного теста
logic [31:0] value;        // случайное добавляемое значение
integer seed = 11;         // начальное число для $random


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

// считаем ответы слейва с ошибкой (pslverr = 1 вместе с pready)
always @(posedge pclk)
  if (pready && pslverr)
    slverr_cnt++;

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

  //после сброса результат = FFFF_FFFF
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

  //доработка тестов

  //чтение регистров DATA и CTRL
  check(DATA, 32'hFF00_FF0F);       // последнее записанное значение
  check(CTRL, 32'h0);               // AUTO выключен, START и CLEAR при чтении всегда 0

  //режим AUTO: накопление сразу при записи в DATA
  master.apb_write(CTRL, AUTO);
  check(CTRL, AUTO);                // AUTO включен
  master.apb_write(DATA, 32'h1234_5678);
  check(RESULT, 32'h1234_5678);     // FFFF_FFFF & 1234_5678
  master.apb_write(DATA, 32'h0F0F_FFFF);
  check(RESULT, 32'h0204_5678);     // 1234_5678 & 0F0F_FFFF

  //запись в CTRL без START и CLEAR: AUTO выключается, результат не меняется
  master.apb_write(CTRL, 32'h0);
  master.apb_write(DATA, 32'h0);
  check(RESULT, 32'h0204_5678);

  //START и CLEAR одновременно
  master.apb_write(DATA, 32'h0000_00FF);
  master.apb_write(CTRL, START | CLEAR);
  check(RESULT, 32'hFFFF_FFFF);

  //ошибки: запись в RESULT (только чтение), запись и чтение по неверным адресам
  master.apb_write(RESULT, 32'h1);
  master.apb_write(BASE + 32'hC, 32'h1);
  master.apb_read(BASE + 32'h10, rd);
  master.apb_read(32'hFFFF_FFF3, rd); // совсем чужой адрес: младший байт F3 - такого регистра нет
  check(RESULT, 32'hFFFF_FFFF);     // результат не испортился
  if (slverr_cnt == 4)
    $display("OK:     pslverr = 1 in all 4 wrong accesses");
  else begin
    $display("ERROR:  pslverr count = %0d, expected 4", slverr_cnt);
    errors++;
  end

  //случайный тест: 20 случайных значений, ожидаемый результат считаем сами
  expected = 32'hFFFF_FFFF;
  for (int i = 0; i < 20; i++) begin
    if (i % 4 == 0) begin           // каждые 4 шага сбрасываем, чтобы биты снова стали 1
      master.apb_write(CTRL, CLEAR);
      expected = 32'hFFFF_FFFF;
    end
    value = $random(seed);          // при каждом запуске одна и та же последовательность
    master.apb_write(DATA, value);
    master.apb_write(CTRL, START);
    expected = expected & value;
    check(RESULT, expected);
  end

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
