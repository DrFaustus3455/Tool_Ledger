package com.toolledger.toolledger_backend.security;

import java.util.Locale;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;

import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Component;

@Component
public class InitialManagerBootstrap implements ApplicationRunner {

    private final AppUserRepository repository;
    private final PasswordEncoder passwordEncoder;

    private final String managerUsername;
    private final String managerPassword;

    public InitialManagerBootstrap(
            AppUserRepository repository,
            PasswordEncoder passwordEncoder,

            @Value("${TOOLLEDGER_BOOTSTRAP_MANAGER_USERNAME:}")
            String managerUsername,

            @Value("${TOOLLEDGER_BOOTSTRAP_MANAGER_PASSWORD:}")
            String managerPassword
    ) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.managerUsername = managerUsername;
        this.managerPassword = managerPassword;
    }

    @Override
    public void run(ApplicationArguments args) {

        // Don't create another Manager after initialization
        if (repository.existsByRole(AppRole.MANAGER)) {
            return;
        }

        // Require initialization credentials
        if (managerUsername.isBlank()
                || managerPassword.length() < 16) {

            throw new IllegalStateException(
                "Initial Manager credentials are missing or too short"
            );
        }

        String username = managerUsername.strip()
                .toLowerCase(Locale.ROOT);

        if (username.length() > 80) {
            throw new IllegalStateException(
                "Manager username exceeds 80 characters"
            );
        }

        if (repository.findByUsername(username).isPresent()) {
            throw new IllegalStateException(
                "Bootstrap username is already registered"
            );
        }

        // Hash the password
        String hashedPassword =
                passwordEncoder.encode(managerPassword);

        // Create the Manager account
        AppUser manager = new AppUser(
                username,
                hashedPassword,
                AppRole.MANAGER
        );

        repository.save(manager);

        System.out.println(
                "Initial Manager account created successfully."
        );
    }
}