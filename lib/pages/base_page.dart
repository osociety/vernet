import 'package:flutter/material.dart';
import 'package:vernet/ui/adaptive/adaptive_list.dart';
import 'package:vernet/ui/adaptive/shell_chrome.dart';
import 'package:vernet/ui/popular_chip.dart';
import 'package:vernet/utils/localization.dart';
import 'package:vernet/values/keys.dart';

abstract class BasePage<T extends StatefulWidget> extends State<T> {
  TextEditingController textEditingController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // These three take the context because the copy behind them lives in the ARB
  // files, and reading them needs the locale the app is currently rendering.
  String title(BuildContext context);
  String fieldLabel(BuildContext context);
  String buttonLabel(BuildContext context);

  Widget _getDomainChip(String label) {
    return PopularChip(
      label: label,
      onPressed: () {
        textEditingController.text = label;
      },
    );
  }

  String? validateIP(BuildContext context, String? value) {
    if (value != null && value.isEmpty) {
      return context.l10n.baseAddressRequired;
    }
    return null;
  }

  Widget buildPopularChips(BuildContext context) {
    return Card(
      child: AdaptiveListTile(
        title: Text(context.l10n.tryAWebsite),
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

  Future<void> onPressed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShellChrome.providesAppBar(context)
          ? null
          : AppBar(
              title: Text(title(context)),
            ),
      body: SafeArea(
        child: Container(
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
                          validator: (value) => validateIP(context, value),
                          controller: textEditingController,
                          decoration: InputDecoration(
                            filled: true,
                            hintText: fieldLabel(context),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: ElevatedButton(
                          key: WidgetKey.basePageSubmitButton.key,
                          onPressed: () {
                            if (_formKey.currentState!.validate()) onPressed();
                          },
                          child: Text(buttonLabel(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              buildPopularChips(context),
              Expanded(
                child: buildResults(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
