// слейв APB: сложение по И с накоплением
// результат = результат И добавляемое значение

`timescale 1ns/1ps

module apb_and_acc
(
  input  logic        pclk,     // синхросигнал
  input  logic        presetn,  // сигнал сброса (инверсный)
  input  logic [31:0] paddr,    // адрес обращения
  input  logic [31:0] pwdata,   // данные для записи
  input  logic        psel,     // признак выбора устройства
  input  logic        penable,  // признак активной транзакции
  input  logic        pwrite,   // признак операции записи
  output logic        pready,   // признак готовности от устройства
  output logic        pslverr,  // признак ошибки при обращении
  output logic [31:0] prdata    // прочитанные данные
);

logic [31:0] data_reg;     // 0x0 - добавляемое значение
logic        auto_mode;    // 0x4 - бит 2 контрольного регистра
logic [31:0] result_reg;   // 0x8 - текущий результат

// состояния автомата APB 
enum logic [1:0] {
  APB_SETUP,      // ждем, когда мастер начнет обмен
  APB_W_ENABLE,   // выполняем запись
  APB_R_ENABLE    // выполняем чтение
} apb_st;

always @(posedge pclk)
if (!presetn)                  // сброс
begin
  prdata <= '0;
  pslverr <= 1'b0;
  pready <= 1'b0;
  data_reg <= '0;
  auto_mode <= 1'b0;
  result_reg <= 32'hFFFF_FFFF; // начальное значение для И
  apb_st <= APB_SETUP;
end
else
begin
  case (apb_st)
    APB_SETUP:
    begin
      prdata <= '0;
      pready <= 1'b0;
      pslverr <= 1'b0;
      if (psel && !penable)              // мастер начал обмен
      begin
        if (pwrite)
          apb_st <= APB_W_ENABLE;        // запись
        else
          apb_st <= APB_R_ENABLE;        // чтение
      end
    end

    APB_W_ENABLE:
    begin
      if (psel && penable && pwrite)     // вторая фаза записи
      begin
        pready <= 1'b1;
        case (paddr[7:0])
          8'h0: begin                    // запись добавляемого значения
            data_reg <= pwdata;
            if (auto_mode)               // сразу накапливаем
            begin
              result_reg <= result_reg & pwdata;
              $display("[%0t] SLAVE: DATA = 0x%h, AUTO: RESULT = 0x%h & 0x%h = 0x%h",
                       $time, pwdata, result_reg, pwdata, result_reg & pwdata);
            end
            else
              $display("[%0t] SLAVE: DATA = 0x%h", $time, pwdata);
          end
          8'h4: begin                    // запись в контрольный регистр
            auto_mode <= pwdata[2];
            if (pwdata[1])               // CLEAR важнее START
            begin
              result_reg <= 32'hFFFF_FFFF;
              $display("[%0t] SLAVE: CTRL = 0x%h, CLEAR: RESULT = 0xffffffff", $time, pwdata);
            end
            else if (pwdata[0])          // START: одно накопление
            begin
              result_reg <= result_reg & data_reg;
              $display("[%0t] SLAVE: CTRL = 0x%h, START: RESULT = 0x%h & 0x%h = 0x%h",
                       $time, pwdata, result_reg, data_reg, result_reg & data_reg);
            end
            else
              $display("[%0t] SLAVE: CTRL = 0x%h, AUTO = %b", $time, pwdata, pwdata[2]);
          end
          default: begin                 // 0x8 (только чтение) и неверные адреса
            pslverr <= 1'b1;
            $display("[%0t] SLAVE: error, write to addr 0x%h is not allowed", $time, paddr);
          end
        endcase
        apb_st <= APB_SETUP;
      end
    end

    APB_R_ENABLE:
    begin
      if (psel && penable && !pwrite)    // вторая фаза чтения
      begin
        pready <= 1'b1;
        case (paddr[7:0])
          8'h0: begin                    // чтение добавляемого значения
            prdata <= data_reg;
            $display("[%0t] SLAVE: read DATA = 0x%h", $time, data_reg);
          end
          8'h4: begin                    // чтение контрольного регистра
            prdata <= {29'b0, auto_mode, 2'b00};
            $display("[%0t] SLAVE: read CTRL, AUTO = %b", $time, auto_mode);
          end
          8'h8: begin                    // чтение результата
            prdata <= result_reg;
            $display("[%0t] SLAVE: read RESULT = 0x%h", $time, result_reg);
          end
          default: begin                 // неверный адрес
            pslverr <= 1'b1;
            $display("[%0t] SLAVE: error, read from wrong addr 0x%h", $time, paddr);
          end
        endcase
        apb_st <= APB_SETUP;
      end
    end

    default:                             // неизвестное состояние - возврат в начало
    begin
      pslverr <= 1'b1;
      apb_st <= APB_SETUP;
    end
  endcase
end

endmodule
