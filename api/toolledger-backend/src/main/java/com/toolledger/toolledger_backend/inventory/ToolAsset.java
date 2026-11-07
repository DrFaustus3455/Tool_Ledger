package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

import jakarta.persistence.*;

@Entity
@Table(name = "tool_assets")
public class ToolAsset {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(
        name = "asset_code",
        nullable = false,
        unique = true,
        length = 40
    )
    private String assetCode;

    @Column(nullable = false, length = 200)
    private String description;

    @Column(
        name = "purchase_price",
        nullable = false,
        precision = 14,
        scale = 2
    )
    private BigDecimal purchasePrice;

    @Column(nullable = false, length = 32)
    private String status = "AVAILABLE";

    protected ToolAsset() {
    }

    public ToolAsset(
            String assetCode,
            String description,
            BigDecimal purchasePrice
    ) {
        this.assetCode = assetCode;
        this.description = description;
        this.purchasePrice = purchasePrice;
        this.status = "AVAILABLE";
    }

    public Long getId() {
        return id;
    }

    public String getAssetCode() {
        return assetCode;
    }

    public String getDescription() {
        return description;
    }

    public BigDecimal getPurchasePrice() {
        return purchasePrice;
    }

    public String getStatus() {
        return status;
    }
}