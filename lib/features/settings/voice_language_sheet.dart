import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceLanguageSheet extends ConsumerStatefulWidget {
  const VoiceLanguageSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const VoiceLanguageSheet(),
  );

  @override
  ConsumerState<VoiceLanguageSheet> createState() => _VoiceLanguageSheetState();
}

class _VoiceLanguageSheetState extends ConsumerState<VoiceLanguageSheet> {
  late Future<List<LocaleName>> _locales;
  bool _saving = false;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _locales = ref.read(voiceInputProvider.notifier).availableLocales();
  }

  Future<void> _choose(String? id, String name) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).setVoiceLocale(id, name: name);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        KoinSnackBar.error(
          context,
          'Could not save speech language. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(settingsProvider).voiceLocale;
    Widget option(String name, String? id) => Semantics(
      selected: selected == id,
      child: ListTile(
        title: Text(name),
        enabled: !_saving,
        selected: selected == id,
        leading: Icon(
          selected == id ? KoinIcons.radioButton : KoinIcons.circle,
        ),
        onTap: () => _choose(id, name),
      ),
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: KoinSheetSurface(
          scrollable: true,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const KoinBottomSheetHandle(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Speech language',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  option('Follow system language', null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search languages',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  FutureBuilder<List<LocaleName>>(
                    future: _locales,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return KoinErrorState(
                          message: 'Could not load speech languages. Check microphone permission.',
                          onRetry: () => setState(
                            () => _locales = ref
                                .read(voiceInputProvider.notifier)
                                .availableLocales(),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final locales = snapshot.data!
                          .where(
                            (locale) => locale.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                          )
                          .toList();
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: locales.length,
                        itemBuilder: (_, i) =>
                            option(locales[i].name, locales[i].localeId),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
