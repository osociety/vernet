import 'package:flutter/material.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/popular_chip.dart';

abstract class BasePage<T extends StatefulWidget> extends State<T> {
  TextEditingController textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String title();
  String fieldLabel();

  Widget _getDomainChip(String label) {
    return PopularChip(
      label: label,
      onPressed: () {
        textEditingController.text = label;
      },
    );
  }

  String? validateIP(String? value) {
    if (value != null) {
      if (value.isEmpty) return 'Required';
    }
    return null;
  }

  Widget buildPopularChips() {
    return Card(
      child: AdaptiveListTile(
        title: const Text('Popular targets'),
        subtitle: Wrap(
          children: [
            _getDomainChip('google.com'),
            _getDomainChip('youtube.com'),
            _getDomainChip('apple.com'),
            _getDomainChip('amazon.com'),
            _getDomainChip('cloudflare.com'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    textEditingController.dispose();
  }

  Widget buildResults(BuildContext context);

  String buttonLabel();
  Future<void> onPressed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title()),
      ),
      body: Container(
        margin: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(5.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        validator: validateIP,
                        controller: textEditingController,
                        decoration: InputDecoration(
                          filled: true,
                          hintText: fieldLabel(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) onPressed();
                        },
                        child: Text(buttonLabel()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            buildPopularChips(),
            Expanded(
              child: buildResults(context),
            ),
          ],
        ),
      ),
    );
  }
}
