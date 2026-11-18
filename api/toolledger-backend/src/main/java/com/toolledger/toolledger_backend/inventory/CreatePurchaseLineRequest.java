package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreatePurchaseLineRequest(

    @NotBlank(message = "Description is required")
    @Size(max = 250)
    String description,

    @NotNull(message = "Quantity is required")
    @Min(value = 1, message = "Quantity must be at least 1")
    @Max(value = 10000)
    Integer quantity,

    @NotNull(message = "Unit price is required")
    @DecimalMin(value = "0.00")
    @Digits(integer = 9, fraction = 2)
    BigDecimal unitPricePkr,

    @Size(max = 255)
    String vendor

) {}