import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_app/core/theme/app_theme.dart';
import 'package:music_app/data/models.dart';
import 'package:music_app/state/library_controller.dart';
import 'package:music_app/ui/widgets/track_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Regression: disposing the TextEditingController as soon as showDialog
  // returned crashed while the dialog was still animating closed.
  testWidgets('create playlist dialog closes without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final library = await LibraryController.load();
    UserPlaylist? created;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: library,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  created = await showCreatePlaylistDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Road Trip');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(created?.name, 'Road Trip');
    expect(library.playlists.single.name, 'Road Trip');
  });
}
