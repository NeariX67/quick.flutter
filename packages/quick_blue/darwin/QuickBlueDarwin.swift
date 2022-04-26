import CoreBluetooth

#if os(iOS)
import Flutter
import UIKit
#elseif os(OSX)
import Cocoa
import FlutterMacOS
#endif

extension CBUUID {
  public var uuidStr: String {
    get {
      uuidString.lowercased()
    }
  }
}

extension CBPeripheral {
  // FIXME https://forums.developer.apple.com/thread/84375
  public var uuid: UUID {
    get {
      value(forKey: "identifier") as! NSUUID as UUID
    }
  }
}

public class QuickBlueDarwin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #elseif os(OSX)
    let messenger = registrar.messenger
    #endif
    let method = FlutterMethodChannel(name: "quick_blue/method", binaryMessenger: messenger)
    let eventScanResult = FlutterEventChannel(name: "quick_blue/event.scanResult", binaryMessenger: messenger)
    let messageConnector = FlutterBasicMessageChannel(name: "quick_blue/message.connector", binaryMessenger: messenger)

    let instance = QuickBlueDarwin()
    registrar.addMethodCallDelegate(instance, channel: method)
    eventScanResult.setStreamHandler(instance)
    instance.messageConnector = messageConnector
  }

  private var manager: CBCentralManager!
  private var discoveredPeripherals: Dictionary<String, CBPeripheral>!

  private var scanResultSink: FlutterEventSink?
  private var messageConnector: FlutterBasicMessageChannel!

  override init() {
    super.init()
    manager = CBCentralManager(delegate: self, queue: nil)
    discoveredPeripherals = Dictionary()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isBluetoothAvailable":
      result(manager.state == .poweredOn)
    case "startScan":
      manager.scanForPeripherals(withServices: nil)
      result(nil)
    case "stopScan":
      manager.stopScan()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

extension QuickBlueDarwin: CBCentralManagerDelegate {
  public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    print("centralManagerDidUpdateState \(central.state.rawValue)")
  }

  public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    print("centralManager:didDiscoverPeripheral \(peripheral.name) \(peripheral.uuid.uuidString)")
    discoveredPeripherals[peripheral.uuid.uuidString] = peripheral

    let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
    scanResultSink?([
      "name": peripheral.name ?? "",
      "deviceId": peripheral.uuid.uuidString,
      "manufacturerData": FlutterStandardTypedData(bytes: manufacturerData ?? Data()),
      "rssi": RSSI,
    ])
  }
}

extension QuickBlueDarwin: FlutterStreamHandler {
  open func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard let args = arguments as? Dictionary<String, Any>, let name = args["name"] as? String else {
      return nil
    }
    print("QuickBlueDarwin onListenWithArguments: \(name)")
    if name == "scanResult" {
      scanResultSink = events
    }
    return nil
  }

  open func onCancel(withArguments arguments: Any?) -> FlutterError? {
    guard let args = arguments as? Dictionary<String, Any>, let name = args["name"] as? String else {
      return nil
    }
    print("QuickBlueDarwin onCancelWithArguments: \(name)")
    if name == "scanResult" {
      scanResultSink = nil
    }
    return nil
  }
}
