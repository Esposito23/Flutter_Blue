import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(FlutterBlueApp());

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.off) {
              return BluetoothOffScreen(state: state);
            } else {
              return (FindDevicesScreen());
            }
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key key, this.state}) : super(key: key);

  final BluetoothState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
                'Stato del Blue --> ${state != null ? state.toString().substring(15) : 'not available'}.',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatefulWidget {
  FindDevicesScreen({Key key}) : super(key: key);

  @override
  _FindDevicesScreenState createState() => _FindDevicesScreenState();
}

class _FindDevicesScreenState extends State<FindDevicesScreen> {
  final List<ScanResult> listaDispositivi = [];

  aggiungiDispositivo() {
    FlutterBlue.instance.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        if (!listaDispositivi.contains(result)) {
          setState(() {
            listaDispositivi.add(result);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        backgroundColor: Colors.grey[800],
        centerTitle: true,
        title: Text('AppBle'),
      ),
      body: StreamBuilder<List<ScanResult>>(
          stream: FlutterBlue.instance.scanResults,
          initialData: [],
          builder: (_, snapshot) {
            return ListView.builder(
              itemCount: listaDispositivi.length,
              itemBuilder: (_, index) {
                return (RaisedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => Dispositivo(),
                              settings: RouteSettings(
                                  arguments: listaDispositivi[index].device)));
                    },
                    child: Text(listaDispositivi[index].device.name == ''
                        ? '${listaDispositivi[index].device.id}'
                        : '${listaDispositivi[index].device.name}')));
              },
            );
          }),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (_, snapshot) {
          if (snapshot.data) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () {
                FlutterBlue.instance.stopScan();
              },
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () {
                  FlutterBlue.instance.startScan(timeout: Duration(seconds: 5));
                  aggiungiDispositivo();
                });
          }
        },
      ),
    );
  }
}

class Dispositivo extends StatefulWidget {
  @override
  _DispositivoState createState() => _DispositivoState();
}

class _DispositivoState extends State<Dispositivo> {
  @override
  Widget build(BuildContext context) {
    final BluetoothDevice deviceSelect =
        ModalRoute.of(context).settings.arguments;

    BluetoothCharacteristic targetCharacteristicWrite;
    BluetoothCharacteristic targetCharacteristicRead;
    List<String> chat = [];

    sendMessage(String message) async {
      List<int> bytes = utf8.encode(message);
      await targetCharacteristicWrite.write(bytes);
      print(message);
      chat.add(message);
    }

    leggi() {
      targetCharacteristicRead.value.listen((s) {
        chat.add(utf8.decode(s).toString());
        print(utf8.decode(s).toString());
      });
    }

    cercaServizi() async {
      List<BluetoothService> services = await deviceSelect.discoverServices();
      services.forEach((servizi) {
        List<BluetoothCharacteristic> blueChar = servizi.characteristics;
        blueChar.forEach((char) async {
          if (char.uuid.toString() == "6e400002-b5a3-f393-e0a9-e50e24dcca9e") {
            targetCharacteristicWrite = char;
            // print('servizio catturato scrittura');
          }
          if (char.uuid.toString() == "6e400003-b5a3-f393-e0a9-e50e24dcca9e") {
            targetCharacteristicRead = char;
            await targetCharacteristicRead.setNotifyValue(true);
            leggi();
            // print('servizio catturato lettura');
          }
        });
      });
    }

    iconState() {
      return (StreamBuilder<BluetoothDeviceState>(
          stream: deviceSelect.state,
          initialData: BluetoothDeviceState.disconnected,
          builder: (_, snap) {
            if (snap.data == BluetoothDeviceState.connected) {
              cercaServizi();
              return (Icon(
                Icons.bluetooth_connected_sharp,
                color: Colors.green,
                size: 40,
              ));
            } else {
              return (Icon(
                Icons.bluetooth_disabled_rounded,
                color: Colors.grey[850],
                size: 40,
              ));
            }
          }));
    }

    return Scaffold(
      appBar: AppBar(title: Text('${deviceSelect.name}')),
      body: Container(
        padding: EdgeInsets.all(20),
        child: Column(children: <Widget>[
          Column(
            children: <Widget>[
              Text('${deviceSelect.name}'),
              Text('${deviceSelect.id}'),
              Text('${deviceSelect.type}')
            ],
          ),
          SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            RaisedButton(
              onPressed: () async {
                deviceSelect.connect(autoConnect: false);
              },
              child: Text('Connetti'),
            ),
            SizedBox(
              width: 30,
            ),
            RaisedButton(
              child: Text('Disconnetti'),
              onPressed: () {
                deviceSelect.disconnect();
              },
            ),
            SizedBox(
              width: 30,
            ),
            Container(child: iconState()),
          ]),
          SizedBox(
            height: 30,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              RaisedButton(
                child: Text('Invia'),
                onPressed: () {
                  sendMessage('Ciao Fra\n');
                },
              ),
              SizedBox(
                width: 30,
              )
            ],
          ),
        ]),
      ),
    );
  }
}
