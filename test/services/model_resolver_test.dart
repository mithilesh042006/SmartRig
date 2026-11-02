import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/models/hardware_spec.dart';
import 'package:pc_buildere/services/model_resolver.dart';

void main() {
  const resolver = ModelResolver();

  group('GPU models', () {
    test('similarly named NVIDIA cards stay separate', () {
      final cases = {
        'ASUS Dual GeForce RTX 4070 12GB OC': ('RTX 4070', 200),
        'MSI GeForce RTX 4070 Ti 12GB': ('RTX 4070 TI', 285),
        'Gigabyte GeForce RTX™ 4070 SUPER 12G': ('RTX 4070 SUPER', 220),
        'ZOTAC RTX 4070 Ti SUPER 16GB': ('RTX 4070 TI SUPER', 285),
        'PNY RTX4060Ti 8GB': ('RTX 4060 TI', 165),
        'GeForce GTX 1660 Super': ('GTX 1660 SUPER', 125),
      };
      cases.forEach((title, expected) {
        final gpu = resolver.gpu(title);
        expect(gpu.model, expected.$1, reason: title);
        expect(gpu.boardPowerW, expected.$2, reason: title);
      });
    });

    test('AMD and Intel variants stay separate', () {
      expect(resolver.gpu('Sapphire Radeon RX 7900 XTX').boardPowerW, 355);
      expect(resolver.gpu('XFX Radeon RX 7900 XT').boardPowerW, 315);
      expect(resolver.gpu('PowerColor RX7800XT Hellhound').boardPowerW, 263);
      expect(resolver.gpu('Intel Arc A750 8GB').boardPowerW, 225);
    });

    test('unknown cards stay unknown', () {
      expect(resolver.gpu('Generic Graphics Card 8GB').model, isNull);
      final uncatalogued = resolver.gpu('NVIDIA RTX 9999');
      expect(uncatalogued.model, 'RTX 9999');
      expect(uncatalogued.boardPowerW, isNull);
    });
  });

  group('CPU models', () {
    test('Intel generations resolve to the right socket and power', () {
      final i12 = resolver.cpu('Intel Core i5-12400 Desktop Processor');
      final i13 = resolver.cpu('Intel® Core™ i5-13400 Desktop Processor');
      expect(i12.model, 'I5 12400');
      expect(i13.model, 'I5 13400');
      expect(i12.socket, CpuSocket.lga1700);
      expect(i12.maxPowerW, 117);
      expect(i13.maxPowerW, 148);
      expect(resolver.cpu('Intel Core i5-11400').socket, CpuSocket.lga1200);
      expect(resolver.cpu('Intel Core i7-10700K').socket, CpuSocket.lga1200);
    });

    test('F variants share power data; other variants do not guess', () {
      expect(resolver.cpu('Intel Core i5-12400F').maxPowerW, 117);
      expect(resolver.cpu('Intel Core i7-14700KF').maxPowerW, 253);
      final lowPower = resolver.cpu('Intel Core i7-14700T');
      expect(lowPower.socket, CpuSocket.lga1700);
      expect(lowPower.maxPowerW, isNull);
    });

    test('Core Ultra desktop chips use LGA1851', () {
      final cpu = resolver.cpu('Intel Core Ultra 7 265K');
      expect(cpu.socket, CpuSocket.lga1851);
      expect(cpu.maxPowerW, 250);
    });

    test('Ryzen series resolve to AM4 or AM5', () {
      expect(resolver.cpu('AMD Ryzen 5 5600X').socket, CpuSocket.am4);
      expect(resolver.cpu('AMD Ryzen 7 5800X3D').socket, CpuSocket.am4);
      expect(resolver.cpu('AMD Ryzen 5 7600X').socket, CpuSocket.am5);
      expect(resolver.cpu('AMD Ryzen 7 9800X3D').socket, CpuSocket.am5);
      expect(resolver.cpu('AMD Ryzen 7 8700G').socket, CpuSocket.am5);
    });

    test('X and X3D variants stay separate', () {
      expect(resolver.cpu('AMD Ryzen 7 7700X').maxPowerW, 142);
      expect(resolver.cpu('AMD Ryzen 7 7700').maxPowerW, 88);
      expect(resolver.cpu('AMD RYZEN 9 7950X3D').maxPowerW, 162);
      expect(resolver.cpu('AMD Ryzen 9 7950X').maxPowerW, 230);
    });

    test('laptop chips have no socket', () {
      expect(resolver.cpu('Intel Core i7-12700H').socket, isNull);
      expect(resolver.cpu('Intel Core i5-1240P').socket, isNull);
      expect(resolver.cpu('Intel Core Ultra 7 155H').socket, isNull);
    });

    test('unrecognized titles stay unknown', () {
      final cpu = resolver.cpu('Unknown Processor 8 Core');
      expect(cpu.model, isNull);
      expect(cpu.socket, isNull);
    });
  });

  group('motherboards', () {
    test('chipset decides the socket', () {
      expect(
        resolver.motherboard('ASUS TUF Gaming B650-PLUS WiFi').socket,
        CpuSocket.am5,
      );
      expect(resolver.motherboard('MSI B550M PRO-VDH').socket, CpuSocket.am4);
      expect(
        resolver.motherboard('Gigabyte Z790 AORUS ELITE').socket,
        CpuSocket.lga1700,
      );
      expect(
        resolver.motherboard('ASRock Z890 Pro-A').socket,
        CpuSocket.lga1851,
      );
    });

    test('a socket named in the title is used without a chipset', () {
      final board = resolver.motherboard('Gaming Motherboard Socket AM5');
      expect(board.socket, CpuSocket.am5);
      expect(board.memoryType, MemoryType.ddr5);
    });

    test('a chipset and socket that disagree are a conflict', () {
      final board = resolver.motherboard('B650 Motherboard LGA 1700');
      expect(board.socket, isNull);
      expect(board.socketConflict, isTrue);
    });

    test('memory comes from the title, else a single-generation platform', () {
      expect(
        resolver.motherboard('MSI B760 Gaming Plus DDR4').memoryType,
        MemoryType.ddr4,
      );
      expect(
        resolver.motherboard('ASUS Prime Z790-P D4').memoryType,
        MemoryType.ddr4,
      );
      expect(
        resolver.motherboard('MSI B550 Tomahawk').memoryType,
        MemoryType.ddr4,
      );
      expect(
        resolver.motherboard('ASUS B650 Plus').memoryType,
        MemoryType.ddr5,
      );
      expect(resolver.motherboard('MSI Z790 Tomahawk').memoryType, isNull);
    });

    test('form factors are told apart', () {
      expect(resolver.motherboard('B650 ATX').formFactor, FormFactor.atx);
      expect(
        resolver.motherboard('B650M Micro-ATX').formFactor,
        FormFactor.microAtx,
      );
      expect(resolver.motherboard('B650 mATX').formFactor, FormFactor.microAtx);
      expect(
        resolver.motherboard('B650I Mini-ITX').formFactor,
        FormFactor.miniItx,
      );
      expect(resolver.motherboard('X670E E-ATX').formFactor, FormFactor.eAtx);
    });
  });

  group('from real listings', () {
    test('Core Ultra titles with the word Processor', () {
      final cpu = resolver.cpu('Intel Core Ultra 9 Processor 285K, 24 cores');
      expect(cpu.model, 'ULTRA 9 285K');
      expect(cpu.socket, CpuSocket.lga1851);
    });

    test('RX 9070 GRE stays separate from the RX 9070', () {
      expect(resolver.gpu('ASUS Radeon RX 9070 GRE 12GB').model, 'RX 9070 GRE');
      expect(resolver.gpu('ASRock Radeon RX 9070 16GB').model, 'RX 9070');
    });

    test('mid towers count as ATX without saying so', () {
      expect(
        resolver.pcCase('CORSAIR 4000D Mid-Tower PC Case').maxFormFactor,
        FormFactor.atx,
      );
    });

    test('i3 13th and 14th gen use their 110 W maximum', () {
      expect(resolver.cpu('Intel Core i3-13100').maxPowerW, 110);
      expect(resolver.cpu('Intel Core i3-14100F').maxPowerW, 110);
    });
  });

  group('measurements in titles', () {
    test('RAM stick count', () {
      expect(resolver.ram('32GB (2x16GB) DDR5').stickCount, 2);
      expect(resolver.ram('32GB (2 x 16GB) DDR5').stickCount, 2);
      expect(resolver.ram('64GB Kit 4X16GB DDR4').stickCount, 4);
      expect(resolver.ram('16GB DDR4').stickCount, isNull);
    });

    test('motherboard slots', () {
      expect(resolver.motherboard('B650I Mini-ITX').ramSlots, 2);
      expect(resolver.motherboard('B650 ATX 4 DIMM').ramSlots, 4);
      expect(resolver.motherboard('B650 ATX').ramSlots, isNull);
    });

    test('case clearances', () {
      final pcCase = resolver.pcCase(
        'ATX Case, GPU up to 360mm, CPU Cooler up to 165mm, 3x120mm Fans',
      );
      expect(pcCase.maxGpuLengthMm, 360);
      expect(pcCase.maxCoolerHeightMm, 165);
      expect(
        resolver.pcCase('ATX Case with 120mm Fans').maxGpuLengthMm,
        isNull,
      );
    });

    test('GPU length and cooler height ignore fan sizes', () {
      expect(resolver.gpu('RTX 4070 Length 285mm').lengthMm, 285);
      expect(resolver.gpu('RTX 4070 with 100mm fans').lengthMm, isNull);
      expect(resolver.cooler('Cooler Height 155mm').heightMm, 155);
      expect(resolver.cooler('Cooler 158mm tall').heightMm, 158);
      expect(resolver.cooler('Cooler with 120mm fan').heightMm, isNull);
    });

    test('cooler TDP rating', () {
      expect(resolver.cooler('Air CPU Cooler, 250W TDP').ratedTdpW, 250);
      expect(resolver.cooler('Cooler TDP up to 220W').ratedTdpW, 220);
      expect(resolver.cooler('Cooler 3 x 120mm').ratedTdpW, isNull);
    });
  });

  group('other parts', () {
    test('RAM generation', () {
      expect(
        resolver.ram('Corsair Vengeance 32GB DDR5-6000').memoryType,
        MemoryType.ddr5,
      );
      expect(
        resolver.ram('G.Skill 16GB DDR4 3200').memoryType,
        MemoryType.ddr4,
      );
      expect(resolver.ram('Desktop memory 16GB').memoryType, isNull);
      final both = resolver.ram('Memory DDR4 and DDR5 kit');
      expect(both.memoryType, isNull);
      expect(both.conflict, isTrue);
    });

    test('PSU wattage', () {
      expect(resolver.psu('Corsair RM850x 850W 80+ Gold').wattage, 850);
      expect(resolver.psu('EVGA 650 Watt Power Supply').wattage, 650);
      expect(resolver.psu('Seasonic Prime 1,000W').wattage, 1000);
      expect(resolver.psu('MSI MAG 1000 W ATX 3.0').wattage, 1000);
      expect(resolver.psu('Power Supply 80 Plus Gold').wattage, isNull);
      expect(resolver.psu('Available in 650W and 750W').wattage, isNull);
    });

    test('case size is the largest one named', () {
      expect(
        resolver.pcCase('Mid Tower ATX Case').maxFormFactor,
        FormFactor.atx,
      );
      expect(
        resolver.pcCase('Case for ATX, Micro-ATX, Mini-ITX').maxFormFactor,
        FormFactor.atx,
      );
      expect(
        resolver.pcCase('Compact Micro ATX Tower').maxFormFactor,
        FormFactor.microAtx,
      );
      expect(
        resolver.pcCase('Mini-ITX SFF Case').maxFormFactor,
        FormFactor.miniItx,
      );
      expect(resolver.pcCase('RGB Tempered Glass Tower').maxFormFactor, isNull);
    });

    test('cooler sockets', () {
      expect(resolver.cooler('Air Cooler for AM4/AM5/LGA1700').sockets, {
        CpuSocket.am4,
        CpuSocket.am5,
        CpuSocket.lga1700,
      });
      expect(resolver.cooler('Noctua CPU Cooler').sockets, isEmpty);
    });
  });
}
