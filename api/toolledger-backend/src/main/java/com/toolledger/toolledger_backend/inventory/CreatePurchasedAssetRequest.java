package com.toolledger.toolledger_backend.inventory;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreatePurchasedAssetRequest(

    @NotBlank(message = "Asset code is required")
    @Size(max = 40)
    String assetCode

) {}