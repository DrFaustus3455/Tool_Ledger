package com.toolledger.toolledger_backend.inventory;

import java.util.Locale;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PurchasedAssetService {

    private final ToolAssetRepository toolRepository;
    private final PurchaseLineRepository purchaseRepository;

    public PurchasedAssetService(
            ToolAssetRepository toolRepository,
            PurchaseLineRepository purchaseRepository
    ) {
        this.toolRepository = toolRepository;
        this.purchaseRepository = purchaseRepository;
    }

    @Transactional
    public ToolAssetResponse registerTool(
            Long purchaseId,
            CreatePurchasedAssetRequest request
    ) {

        // 1. Find the purchase and lock its row
        PurchaseLine purchase = purchaseRepository
                .findByIdForUpdate(purchaseId)
                .orElseThrow(() -> new ResponseStatusException(
                        HttpStatus.NOT_FOUND,
                        "Purchase not found"
                ));

        // 2. Count existing physical tools
        long registered = toolRepository
                .countByPurchaseLine_Id(purchaseId);

        // 3. Enforce purchased quantity
        if (registered >= purchase.getQuantity()) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "All purchased tools are already registered"
            );
        }

        // 4. Normalize the asset code
        String code = request.assetCode()
                .strip()
                .toUpperCase(Locale.ROOT);

        // 5. Check for duplicate codes
        if (toolRepository.existsByAssetCode(code)) {
            throw new ResponseStatusException(
                    HttpStatus.CONFLICT,
                    "Asset code already exists"
            );
        }

        // 6. Validate the source purchase data
        if (purchase.getUnitPricePkr() == null) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Purchase has no unit price"
            );
        }

        String description = purchase.getDescription().strip();

        if (description.length() > 200) {
            throw new ResponseStatusException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "Purchase description exceeds tool description limit"
            );
        }

        // 7. Create the individual physical tool
        ToolAsset tool = new ToolAsset(
                code,
                description,
                purchase.getUnitPricePkr()
        );

        // 8. Connect the tool to the purchase
        tool.linkToPurchaseLine(purchase);

        // 9. Save in PostgreSQL
        ToolAsset saved = toolRepository.save(tool);

        // 10. Return JSON-ready data
        return ToolAssetResponse.from(saved);
    }
}