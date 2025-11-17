import 'package:flutter/material.dart';
import 'package:watchtower_sdk/watchtower_sdk.dart';

class UriEventWidget extends StatelessWidget {
  UriEventWidget({super.key});

  final _uriController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Text(
                      "Open link event",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _uriController,
                  decoration: const InputDecoration(labelText: "URI"),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return "Fill this field";
                    }
                    return null;
                  },
                ),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      Watchtower.sendOpenLinkEvent(
                        uri: _uriController.text,
                        responseText: "Success",
                      );
                    },
                    child: const Text("Open"),
                  ),
                  // sendOpenLinkEvent({required String uri, int? responseCode, String? responseText}) async {
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
