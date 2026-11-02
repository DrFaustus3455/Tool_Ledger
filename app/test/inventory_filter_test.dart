import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolledger/features/inventory/data/models/tool_asset.dart';
import 'package:toolledger/features/inventory/presentation/inventory_controller.dart';
import 'package:toolledger/shared/data/mock_workspace_repository.dart';
import 'package:toolledger/shared/data/workspace_controller.dart';

void main() {
  test(
    'inventory filters combine query, status and department with sorting',
    () async {
      final container = ProviderContainer(
        overrides: [
          workspaceRepositoryProvider.overrideWithValue(
            MockWorkspaceRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(workspaceProvider.future);

      final filters = container.read(inventoryFilterProvider.notifier);
      filters.search('fluke');
      var assets = container.read(filteredAssetsProvider);
      expect(assets, hasLength(1));
      expect(assets.single.id, 'TL-MULT-003');

      filters.reset();
      filters.status(AssetStatus.available);
      filters.department('Mechanical Support');
      assets = container.read(filteredAssetsProvider);
      expect(assets, isNotEmpty);
      expect(
        assets.every(
          (asset) =>
              asset.status == AssetStatus.available &&
              asset.department == 'Mechanical Support',
        ),
        isTrue,
      );
      final sorted = assets.map((asset) => asset.id).toList();
      final expected = [...sorted]..sort();
      expect(sorted, expected);

      filters.search('serial-that-does-not-exist');
      expect(container.read(filteredAssetsProvider), isEmpty);
      filters.reset();
      expect(container.read(inventoryFilterProvider).query, isEmpty);
    },
  );
}
