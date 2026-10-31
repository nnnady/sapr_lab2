// запуск модели Verilator и сохранение покрытия в coverage.dat
#include <memory>
#include "verilated.h"
#include "verilated_cov.h"
#include "Vtb_top.h"

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> ctx{new VerilatedContext};
    ctx->commandArgs(argc, argv);
    const std::unique_ptr<Vtb_top> top{new Vtb_top{ctx.get()}};
    while (!ctx->gotFinish()) {           // крутим модель, пока тест не вызовет $finish
        top->eval();
        if (!top->eventsPending()) break;
        ctx->time(top->nextTimeSlot());
    }
    top->final();
    ctx->coveragep()->write("coverage.dat");   // сохраняем покрытие
    return 0;
}
