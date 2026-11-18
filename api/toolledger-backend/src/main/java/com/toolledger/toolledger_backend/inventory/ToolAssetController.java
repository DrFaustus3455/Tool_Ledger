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
@RequestMapping("/api/v1/assets")
public class ToolAssetController {

    private final ToolAssetService service;

    public ToolAssetController(ToolAssetService service) {
        this.service = service;
    }

    // POST: Register a new tool
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ToolAssetResponse createTool(
            @Valid @RequestBody CreateToolRequest request) {

        return service.createTool(request);
    }

    // GET: Retrieve all inventory
    @GetMapping
    public List<ToolAssetResponse> getAllTools() {

        return service.getAllTools();
    }

    // GET: Find by database ID
    @GetMapping("/{id}")
    public ToolAssetResponse getToolById(
            @PathVariable Long id) {

        return service.getToolById(id);
    }

    // GET: Find by QR asset code
    @GetMapping("/code/{assetCode}")
    public ToolAssetResponse getToolByCode(
            @PathVariable String assetCode) {

        return service.getToolByCode(assetCode);
    }
}