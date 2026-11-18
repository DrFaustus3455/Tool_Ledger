package com.toolledger.toolledger_backend.security;

import java.util.Map;

import org.springframework.security.core.Authentication;
import org.springframework.security.web.csrf.CsrfToken;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    @GetMapping("/csrf")
    public CsrfToken csrf(CsrfToken token) {
        return token;
    }

    @GetMapping("/me")
    public Map<String, String> currentUser(
            Authentication authentication
    ) {

        String role = authentication
                .getAuthorities()
                .stream()
                .map(authority -> authority.getAuthority())
                .filter(authority -> authority.startsWith("ROLE_"))
                .findFirst()
                .orElse("ROLE_UNKNOWN")
                .substring(5);

        return Map.of(
                "username", authentication.getName(),
                "role", role
        );
    }
}