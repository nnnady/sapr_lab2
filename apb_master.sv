// мастер APB
// мастер - это устройство, которое начинает обмен: говорит слейву адрес,
// что делать (запись или чтение) и передает данные.
`timescale 1ns/1ps   // единица времени 1 нс, точность 1 пс

module apb_master
(
  input  logic        pclk,     // синхросигнал
  input  logic        presetn,  // сигнал сброса (инверсный, сброс когда 0)
  output logic        psel,     // признак выбора устройства (1 - обращаемся к слейву)
  output logic        penable,  // признак активной транзакции (вторая фаза обмена)
  output logic        pwrite,   // признак операции записи (1 - запись, 0 - чтение)
  output logic [31:0] paddr,    // адрес обращения
  output logic [31:0] pwdata,   // данные для записи
  input  logic [31:0] prdata,   // прочитанные данные (приходят от слейва)
  input  logic        pready,   // признак готовности от устройства
  input  logic        pslverr   // признак ошибки от слейва
);

// в начале моделирования все сигналы шины ставим в 0
initial
begin
  psel = '0;      // '0 - все биты равны нулю
  penable = '0;
  pwrite = '0;
  paddr = '0;
  pwdata = '0;
end

// задача записи: addr - куда пишем, data - что пишем
// automatic - у каждого вызова задачи свои переменные
task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
  wait ((penable == 0) && (pready == 0));   // ждем, пока шина освободится
  @(posedge pclk);                          // ждем фронт тактового сигнала
  // 1 фаза (SETUP): выбираем слейв и выставляем адрес и данные
  psel <= 1'b1;
  paddr[31:0] <= addr[31:0];
  pwdata[31:0] <= data[31:0];
  pwrite <= 1'b1;                           // 1 = запись
  @(posedge pclk);                          // следующий такт
  // 2 фаза (ENABLE): penable = 1
  penable <= 1'b1;
  @(posedge pclk);
  wait (pready == 1'b1);                    // ждем, пока слейв ответит, что готов
  @(posedge pclk);
  if (pslverr)                              // если слейв выставил ошибку - пишем сообщение
    $display("[%0t] MASTER: error on write, addr 0x%h", $time, addr);
  // запись закончена, снимаем сигналы
  psel <= 1'b0;
  penable <= 1'b0;
  pwrite <= 1'b0;
  @(posedge pclk);                          // пауза в один такт
endtask

// задача чтения: addr - откуда читаем, data - сюда вернется прочитанное
task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
  wait ((penable == 0) && (pready == 0));   // ждем, пока шина освободится
  @(posedge pclk);
  // 1 фаза: выбираем слейв, pwrite = 0 значит чтение, выставляем адрес
  psel <= 1'b1;
  pwrite <= 1'b0;
  paddr[31:0] <= addr[31:0];
  @(posedge pclk);
  // 2 фаза
  penable <= 1'b1;
  @(posedge pclk);
  wait (pready == 1'b1);                    // ждем ответ слейва
  @(posedge pclk);
  if (pslverr)
    $display("[%0t] MASTER: error on read, addr 0x%h", $time, addr);
  data = prdata;                            // запоминаем прочитанные данные
  // чтение закончено, снимаем сигналы
  psel <= 1'b0;
  penable <= 1'b0;
  @(posedge pclk);
endtask

endmodule
