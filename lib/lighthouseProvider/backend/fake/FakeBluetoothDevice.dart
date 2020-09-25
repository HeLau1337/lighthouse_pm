import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:lighthouse_pm/lighthouseProvider/ble/DefaultCharacteristics.dart';

import '../../ble/BluetoothCharacteristic.dart';
import '../../ble/BluetoothDevice.dart';
import '../../ble/BluetoothService.dart';
import '../../ble/DeviceIdentifier.dart';
import '../../ble/Guid.dart';

class FakeBluetoothDevice extends LHBluetoothDevice {
  final LHDeviceIdentifier deviceIdentifier;
  final _SimpleBluetoothService service;
  final String _name;

  FakeBluetoothDevice(
      List<LHBluetoothCharacteristic> characteristics, int id, String name)
      : service = _SimpleBluetoothService(characteristics),
        deviceIdentifier = LHDeviceIdentifier(
            '00:00:00:00:00:${id.toRadixString(16).padLeft(2, '0').toUpperCase()}'),
        _name = name;

  @override
  Future<void> connect({Duration timeout}) async {
    // do nothing
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<LHBluetoothService>> discoverServices() async {
    return [service];
  }

  @override
  LHDeviceIdentifier get id => deviceIdentifier;

  @override
  String get name => _name;

  @override
  Stream<LHBluetoothDeviceState> get state =>
      Stream.value(LHBluetoothDeviceState.connected);
}

class FakeLighthouseV2Device extends FakeBluetoothDevice {
  FakeLighthouseV2Device(int deviceName, int deviceId)
      : super([
          _FakeFirmwareCharacteristic(),
          _FakeModelNumberCharacteristic(),
          _FakeSerialNumberCharacteristic(),
          _FakeHardwareRevisionCharacteristic(),
          _FakeManufacturerNameCharacteristic(),
          _FakeChannelCharacteristic(),
          _FakeLighthouseV2PowerCharacteristic()
        ], deviceId, _getNameFromInt(deviceName));

  static String _getNameFromInt(int deviceName) {
    return 'LHB-000000${deviceName.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}

class FakeViveBaseStationDevice extends FakeBluetoothDevice {
  FakeViveBaseStationDevice(int deviceName, int deviceId)
      : super([
          _FakeFirmwareCharacteristic(),
          _FakeModelNumberCharacteristic(),
          _FakeSerialNumberCharacteristic(),
          _FakeHardwareRevisionCharacteristic(),
          _FakeManufacturerNameCharacteristic(),
          _FakeViveBaseStationCharacteristic()
        ], deviceId, _getNameFromInt(deviceName));

  static String _getNameFromInt(int deviceName) {
    return 'HTC BS 0000${deviceName.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }
}

class _SimpleBluetoothService extends LHBluetoothService {
  _SimpleBluetoothService(List<LHBluetoothCharacteristic> characteristics)
      : _characteristics = characteristics;

  List<LHBluetoothCharacteristic> _characteristics;

  LighthouseGuid _uuid =
      LighthouseGuid.fromString('00000000-0000-0000-0000-000000000001');

  @override
  List<LHBluetoothCharacteristic> get characteristics => _characteristics;

  @override
  LighthouseGuid get uuid => _uuid;
}

abstract class FakeReadWriteCharacteristic extends LHBluetoothCharacteristic {
  final LighthouseGuid _uuid;

  List<int> data = [];

  FakeReadWriteCharacteristic(LighthouseGuid uuid) : _uuid = uuid;

  @override
  LighthouseGuid get uuid => _uuid;

  @override
  Future<List<int>> read() async {
    return data;
  }
}

abstract class FakeReadOnlyCharacteristic extends LHBluetoothCharacteristic {
  final List<int> data;
  final LighthouseGuid _uuid;

  FakeReadOnlyCharacteristic(this.data, LighthouseGuid uuid) : _uuid = uuid;

  @override
  LighthouseGuid get uuid => _uuid;

  @override
  Future<List<int>> read() async => data;

  @override
  Future<Function> write(List<int> data, {bool withoutResponse = false}) {
    throw UnimplementedError(
        'Write is not supported by FakeReadOnlyCharacteristic');
  }
}

//region Fake default
class _FakeFirmwareCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeFirmwareCharacteristic()
      : super(
            _intListFromString('FAKE_DEVICE'),
            _fromDefaultCharacteristic(
                DefaultCharacteristics.FIRMWARE_REVISION_CHARACTERISTIC));
}

class _FakeModelNumberCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeModelNumberCharacteristic()
      : super(
            _intListFromNumber(0xFF),
            _fromDefaultCharacteristic(
                DefaultCharacteristics.MODEL_NUMBER_STRING_CHARACTERISTIC));
}

class _FakeSerialNumberCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeSerialNumberCharacteristic()
      : super(
            _intListFromNumber(0xFF),
            _fromDefaultCharacteristic(
                DefaultCharacteristics.SERIAL_NUMBER_STRING_CHARACTERISTIC));
}

class _FakeHardwareRevisionCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeHardwareRevisionCharacteristic()
      : super(
            _intListFromString('FAKE_REVISION'),
            _fromDefaultCharacteristic(
                DefaultCharacteristics.HARDWARE_REVISION_CHARACTERISTIC));
}

class _FakeManufacturerNameCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeManufacturerNameCharacteristic()
      : super(
            _intListFromString('LIGHTHOUSE PM By Jeroen1602'),
            _fromDefaultCharacteristic(
                DefaultCharacteristics.HARDWARE_REVISION_CHARACTERISTIC));
}
//endregion

class _FakeChannelCharacteristic extends FakeReadOnlyCharacteristic {
  _FakeChannelCharacteristic()
      : super(_intListFromNumber(0xFF),
            LighthouseGuid.fromString('00001524-1212-EFDE-1523-785FEABCD124'));
}

class _FakeLighthouseV2PowerCharacteristic extends FakeReadWriteCharacteristic {
  _FakeLighthouseV2PowerCharacteristic()
      : super(
            LighthouseGuid.fromString('00001525-1212-efde-1523-785feabcd124')) {
    if (random.nextBool()) {
      this.data.add(0x00); // sleep
    } else {
      this.data.add(0x0b); // on
    }
  }

  final random = new Random();

  @override
  Future<void> write(List<int> data, {bool withoutResponse = false}) async {
    if (data.length != 1) {
      debugPrint(
          'Send incorrect amount of bytes to fake lighthouse v2 power characteristic');
      return;
    }
    final byte = data[0];
    switch (byte) {
      case 0x00:
        this.data[0] = byte;
        break;
      case 0x01:
      case 0x02:
        if (this.data[0] == 0x0b && byte == 0x02) {
          this.data[0] = byte;
          break;
        }
        if (this.data[0] == 0x02 && byte == 0x01) {
          this.data[0] = 0x0b;
          break;
        }
        this.data[0] = byte;
        Future.delayed(new Duration(milliseconds: 10)).then((value) async {
          // booting
          this.data[0] = 0x09;
          await Future.delayed(new Duration(milliseconds: 1200));
        }).then((value) {
          if (byte == 0x01) {
            this.data[0] = 0x0b; // on
          } else {
            this.data[0] = byte; // other
          }
        });

        break;
      default:
        debugPrint(
            'Unknown state 0x${byte.toRadixString(16).padLeft(2, '0').toUpperCase()}');
    }
  }
}

class _FakeViveBaseStationCharacteristic extends FakeReadWriteCharacteristic {
  _FakeViveBaseStationCharacteristic()
      : super(
            LighthouseGuid.fromString('0000cb01-0000-1000-8000-00805f9b34fb')) {
    data.addAll([0x01, 0x02]);
  }

  @override
  Future<void> write(List<int> data, {bool withoutResponse = false}) async {
    debugPrint('Written some data to vive base station!');
  }
}

LighthouseGuid _fromDefaultCharacteristic(
    DefaultCharacteristics defaultCharacteristics) {
  final data = ByteData(16);
  data.setUint32(0, defaultCharacteristics.uuid, Endian.big);
  return LighthouseGuid.fromBytes(data);
}

List<int> _intListFromString(String data) {
  return Utf8Encoder().convert(data).toList();
}

List<int> _intListFromNumber(int number) {
  final data = ByteData(8);
  data.setUint64(0, number, Endian.big);
  final List<int> list = List<int>();
  var nonZero = false;
  for (int i = 0; i < 8; i++) {
    final byte = data.getUint8(i);
    if (byte > 0) {
      nonZero = true;
    }
    list.add(byte);
  }
  if (nonZero) {
    // Trim the list at the end.
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i] == 0) {
        list.removeLast();
      } else {
        break;
      }
    }
    return list;
  } else {
    return <int>[];
  }
}
