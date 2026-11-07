package com.toolledger.toolledger_backend.health;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HealthController {

    @GetMapping("/api/v1/hello")
    public Map<String, String> hello() {

        return Map.of(
            "message",
            "ToolLedger Backend is running successfully!"
        );
    }
}