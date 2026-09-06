import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_project(dut):
    dut._log.info("Trit NPU Testi Baslatiliyor...")

    # Saat sinyalini başlatıyoruz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Donanımı Sıfırla (Reset)
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("START Sinyali Veriliyor...")
    # ui_in[0] = 1 (START)
    # ui_in[2:1] = 01 (Nöron 1'i seç -> PyTorch sonucumuz 69'du!)
    # İkili: 0000_0011 -> Onluk: 3
    dut.ui_in.value = 3

    # Çipin kendi FSM'si ile hesaplamayı bitirmesi için 15 saat darbesi bekle
    await ClockCycles(dut.clk, 15)

    dut._log.info(f"Cipin Urettigi Cikti: {int(dut.uo_out.value)}")

    # Nöron 1 çıktısının PyTorch ile eşleştiğini doğrula (69 olmalı!)
    assert int(dut.uo_out.value) == 69, f"Hata! Beklenen 69, Cikan: {dut.uo_out.value}"
    dut._log.info("TEST BASARILI! Trit NPU Silikon Seviyesinde Kusursuz Calisiyor.")
