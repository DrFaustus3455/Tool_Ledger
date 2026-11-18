package com.toolledger.toolledger_backend.inventory;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PurchaseLineService {

    private final PurchaseLineRepository repository;


    // CONSTRUCTOR INJECTION
    public PurchaseLineService(PurchaseLineRepository repository) {
        this.repository = repository;
    }


    // CREATE A PURCHASE
    @Transactional
    public PurchaseLineResponse createPurchase(
            CreatePurchaseLineRequest request
    ) {

        PurchaseLine purchase = new PurchaseLine(

            request.description().strip(),
            request.quantity(),
            request.unitPricePkr(),
            request.vendor() == null
                    ? null
                    : request.vendor().strip()

        );

        PurchaseLine savedPurchase = repository.save(purchase);

        return PurchaseLineResponse.from(savedPurchase);
    }


    // GET ALL PURCHASES
    @Transactional(readOnly = true)
    public List<PurchaseLineResponse> getAllPurchases() {

        return repository.findAll()
                .stream()
                .map(PurchaseLineResponse::from)
                .toList();
    }


    // GET PURCHASE BY ID
    @Transactional(readOnly = true)
    public PurchaseLineResponse getPurchaseById(Long id) {

        PurchaseLine purchase = repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(
                    HttpStatus.NOT_FOUND,
                    "Purchase record not found"
                ));

        return PurchaseLineResponse.from(purchase);
    }
}