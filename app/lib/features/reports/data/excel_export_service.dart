import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';

import '../../../shared/models/app_user.dart';
import '../../../shared/models/workspace_data.dart';
import '../../inventory/data/models/tool_asset.dart';
import '../../loans/data/models/loan_record.dart';

enum ExportDataset {
  completeWorkbook,
  entireInventory,
  filteredResults,
  selectedEquipment,
  activeLoans,
  lendingHistory,
  overdueEquipment,
  damagedEquipment,
  disposedEquipment,
  valuation,
  audit,
}

extension ExportDatasetLabel on ExportDataset {
  String get label => switch (this) {
    ExportDataset.completeWorkbook => 'Complete authorized workbook',
    ExportDataset.entireInventory => 'Entire inventory',
    ExportDataset.filteredResults => 'Currently filtered results',
    ExportDataset.selectedEquipment => 'Selected equipment',
    ExportDataset.activeLoans => 'Active loans',
    ExportDataset.lendingHistory => 'Complete lending history',
    ExportDataset.overdueEquipment => 'Overdue equipment',
    ExportDataset.damagedEquipment => 'Damaged equipment',
    ExportDataset.disposedEquipment => 'Disposed equipment',
    ExportDataset.valuation => 'Asset valuation & depreciation',
    ExportDataset.audit => 'Authorized audit history',
  };
}

class ExportOptions {
  const ExportOptions({
    this.dataset = ExportDataset.completeWorkbook,
    this.department,
    this.category,
    this.status,
    this.startDate,
    this.endDate,
    this.purchaseStart,
    this.purchaseEnd,
    this.borrower = '',
    this.selectedIds = const {},
    this.filteredIds,
  });
  final ExportDataset dataset;
  final String? department;
  final String? category;
  final AssetStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? purchaseStart;
  final DateTime? purchaseEnd;
  final String borrower;
  final Set<String> selectedIds;
  final Set<String>? filteredIds;
}

class UnauthorizedExportException implements Exception {
  const UnauthorizedExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExportResult {
  const ExportResult({
    required this.bytes,
    required this.fileName,
    required this.recordCount,
  });
  final Uint8List bytes;
  final String fileName;
  final int recordCount;
}

class ExcelExportService {
  const ExcelExportService();

  ExportResult build(
    WorkspaceData data,
    ExportOptions options,
    AppUser requester, {
    DateTime? generatedAt,
  }) {
    _authorize(options.dataset, requester.role);
    final now = generatedAt ?? DateTime.now();
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');
    var records = 0;
    _summary(excel['Summary'], data, options, requester, now);

    final assets = _filterAssets(data.assets, options);
    final loans = _filterLoans(data.loans, options);
    switch (options.dataset) {
      case ExportDataset.completeWorkbook:
        records += _inventorySheet(excel, data.assets, requester.role);
        records += _loanSheet(
          excel,
          'Active Loans',
          data.activeLoans,
          requester.role,
        );
        records += _loanSheet(
          excel,
          'Lending History',
          data.loans,
          requester.role,
        );
        records += _damageSheet(excel, data);
        records += _disposalSheet(excel, data);
        records += _valuationSheet(excel, data.assets, requester.role);
        records += _auditSheet(excel, data);
      case ExportDataset.entireInventory:
        records += _inventorySheet(excel, data.assets, requester.role);
      case ExportDataset.filteredResults:
        records += _inventorySheet(excel, assets, requester.role);
      case ExportDataset.selectedEquipment:
        records += _inventorySheet(
          excel,
          assets.where((a) => options.selectedIds.contains(a.id)).toList(),
          requester.role,
        );
      case ExportDataset.activeLoans:
        records += _loanSheet(
          excel,
          'Active Loans',
          loans
              .where(
                (l) =>
                    l.status == LoanStatus.active ||
                    l.status == LoanStatus.overdue,
              )
              .toList(),
          requester.role,
        );
      case ExportDataset.lendingHistory:
        records += _loanSheet(excel, 'Lending History', loans, requester.role);
      case ExportDataset.overdueEquipment:
        records += _writeInventorySheet(
          excel,
          'Overdue Equipment',
          data.assets.where((a) => a.status == AssetStatus.overdue).toList(),
          requester.role,
        );
      case ExportDataset.damagedEquipment:
        records += _damageSheet(excel, data);
      case ExportDataset.disposedEquipment:
        records += _disposalSheet(excel, data);
      case ExportDataset.valuation:
        records += _valuationSheet(excel, assets, requester.role);
      case ExportDataset.audit:
        records += _auditSheet(excel, data);
    }
    final raw = excel.encode();
    if (raw == null) throw StateError('Workbook encoding failed.');
    final bytes = _addFrozenHeadersAndFilters(Uint8List.fromList(raw));
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    return ExportResult(
      bytes: bytes,
      fileName: 'ToolLedger_${options.dataset.name}_$stamp.xlsx',
      recordCount: records,
    );
  }

  Future<void> download(ExportResult result) => FileSaver.instance.saveFile(
    name: result.fileName,
    bytes: result.bytes,
    fileExtension: 'xlsx',
    mimeType: MimeType.custom,
    customMimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  void _authorize(ExportDataset dataset, UserRole role) {
    if (role == UserRole.manager) return;
    if (dataset == ExportDataset.activeLoans ||
        dataset == ExportDataset.lendingHistory) {
      return;
    }
    throw const UnauthorizedExportException(
      'Access denied: this export contains financial, personal or audit data that is not authorized for lender accounts.',
    );
  }

  List<ToolAsset> _filterAssets(List<ToolAsset> source, ExportOptions o) =>
      source.where((a) {
        final ids = o.filteredIds;
        return (o.department == null || a.department == o.department) &&
            (o.category == null || a.equipmentType == o.category) &&
            (o.status == null || a.status == o.status) &&
            (o.purchaseStart == null ||
                !a.purchaseDate.isBefore(o.purchaseStart!)) &&
            (o.purchaseEnd == null ||
                !a.purchaseDate.isAfter(o.purchaseEnd!)) &&
            (ids == null || ids.contains(a.id));
      }).toList();

  List<LoanRecord> _filterLoans(List<LoanRecord> source, ExportOptions o) =>
      source.where((l) {
        return (o.department == null || l.department == o.department) &&
            (o.startDate == null || !l.issueDate.isBefore(o.startDate!)) &&
            (o.endDate == null || !l.issueDate.isAfter(o.endDate!)) &&
            (o.borrower.trim().isEmpty ||
                '${l.borrowerName} ${l.borrowerEmployeeId}'
                    .toLowerCase()
                    .contains(o.borrower.trim().toLowerCase()));
      }).toList();

  void _summary(
    Sheet sheet,
    WorkspaceData data,
    ExportOptions options,
    AppUser user,
    DateTime now,
  ) {
    _write(
      sheet,
      ['TOOLLEDGER EXPORT SUMMARY', 'VALUE'],
      [
        ['Dataset', options.dataset.label],
        ['Generated timestamp', now],
        ['Requested by', '${user.displayName} (${user.employeeId})'],
        ['Role', user.role.name.toUpperCase()],
        ['Department filter', options.department ?? 'All'],
        ['Category filter', options.category ?? 'All'],
        ['Status filter', options.status?.label ?? 'All'],
        [
          'Borrower filter',
          options.borrower.isEmpty ? 'All' : options.borrower,
        ],
        ['Registered assets', data.assets.length],
        ['Total purchase value PKR', data.totalPurchaseValue],
        ['Net book value PKR', data.netBookValue],
        [
          'Security',
          'Demonstration export. Production must use authorized backend download endpoints and server audit logs.',
        ],
      ],
    );
  }

  int _inventorySheet(
    Excel excel,
    List<ToolAsset> assets,
    UserRole role, [
    String? title,
  ]) => _writeInventorySheet(excel, title ?? 'Inventory Master', assets, role);
  int _writeInventorySheet(
    Excel excel,
    String name,
    List<ToolAsset> assets,
    UserRole role,
  ) {
    final manager = role == UserRole.manager;
    final headers = [
      'Asset ID',
      'Serial Number',
      'Description',
      'Quantity',
      'Part Number',
      'Series',
      'Manufacturer',
      'Equipment Type',
      'Legacy Type 1',
      'Legacy Type 2',
      if (manager) ...[
        'Unit Price PKR',
        'Extended Price PKR',
        'Historical GST PKR',
        'GST Rate',
        'Total Purchase PKR',
        'Foreign Currency',
        'Foreign Value',
        'Purchase Date',
        'Valuation Date',
        'Days Since Purchase',
        'Useful Life Years',
        'Daily Depreciation PKR',
        'Accumulated Depreciation PKR',
        'Net Book Value PKR',
        'Historical Accumulated Depreciation PKR',
        'Legacy Depreciation A',
        'Legacy Depreciation B',
        'Vendor',
        'Local / Imported',
        'OES Purchase Order',
        'Bill Number',
        'Bill Date',
      ],
      'Department',
      'Lying At',
      'Department Code',
      'Condition',
      'Status',
      'Issued To',
      'Transferred To',
      'Purpose',
      'Remarks',
      'Last Updated',
      'Current Borrower',
      'Expected Return Date',
      'Restricted',
    ];
    final rows = assets
        .map(
          (a) => <Object?>[
            a.id,
            a.serialNumber,
            a.description,
            a.quantity,
            a.partNumber,
            a.series,
            a.manufacturer,
            a.equipmentType,
            a.legacyTypePrimary,
            a.legacyTypeSecondary,
            if (manager) ...[
              a.unitPricePkr,
              a.extendedPricePkr,
              a.historicalGstAmountPkr,
              a.historicalGstRate,
              a.totalPurchaseValuePkr,
              a.foreignCurrencyCode,
              a.foreignCurrencyValue,
              a.purchaseDate,
              a.valuationDate,
              a.daysSincePurchase,
              a.usefulLifeYears,
              a.dailyDepreciation,
              a.accumulatedDepreciation,
              a.netBookValue,
              a.historicalAccumulatedDepreciationPkr,
              a.legacyDepreciationPrimary,
              a.legacyDepreciationSecondary,
              a.vendor,
              a.isImported ? 'Imported' : 'Local',
              a.oesPurchaseOrder,
              a.billNumber,
              a.billDate,
            ],
            a.department,
            a.lyingAt,
            a.departmentCode,
            a.condition,
            a.status.label,
            a.issuedTo,
            a.transferredTo,
            a.purpose,
            a.remarks,
            a.lastUpdated,
            a.currentBorrower,
            a.expectedReturnDate,
            a.isRestricted ? 'YES' : 'NO',
          ],
        )
        .toList();
    _write(excel[name], headers, rows);
    return assets.length;
  }

  int _loanSheet(
    Excel excel,
    String name,
    List<LoanRecord> loans,
    UserRole role,
  ) {
    _write(
      excel[name],
      [
        'Loan ID',
        'Asset ID',
        'Equipment Name',
        'Borrower Name',
        'Borrower Employee ID',
        'Department',
        'Work Order',
        'Purpose',
        'Issued By',
        'Issue Date',
        'Due Date',
        'Return Date',
        'Status',
        'Return Condition',
        'Approval ID',
      ],
      loans
          .map(
            (l) => [
              l.id,
              l.assetId,
              l.assetName,
              l.borrowerName,
              l.borrowerEmployeeId,
              l.department,
              l.workOrder,
              l.purpose,
              l.issuedBy,
              l.issueDate,
              l.dueDate,
              l.returnDate,
              l.status.name.toUpperCase(),
              l.returnCondition,
              l.approvalId,
            ],
          )
          .toList(),
    );
    return loans.length;
  }

  int _damageSheet(Excel excel, WorkspaceData data) {
    _write(
      excel['Damaged Assets'],
      [
        'Damage ID',
        'Asset ID',
        'Damage Description',
        'Reported By',
        'Damage Date',
        'Original Cost PKR',
        'Accumulated Depreciation PKR',
        'Net Book Value PKR',
        'Repair Status',
        'Evidence Photos',
      ],
      data.damages
          .map(
            (d) => [
              d.id,
              d.assetId,
              d.description,
              d.reportedBy,
              d.damageDate,
              d.originalCostPkr,
              d.accumulatedDepreciationPkr,
              d.netBookValuePkr,
              d.repairStatus,
              d.evidenceCount,
            ],
          )
          .toList(),
    );
    return data.damages.length;
  }

  int _disposalSheet(Excel excel, WorkspaceData data) {
    _write(
      excel['Disposed Assets'],
      [
        'Original Asset ID',
        'Purchase Information',
        'Disposal Date',
        'Reason',
        'Original Cost PKR',
        'Accumulated Depreciation PKR',
        'NBV at Disposal PKR',
        'Proceeds PKR',
        'Manager Authorization',
        'Historical Transactions',
      ],
      data.disposals
          .map(
            (d) => [
              d.assetId,
              d.purchaseSummary,
              d.disposalDate,
              d.reason,
              d.originalCostPkr,
              d.accumulatedDepreciationPkr,
              d.netBookValueAtDisposalPkr,
              d.proceedsPkr,
              d.authorizedBy,
              d.transactionCount,
            ],
          )
          .toList(),
    );
    return data.disposals.length;
  }

  int _valuationSheet(Excel excel, List<ToolAsset> assets, UserRole role) {
    if (role != UserRole.manager) {
      throw const UnauthorizedExportException(
        'Financial valuation export requires manager authorization.',
      );
    }
    _write(
      excel['Depreciation Report'],
      [
        'Asset ID',
        'Description',
        'Department',
        'Purchase Cost PKR',
        'Residual Value PKR',
        'Depreciable Cost PKR',
        'Purchase Date',
        'Valuation Date',
        'Age Days',
        'Useful Life Years',
        'Daily Depreciation PKR',
        'Accumulated Depreciation PKR',
        'Net Book Value PKR',
        'Historical Depreciation PKR',
        'Review Required',
      ],
      assets
          .map(
            (a) => [
              a.id,
              a.description,
              a.department,
              a.totalPurchaseValuePkr,
              a.residualValuePkr,
              a.depreciableCost,
              a.purchaseDate,
              a.valuationDate,
              a.daysSincePurchase,
              a.usefulLifeYears,
              a.dailyDepreciation,
              a.accumulatedDepreciation,
              a.netBookValue,
              a.historicalAccumulatedDepreciationPkr,
              a.financialReviewRequired ? 'REVIEW' : 'OK',
            ],
          )
          .toList(),
    );
    return assets.length;
  }

  int _auditSheet(Excel excel, WorkspaceData data) {
    _write(
      excel['Authorized Audit History'],
      [
        'Event ID',
        'Actor',
        'Action',
        'Affected Record',
        'Timestamp',
        'Category',
        'Relevant Changes / Details',
      ],
      data.audit
          .map(
            (a) => [
              a.id,
              a.actor,
              a.action,
              a.recordId,
              a.timestamp,
              a.category,
              a.details,
            ],
          )
          .toList(),
    );
    return data.audit.length;
  }

  void _write(Sheet sheet, List<String> headers, List<List<Object?>> rows) {
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#E9E8E0'),
      backgroundColorHex: ExcelColor.fromHexString('#182831'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    for (var col = 0; col < headers.length; col++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
              .cellStyle =
          headerStyle;
      sheet.setColumnWidth(
        col,
        headers[col].length > 24
            ? 26
            : headers[col].length < 12
            ? 16
            : 20,
      );
    }
    sheet.setRowHeight(0, 28);
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      sheet.appendRow(row.map(_cell).toList());
      for (var c = 0; c < row.length; c++) {
        final value = row[c];
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        );
        if (value is double || value is int) {
          final currency = headers[c].contains('PKR');
          cell.cellStyle = CellStyle(
            numberFormat: currency
                ? NumFormat.custom(formatCode: '"PKR" #,##0.00')
                : NumFormat.standard_4,
          );
        } else if (value is DateTime) {
          cell.cellStyle = CellStyle(
            numberFormat: NumFormat.custom(formatCode: 'dd-mmm-yyyy hh:mm'),
          );
        }
        if (headers[c] == 'Status' || headers[c] == 'Review Required') {
          final text = value?.toString() ?? '';
          final danger =
              text.contains('OVERDUE') ||
              text.contains('MISSING') ||
              text.contains('DAMAGED') ||
              text == 'REVIEW';
          final good =
              text.contains('AVAILABLE') ||
              text.contains('RETURNED') ||
              text == 'OK';
          cell.cellStyle = CellStyle(
            bold: true,
            fontColorHex: ExcelColor.fromHexString(
              danger
                  ? '#BD3545'
                  : good
                  ? '#087F70'
                  : '#A7650B',
            ),
            backgroundColorHex: ExcelColor.fromHexString(
              danger
                  ? '#FCECEF'
                  : good
                  ? '#E6F5F1'
                  : '#FFF4DF',
            ),
          );
        }
      }
    }
  }

  CellValue _cell(Object? value) => switch (value) {
    null => TextCellValue(''),
    DateTime() => DateTimeCellValue.fromDateTime(value),
    int() => IntCellValue(value),
    double() => DoubleCellValue(value),
    _ => TextCellValue(_literal(value.toString())),
  };

  String _literal(String value) =>
      RegExp(r'^[=+\-@]').hasMatch(value) ? "'$value" : value;

  Uint8List _addFrozenHeadersAndFilters(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final output = Archive();
    for (final file in archive.files) {
      if (!file.isFile ||
          !RegExp(r'xl/worksheets/sheet\d+\.xml$').hasMatch(file.name)) {
        output.addFile(file);
        continue;
      }
      var xml = utf8.decode(file.content as List<int>);
      final sheetView = RegExp(r'<sheetView\b[^>]*/>').firstMatch(xml);
      if (sheetView != null) {
        final replacement =
            '${sheetView.group(0)!.substring(0, sheetView.group(0)!.length - 2)}><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView>';
        xml = xml.replaceFirst(sheetView.group(0)!, replacement);
      }
      final isSummary = file.name.endsWith('sheet1.xml');
      if (!isSummary && !xml.contains('<autoFilter')) {
        final dimension =
            RegExp(r'<dimension ref="([^"]+)"').firstMatch(xml)?.group(1) ??
            'A1:Z10000';
        xml = xml.replaceFirst(
          '</worksheet>',
          '<autoFilter ref="$dimension"/></worksheet>',
        );
      }
      final encoded = utf8.encode(xml);
      output.addFile(ArchiveFile(file.name, encoded.length, encoded));
    }
    return Uint8List.fromList(ZipEncoder().encode(output)!);
  }
}
