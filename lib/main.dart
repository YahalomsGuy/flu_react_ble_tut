import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location_permissions/location_permissions.dart';
import 'dart:io' show Platform;


// Uuid _UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
// Uuid _UART_RX   = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
// Uuid _UART_TX   = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_UUID = Uuid.parse("254E3845-4A95-4978-9772-7FEE40F8E23C");
Uuid _CHANNELS_TX   = Uuid.parse("2AABE551-C76B-42F4-AAC3-769fA23987AC");
Uuid _STATS_TX   = Uuid.parse("DBDC4211-20AB-4382-B086-815f05130ED8");
Uuid _UART_RX   = Uuid.parse("788DCFD2-DC8D-40C4-A35F-1040A89EE22F");
//6C5B157C-FC19-FAE6-92DD-9917EB7981F4
// const String channelsChar =
//     '2aabe551-c76b-42f4-aac3-769fa23987ac'; //Charectiristics
// const String voltTempChar =
//     'dbdc4211-20ab-4382-b086-815f05130ed8'; //idBattTemp....
// const String calibrateChar = '788dcfd2-dc8d-40c4-a35f-1040a89ee22f';





void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:  MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {


  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  List<DiscoveredDevice> _foundBleUARTDevices = [];
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late Stream<ConnectionStateUpdate> _currentConnectionStream;
  late StreamSubscription<ConnectionStateUpdate> _connection;
  late QualifiedCharacteristic _txChannelsCharacteristic;
  late QualifiedCharacteristic _txStatCharacteristic;
  late QualifiedCharacteristic _rxCharacteristic;
  late Stream<List<int>> _receivedChannelsDataStream;
  late Stream<List<int>> _receivedStatDataStream;
  TextEditingController _dataToSendText = TextEditingController();
  bool _scanning = false;
  bool connected = false;
  String _logTexts = "";
  List<String> _receivedChannelData = [];
  List<String> _receivedStatData = [];
  int _numberOfMessagesReceived = 0;

  @override
  void initState() {
    super.initState();
    _dataToSendText = TextEditingController();
    _startScan();
    print("Found It!");

  }

  void refreshScreen() {
    setState(() {});
  }
  void _sendData() async {
    await flutterReactiveBle.writeCharacteristicWithResponse(_rxCharacteristic, value: _dataToSendText.text.codeUnits);
  }
  void onNewReceivedChannelData(List<int> data) {

    _receivedChannelData.add(data.toString()); //String.fromCharCodes(data));
    if (_receivedChannelData.length > 1) {
      _receivedChannelData.removeAt(0);
    }
    refreshScreen();
  }
  void onNewReceivedStatData(List<int> data) {

    _receivedStatData.add(data.toString()); // String.fromCharCodes(data));
    if (_receivedStatData.length > 1) {
      _receivedStatData.removeAt(0);
    }

    refreshScreen();
  }
  void _disconnect() async {
    await _connection.cancel();
    connected = false;
    refreshScreen();
  }
  void _stopScan() async {
    await _scanStream.cancel();
    _scanning = false;
    refreshScreen();
  }
  Future<void> showNoPermissionDialog() async => showDialog<void>(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: const Text('No location permission '),
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('No location permission granted.'),
            Text('Location permission is required for BLE to function.'),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Acknowledge'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    ),
  );
  void _startScan() async {
    bool goForIt=false;
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await LocationPermissions().requestPermissions();
      if (permission == PermissionStatus.granted) {
        goForIt=true;
      }
    } else if (Platform.isIOS) {
      goForIt=true;
    }
    if (goForIt) { //TODO replace True with permission == PermissionStatus.granted is for IOS test
      _foundBleUARTDevices = [];
      _scanning = true;
      refreshScreen();
      _scanStream =
          flutterReactiveBle.scanForDevices(withServices: [_UART_UUID]).listen((
              device) {
            if (_foundBleUARTDevices.every((element) =>
            element.id != device.id)) {
              _foundBleUARTDevices.add(device);
              refreshScreen();
              _stopScan();
              onConnectDevice(0);
            }
          }, onError: (Object error) {
            _logTexts =
            "${_logTexts}ERROR while scanning:$error \n";
            print("ERROR while scanning:$error");
            refreshScreen();
          }
          );
    }
    else {
      await showNoPermissionDialog();
    }
  }
  void onConnectDevice(index) {
    _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
      id:_foundBleUARTDevices[index].id,
      prescanDuration: const Duration(seconds: 1),
      withServices: [_UART_UUID, _UART_RX, _CHANNELS_TX, _STATS_TX],
    );
    _logTexts = "";
    refreshScreen();
    _connection = _currentConnectionStream.listen((event) {
      var id = event.deviceId.toString();
      switch(event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            _logTexts = "${_logTexts}Connecting to $id\n";
            print("Connecting to $id");

            break;
          }
        case DeviceConnectionState.connected:
          {
            connected = true;
            _logTexts = "${_logTexts}Connected to $id\n";
            print("Connected to $id");
            _numberOfMessagesReceived = 0;
            _receivedChannelData = [];
            _receivedStatData = [];
            _txChannelsCharacteristic = QualifiedCharacteristic(serviceId: _UART_UUID, characteristicId: _CHANNELS_TX, deviceId: event.deviceId);
            _txStatCharacteristic = QualifiedCharacteristic(serviceId: _UART_UUID, characteristicId: _STATS_TX, deviceId: event.deviceId);
            _receivedChannelsDataStream = flutterReactiveBle.subscribeToCharacteristic(_txChannelsCharacteristic);
            _receivedStatDataStream = flutterReactiveBle.subscribeToCharacteristic(_txStatCharacteristic);
            _receivedChannelsDataStream.listen((channelsData) {
              onNewReceivedChannelData(channelsData);
            }, onError: (dynamic error) {
              _logTexts = "${_logTexts}Error:$error$id\n";
            });
            _receivedStatDataStream.listen((statData) {
              onNewReceivedStatData(statData);
            }, onError: (dynamic error) {
              _logTexts = "${_logTexts}Error:$error$id\n";
            });
            _rxCharacteristic = QualifiedCharacteristic(serviceId: _UART_UUID, characteristicId: _UART_RX, deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            connected = false;
            _logTexts = "${_logTexts}Disconnecting from $id\n";
            print("Disconnecting from $id");
            refreshScreen();
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            _logTexts = "${_logTexts}Disconnected from $id\n";
            print("Disconnected from $id");
            _numberOfMessagesReceived = 0;
            _receivedChannelData = [];
            _receivedStatData = [];
            connected = false;

            _startScan();
            refreshScreen();
            break;
          }
      }
      refreshScreen();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Reactive BT Test"),
    ),
    body: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const Text("BLE UART Devices found:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 100,
              child: ListView.builder(
                  itemCount: _foundBleUARTDevices.length,
                  itemBuilder: (context, index) => Card(
                      child: ListTile(
                        dense: true,
                        enabled: !((!connected && _scanning) || (!_scanning && connected)),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            (!connected && _scanning) || (!_scanning && connected)? (){}: onConnectDevice(index);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_link),
                          ),
                        ),
                        subtitle: Text(_foundBleUARTDevices[index].id),
                        title: Text("$index: ${_foundBleUARTDevices[index].name}"),
                      ))
              )
          ),
          const Text("Status messages:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width:1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 90,
              child: Scrollbar(

                  child: SingleChildScrollView(
                      child: Text(_logTexts)
                  )
              )
          ),
          const Text("Received Channels data:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width:1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 90,
              child: Text(_receivedChannelData.join("\n"))
          ),
          const Text("Received Stat data:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              width:1400,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              height: 90,
              child: Text(_receivedStatData.join("\n"))
          ),
          const Text("Send message:"),
          Container(
              margin: const EdgeInsets.all(3.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.blue,
                      width:2
                  )
              ),
              child: Row(
                  children: <Widget> [
                    Expanded(
                        child: TextField(
                          enabled: connected,
                          controller: _dataToSendText,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter a string'
                          ),
                        )
                    ),
                    IconButton(
                        icon: Icon(
                          Icons.send,
                          color:connected ? Colors.blue : Colors.grey,
                        ),
                        onPressed: connected ? _sendData: (){}
                    ),
                  ]
              ))
        ],
      ),
    ),
    persistentFooterButtons: [
      Container(
        height: 50,
        child: Column(
          children: [
            if (_scanning) const Text("Scanning: Scanning") else const Text("Scanning: Idle"),
            if (connected || !_scanning) const Text("Connected") else const Text("disconnected."),
          ],
        ) ,
      ),
      IconButton(
        onPressed: !_scanning && !connected ? _startScan : (){},
        icon: Icon(
          Icons.play_arrow,
          color: !_scanning && !connected ? Colors.blue: Colors.grey,
        ),
      ),
      IconButton(
          onPressed: _scanning ? _stopScan: (){},
          icon: Icon(
            Icons.stop,
            color:_scanning ? Colors.blue: Colors.grey,
          )
      ),
      IconButton(
          onPressed: connected ? _disconnect: (){},
          icon: Icon(
            Icons.cancel,
            color:connected ? Colors.blue:Colors.grey,
          )
      )
    ],
  );
}