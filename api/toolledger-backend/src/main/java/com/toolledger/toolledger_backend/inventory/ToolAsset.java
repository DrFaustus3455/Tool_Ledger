package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "tool_assets")
public class ToolAsset {

    // =====================================
    // LESSON 2 - ORIGINAL FIELDS
    // =====================================

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


    // =====================================
    // LESSON 4 - NEW INVENTORY FIELDS
    // =====================================

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "purchase_line_id")
    private PurchaseLine purchaseLine;

    @Column(name = "serial_number")
    private String serialNumber;

    @Column(name = "part_number")
    private String partNumber;

    @Column(name = "series")
    private String series;

    @Column(name = "make")
    private String make;

    @Column(name = "storage_location")
    private String storageLocation;

    @Column(name = "department")
    private String department;

    @Column(name = "tool_condition")
    private String toolCondition = "UNASSESSED";

    @Column(name = "is_restricted")
    private boolean restricted = false;


    // =====================================
    // CONSTRUCTORS
    // =====================================

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


    // =====================================
    // LESSON 5B - LINK TO PURCHASE
    // =====================================

    public void linkToPurchaseLine(PurchaseLine purchaseLine) {
        this.purchaseLine = purchaseLine;
    }


    // =====================================
    // GETTERS
    // =====================================

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

    public PurchaseLine getPurchaseLine() {
        return purchaseLine;
    }

    public String getSerialNumber() {
        return serialNumber;
    }

    public String getPartNumber() {
        return partNumber;
    }

    public String getSeries() {
        return series;
    }

    public String getMake() {
        return make;
    }

    public String getStorageLocation() {
        return storageLocation;
    }

    public String getDepartment() {
        return department;
    }

    public String getToolCondition() {
        return toolCondition;
    }

    public boolean isRestricted() {
        return restricted;
    }
}