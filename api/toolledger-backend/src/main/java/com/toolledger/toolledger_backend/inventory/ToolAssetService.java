package com.toolledger.toolledger_backend.inventory;

import java.util.List;
import java.util.Locale;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ToolAssetService {

    private final ToolAssetRepository repository;

    // Constructor
    public ToolAssetService(ToolAssetRepository repository) {
        this.repository = repository;
    }

    // Register a new tool
    @Transactional
    public ToolAssetResponse createTool(CreateToolRequest request) {

        String code = request.assetCode()
                .strip()
                .toUpperCase(Locale.ROOT);

        if (repository.existsByAssetCode(code)) {

            throw new ResponseStatusException(
                HttpStatus.CONFLICT,
                "Asset code already exists"
            );
        }

        ToolAsset tool = new ToolAsset(
            code,
            request.description().strip(),
            request.purchasePrice()
        );

        ToolAsset savedTool = repository.save(tool);

        return ToolAssetResponse.from(savedTool);
    }

    // Retrieve all tools
    @Transactional(readOnly = true)
    public List<ToolAssetResponse> getAllTools() {

        return repository.findAll()
                .stream()
                .map(ToolAssetResponse::from)
                .toList();
    }

    // Find a tool by database ID
    @Transactional(readOnly = true)
    public ToolAssetResponse getToolById(Long id) {

        ToolAsset tool = repository.findById(id)
                .orElseThrow(() -> new ResponseStatusException(
                    HttpStatus.NOT_FOUND,
                    "Tool not found"
                ));

        return ToolAssetResponse.from(tool);
    }

    // Find a tool by asset code / QR code
    @Transactional(readOnly = true)
    public ToolAssetResponse getToolByCode(String assetCode) {

        String code = assetCode.strip()
                .toUpperCase(Locale.ROOT);

        ToolAsset tool = repository.findByAssetCode(code)
                .orElseThrow(() -> new ResponseStatusException(
                    HttpStatus.NOT_FOUND,
                    "Tool not found"
                ));

        return ToolAssetResponse.from(tool);
    }
}