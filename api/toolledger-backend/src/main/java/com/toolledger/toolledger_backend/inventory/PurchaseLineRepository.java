package com.toolledger.toolledger_backend.inventory;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

public interface PurchaseLineRepository
        extends JpaRepository<PurchaseLine, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM PurchaseLine p WHERE p.id = :id")
    Optional<PurchaseLine> findByIdForUpdate(
            @Param("id") Long id
    );
}