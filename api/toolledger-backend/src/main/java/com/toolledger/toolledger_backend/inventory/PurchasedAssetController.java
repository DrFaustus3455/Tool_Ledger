package com.toolledger.toolledger_backend.inventory;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/purchases/{purchaseId}/assets")
public class PurchasedAssetController {

    private final PurchasedAssetService service;

    public PurchasedAssetController(PurchasedAssetService service) {
        this.service = service;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ToolAssetResponse registerTool(
            @PathVariable Long purchaseId,
            @Valid @RequestBody CreatePurchasedAssetRequest request
    ) {
        return service.registerTool(purchaseId, request);
    }
}