package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

public record PurchaseLineResponse(

    Long id,
    String description,
    Integer quantity,
    BigDecimal unitPricePkr,
    BigDecimal extendedPricePkr,
    String vendor

) {

    public static PurchaseLineResponse from(PurchaseLine purchase) {

        return new PurchaseLineResponse(

            purchase.getId(),
            purchase.getDescription(),
            purchase.getQuantity(),
            purchase.getUnitPricePkr(),
            purchase.getExtendedPricePkr(),
            purchase.getVendor()

        );
    }
}