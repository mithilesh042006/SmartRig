import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pc_buildere/data/performance_data.dart';
import 'package:pc_buildere/services/model_resolver.dart';

// Real titles returned by the Amazon proxy on 1 November 2026.
void main() {
  const resolver = ModelResolver();
  final fixture =
      jsonDecode(File('test/fixtures/amazon_titles.json').readAsStringSync())
          as Map<String, dynamic>;
  List<String> titles(String key) => (fixture[key] as List).cast<String>();

  test('every CPU resolves to a socket, power and score', () {
    for (final title in titles('cpu')) {
      final cpu = resolver.cpu(title);
      expect(cpu.socket, isNotNull, reason: title);
      expect(cpu.maxPowerW, isNotNull, reason: title);
      expect(cpuGamingIndex[cpu.baseModel], isNotNull, reason: title);
    }
  });

  test('every GPU resolves to power and a score', () {
    for (final title in titles('gpu')) {
      final gpu = resolver.gpu(title);
      expect(gpu.boardPowerW, isNotNull, reason: title);
      expect(gpuGamingIndex[gpu.model], isNotNull, reason: title);
    }
  });

  test('every RAM kit resolves to a generation; kits to a stick count', () {
    for (final title in [...titles('ram'), ...titles('ram2')]) {
      expect(resolver.ram(title).memoryType, isNotNull, reason: title);
    }
    expect(resolver.ram(titles('ram')[0]).stickCount, 2);
    expect(resolver.ram(titles('ram')[1]).stickCount, 1);
    expect(resolver.ram(titles('ram')[2]).stickCount, 2);
  });

  test('every motherboard resolves to socket, memory and size', () {
    for (final title in titles('motherboard')) {
      final board = resolver.motherboard(title);
      expect(board.socket, isNotNull, reason: title);
      expect(board.socketConflict, isFalse, reason: title);
      expect(board.memoryType, isNotNull, reason: title);
      expect(board.formFactor, isNotNull, reason: title);
    }
  });

  test('every power supply resolves to a wattage', () {
    for (final title in titles('psu')) {
      expect(resolver.psu(title).wattage, isNotNull, reason: title);
    }
  });

  test('every case resolves to a size', () {
    for (final title in titles('pcCase')) {
      expect(resolver.pcCase(title).maxFormFactor, isNotNull, reason: title);
    }
  });

  test('coolers yield socket or thermal data when the title has it', () {
    final coolers = titles('cooling').map(resolver.cooler).toList();
    expect(coolers.where((c) => c.sockets.isNotEmpty), isNotEmpty);
    expect(coolers.map((c) => c.ratedTdpW), contains(250));
  });
}
