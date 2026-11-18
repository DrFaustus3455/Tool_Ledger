package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

public record ToolAssetResponse(

    Long id,
    String assetCode,
    String description,
    BigDecimal purchasePrice,
    String status

) {

    public static ToolAssetResponse from(ToolAsset tool) {

        return new ToolAssetResponse(
            tool.getId(),
            tool.getAssetCode(),
            tool.getDescription(),
            tool.getPurchasePrice(),
            tool.getStatus()
        );

    }
}