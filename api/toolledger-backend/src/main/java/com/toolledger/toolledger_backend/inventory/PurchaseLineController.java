package com.toolledger.toolledger_backend.inventory;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/purchases")
public class PurchaseLineController {

    private final PurchaseLineService service;


    public PurchaseLineController(PurchaseLineService service) {
        this.service = service;
    }


    // POST: REGISTER PURCHASE
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PurchaseLineResponse createPurchase(
            @Valid @RequestBody CreatePurchaseLineRequest request
    ) {

        return service.createPurchase(request);
    }


    // GET: ALL PURCHASES
    @GetMapping
    public List<PurchaseLineResponse> getAllPurchases() {

        return service.getAllPurchases();
    }


    // GET: PURCHASE BY ID
    @GetMapping("/{id}")
    public PurchaseLineResponse getPurchaseById(
            @PathVariable Long id
    ) {

        return service.getPurchaseById(id);
    }
}