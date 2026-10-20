import 'package:flutter/material.dart';

import '../models/campus_radio.dart';
import 'radio_details_page.dart';

class RadioListPage extends StatefulWidget {
  const RadioListPage({super.key});

  @override
  State<RadioListPage> createState() => _RadioListPageState();
}

class _RadioListPageState extends State<RadioListPage> {
  late Future<List<CampusRadio>> _radiosFuture;

  @override
  void initState() {
    super.initState();
    _radiosFuture = RadioRepository.getRadios();
  }

  void _openRadio(CampusRadio radio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => RadioDetailsPage(radio: radio)),
    );
  }

  Widget _logo(CampusRadio radio) {
    final logoUrl = radio.logoUrl;
    if (logoUrl == null) {
      return const Icon(Icons.radio);
    }
    return Image.network(logoUrl, width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radios Campus')),
      body: FutureBuilder<List<CampusRadio>>(
        future: _radiosFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final radios = snapshot.data!;
          return ListView.builder(
            itemCount: radios.length,
            itemBuilder: (context, index) {
              final radio = radios[index];
              return ListTile(
                leading: _logo(radio),
                title: Text(radio.name),
                onTap: () => _openRadio(radio),
              );
            },
          );
        },
      ),
    );
  }
}
