package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateToolRequest(

    @NotBlank(message = "Asset code is required")
    @Size(max = 40)
    String assetCode,

    @NotBlank(message = "Description is required")
    @Size(max = 200)
    String description,

    @NotNull(message = "Purchase price is required")
    @DecimalMin(value = "0.00")
    BigDecimal purchasePrice

) {}