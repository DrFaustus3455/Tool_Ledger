package com.toolledger.toolledger_backend.inventory;

import java.math.BigDecimal;
import java.time.LocalDate;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "purchase_lines")
public class PurchaseLine {

    // PRIMARY KEY
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ORIGINAL REGISTER DETAILS
    @Column(name = "original_s_no")
    private Integer originalSerialNumber;

    @Column(nullable = false, length = 250)
    private String description;

    @Column(nullable = false)
    private Integer quantity;

    // FINANCIAL DETAILS
    @Column(name = "unit_price_pkr")
    private BigDecimal unitPricePkr;

    @Column(name = "extended_price_pkr")
    private BigDecimal extendedPricePkr;

    @Column(name = "total_pkr")
    private BigDecimal totalPkr;

    // PROCUREMENT DETAILS
    @Column(name = "purchase_date")
    private LocalDate purchaseDate;

    @Column(name = "vendor")
    private String vendor;


    // REQUIRED BY JPA
    protected PurchaseLine() {
    }


    // CONSTRUCTOR FOR NEW PURCHASES
    public PurchaseLine(
            String description,
            Integer quantity,
            BigDecimal unitPricePkr,
            String vendor
    ) {

        this.description = description;
        this.quantity = quantity;
        this.unitPricePkr = unitPricePkr;
        this.vendor = vendor;

        // Calculate subtotal before tax
        this.extendedPricePkr = unitPricePkr.multiply(
                BigDecimal.valueOf(quantity)
        );
    }


    // GETTERS

    public Long getId() {
        return id;
    }

    public String getDescription() {
        return description;
    }

    public Integer getQuantity() {
        return quantity;
    }

    public BigDecimal getUnitPricePkr() {
        return unitPricePkr;
    }

    public BigDecimal getExtendedPricePkr() {
        return extendedPricePkr;
    }

    public BigDecimal getTotalPkr() {
        return totalPkr;
    }

    public String getVendor() {
        return vendor;
    }
}