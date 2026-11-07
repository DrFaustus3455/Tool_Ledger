package com.toolledger.toolledger_backend.inventory;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ToolAssetRepository
        extends JpaRepository<ToolAsset, Long> {

    Optional<ToolAsset> findByAssetCode(String assetCode);

    boolean existsByAssetCode(String assetCode);
}