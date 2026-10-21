import 'package:sqflite/sqflite.dart';

/// Version 46 upgrade only. Normal rendering and new writes use Phosphor IDs.
/// The application ID marks icon encoding independently of schema version,
/// so converted older backups still receive their remaining schema upgrades.
abstract final class PhosphorIconMigration {
  static const applicationId = 1263552561;

  static Future<void> upgrade(DatabaseExecutor db) async {
    final marker = (await db.rawQuery('PRAGMA application_id'))
        .first
        .values
        .single;
    if (marker == applicationId) return;
    // Icon-only edits must not invalidate categorization history. Restore the
    // exact trigger definitions within the enclosing database upgrade transaction.
    final triggers = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' "
      "AND tbl_name IN ('accounts', 'categories') AND sql IS NOT NULL",
    );
    for (final trigger in triggers) {
      final name = (trigger['name'] as String).replaceAll('"', '""');
      await db.execute('DROP TRIGGER "$name"');
    }
    for (final table in ['accounts', 'categories']) {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      if (!columns.any((column) => column['name'] == 'iconCodePoint')) continue;
      await db.execute('''
        UPDATE $table SET iconCodePoint = CASE iconCodePoint
        WHEN 57408 THEN 57524
        WHEN 57415 THEN 58324
        WHEN 57423 THEN 58326
        WHEN 57424 THEN 58326
        WHEN 57449 THEN 57524
        WHEN 57522 THEN 58704
        WHEN 57634 THEN 57610
        WHEN 57662 THEN 57974
        WHEN 57672 THEN 58468
        WHEN 57673 THEN 59418
        WHEN 57686 THEN 57730
        WHEN 57720 THEN 57794
        WHEN 57759 THEN 57810
        WHEN 57815 THEN 57618
        WHEN 57896 THEN 59718
        WHEN 57946 THEN 59280
        WHEN 57997 THEN 57526
        WHEN 58007 THEN 57346
        WHEN 58123 THEN 58344
        WHEN 58136 THEN 58050
        WHEN 58173 THEN 58062
        WHEN 58212 THEN 58488
        WHEN 58262 THEN 58734
        WHEN 58381 THEN 59586
        WHEN 58498 THEN 58760
        WHEN 58529 THEN 58952
        WHEN 58531 THEN 57824
        WHEN 58565 THEN 57688
        WHEN 58637 THEN 58348
        WHEN 58646 THEN 58154
        WHEN 58648 THEN 58156
        WHEN 58674 THEN 57954
        WHEN 58707 THEN 59908
        WHEN 58713 THEN 58924
        WHEN 58751 THEN 57970
        WHEN 58780 THEN 58398
        WHEN 59111 THEN 58602
        WHEN 59122 THEN 57582
        WHEN 60979 THEN 59018
        WHEN 61058 THEN 57356
        WHEN 61097 THEN 59042
        WHEN 61109 THEN 57518
        WHEN 61239 THEN 58468
        WHEN 61484 THEN 59154
        WHEN 61563 THEN 57924
        WHEN 61585 THEN 57930
        WHEN 61703 THEN 58050
        WHEN 62054 THEN 58760
        WHEN 62191 THEN 58348
        WHEN 62262 THEN 59908
        WHEN 62318 THEN 57970
        WHEN 62333 THEN 58390
        WHEN 62463 THEN 57914
        WHEN 62746 THEN 57754
        WHEN 62751 THEN 57524
        WHEN 62752 THEN 59018
        WHEN 62755 THEN 59004
        WHEN 62763 THEN 57680
        WHEN 62764 THEN 58326
        WHEN 62775 THEN 58324
        WHEN 62817 THEN 57680
        WHEN 62834 THEN 57432
        WHEN 62837 THEN 57406
        WHEN 62841 THEN 57658
        WHEN 62846 THEN 57486
        WHEN 62869 THEN 58470
        WHEN 62889 THEN 57680
        WHEN 62922 THEN 58078
        WHEN 62952 THEN 57740
        WHEN 62967 THEN 57582
        WHEN 62974 THEN 57610
        WHEN 63012 THEN 58468
        WHEN 63029 THEN 57732
        WHEN 63030 THEN 57730
        WHEN 63034 THEN 57656
        WHEN 63035 THEN 57658
        WHEN 63045 THEN 58614
        WHEN 63047 THEN 58614
        WHEN 63064 THEN 59080
        WHEN 63100 THEN 57810
        WHEN 63116 THEN 58160
        WHEN 63125 THEN 58534
        WHEN 63126 THEN 58534
        WHEN 63127 THEN 58534
        WHEN 63128 THEN 60500
        WHEN 63190 THEN 60070
        WHEN 63199 THEN 57868
        WHEN 63203 THEN 60130
        WHEN 63227 THEN 58292
        WHEN 63239 THEN 59006
        WHEN 63250 THEN 58594
        WHEN 63263 THEN 57660
        WHEN 63264 THEN 57654
        WHEN 63323 THEN 57960
        WHEN 63336 THEN 57924
        WHEN 63427 THEN 58006
        WHEN 63428 THEN 58468
        WHEN 63471 THEN 57760
        WHEN 63477 THEN 58050
        WHEN 63501 THEN 58058
        WHEN 63509 THEN 58062
        WHEN 63520 THEN 57686
        WHEN 63531 THEN 57654
        WHEN 63570 THEN 58482
        WHEN 63588 THEN 58760
        WHEN 63624 THEN 58120
        WHEN 63677 THEN 58150
        WHEN 63695 THEN 58700
        WHEN 63697 THEN 58334
        WHEN 63698 THEN 58760
        WHEN 983065 THEN 57490
        WHEN 983092 THEN 58846
        WHEN 983104 THEN 58700
        WHEN 983128 THEN 58760
        WHEN 983190 THEN 59138
        WHEN 983194 THEN 57688
        WHEN 983255 THEN 60168
        WHEN 983256 THEN 57738
        WHEN 983265 THEN 58348
        WHEN 983273 THEN 57398
        WHEN 983281 THEN 58154
        WHEN 983287 THEN 58358
        WHEN 983300 THEN 60994
        WHEN 983307 THEN 57760
        WHEN 983336 THEN 59908
        WHEN 983356 THEN 58126
        WHEN 983357 THEN 58124
        WHEN 983468 THEN 57408
        WHEN 983514 THEN 58184
        WHEN 983516 THEN 58476
        WHEN 983521 THEN 58480
        WHEN 983528 THEN 57592
        WHEN 983546 THEN 57504
        WHEN 983548 THEN 57496
        WHEN 983636 THEN 58542
        WHEN 983640 THEN 58420
        WHEN 983658 THEN 58560
        WHEN 983669 THEN 58584
        WHEN 983698 THEN 57892
        WHEN 983699 THEN 57888
        WHEN 983711 THEN 58060
        WHEN 983712 THEN 58592
        WHEN 983726 THEN 58482
        WHEN 983797 THEN 58700
        WHEN 983798 THEN 59278
        WHEN 983800 THEN 58710
        WHEN 983803 THEN 58714
        WHEN 983828 THEN 59316
        WHEN 983902 THEN 58294
        WHEN 984482 THEN 57872
        WHEN 984705 THEN 58076
        WHEN 984777 THEN 58904
        WHEN 984779 THEN 58754
        WHEN 985044 THEN 59018
        WHEN 985132 THEN 59018
        WHEN 985268 THEN 59018
        ELSE 58344 END
      ''');
    }
    for (final trigger in triggers) {
      await db.execute(trigger['sql'] as String);
    }
    await markCurrent(db);
  }

  static Future<void> markCurrent(DatabaseExecutor db) =>
      db.execute('PRAGMA application_id = $applicationId');
}
