import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolledger/features/reports/data/excel_export_service.dart';
import 'package:toolledger/shared/data/mock_workspace_repository.dart';
import 'package:toolledger/shared/models/app_user.dart';

const manager = AppUser(
  id: 'U-M',
  employeeId: 'OES-MGR-TEST',
  username: 'manager@test.local',
  displayName: 'Test Manager',
  role: UserRole.manager,
  department: 'Product Support',
);
const lender = AppUser(
  id: 'U-L',
  employeeId: 'OES-LND-TEST',
  username: 'lender@test.local',
  displayName: 'Test Lender',
  role: UserRole.lender,
  department: 'Product Support',
);

void main() {
  const service = ExcelExportService();

  test('complete export is a genuine typed XLSX workbook with frozen filtered sheets', () async {
    final data = await MockWorkspaceRepository().load();
    final result = service.build(
      data,
      const ExportOptions(),
      manager,
      generatedAt: DateTime.utc(2026, 10, 30, 12),
    );
    expect(result.bytes.sublist(0, 2), [0x50, 0x4b]);
    expect(result.fileName, endsWith('.xlsx'));
    final workbook = Excel.decodeBytes(result.bytes);
    expect(
      workbook.tables.keys,
      containsAll([
        'Summary',
        'Inventory Master',
        'Active Loans',
        'Lending History',
        'Damaged Assets',
        'Disposed Assets',
        'Depreciation Report',
        'Authorized Audit History',
      ]),
    );
    final inventory = workbook.tables['Inventory Master']!;
    expect(inventory.maxRows, data.assets.length + 1);
    expect(inventory.rows[1][3]!.value, isA<IntCellValue>());
    expect(
      inventory.rows[1][14]!.value,
      anyOf(isA<DoubleCellValue>(), isA<IntCellValue>()),
    );
    expect(
      inventory.rows[1][17]!.value,
      anyOf(isA<DateTimeCellValue>(), isA<DateCellValue>()),
    );
    expect(
      (inventory.rows[1][0]!.value as TextCellValue).value.toString(),
      data.assets.first.id,
    );

    final archive = ZipDecoder().decodeBytes(result.bytes);
    final sheet = archive.files.firstWhere(
      (file) => file.name == 'xl/worksheets/sheet2.xml',
    );
    final xml = utf8.decode(sheet.content as List<int>);
    expect(xml, contains('<pane'));
    expect(xml, contains('<autoFilter'));
  });

  test(
    'lender can export lending data but not financial inventory or audit',
    () async {
      final data = await MockWorkspaceRepository().load();
      final result = service.build(
        data,
        const ExportOptions(dataset: ExportDataset.activeLoans),
        lender,
      );
      final workbook = Excel.decodeBytes(result.bytes);
      expect(workbook.tables.keys, contains('Active Loans'));
      expect(workbook.tables.keys, isNot(contains('Depreciation Report')));
      expect(
        () => service.build(
          data,
          const ExportOptions(dataset: ExportDataset.entireInventory),
          lender,
        ),
        throwsA(isA<UnauthorizedExportException>()),
      );
      expect(
        () => service.build(
          data,
          const ExportOptions(dataset: ExportDataset.audit),
          lender,
        ),
        throwsA(isA<UnauthorizedExportException>()),
      );
    },
  );

  test(
    'export department and purchase filters limit actual worksheet records',
    () async {
      final data = await MockWorkspaceRepository().load();
      final result = service.build(
        data,
        ExportOptions(
          dataset: ExportDataset.filteredResults,
          department: 'Mechanical Support',
          purchaseStart: DateTime(2020),
          purchaseEnd: DateTime(2024, 12, 31, 23, 59, 59),
        ),
        manager,
      );
      final expected = data.assets
          .where(
            (asset) =>
                asset.department == 'Mechanical Support' &&
                !asset.purchaseDate.isBefore(DateTime(2020)) &&
                !asset.purchaseDate.isAfter(DateTime(2024, 12, 31, 23, 59, 59)),
          )
          .length;
      expect(result.recordCount, expected);
      final workbook = Excel.decodeBytes(result.bytes);
      expect(workbook.tables['Inventory Master']!.maxRows, expected + 1);
    },
  );

  test('spreadsheet formula injection is preserved as literal text', () async {
    final data = await MockWorkspaceRepository().load();
    final result = service.build(
      data,
      const ExportOptions(
        dataset: ExportDataset.entireInventory,
        department: '=HYPERLINK("https://invalid")',
      ),
      manager,
    );
    final workbook = Excel.decodeBytes(result.bytes);
    final summary = workbook.tables['Summary']!;
    final departmentCell = summary.rows[5][1]!.value as TextCellValue;
    expect(departmentCell.value.toString(), startsWith("'="));
  });
}
