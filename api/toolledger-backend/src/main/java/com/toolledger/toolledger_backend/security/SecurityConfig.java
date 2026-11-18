package com.toolledger.toolledger_backend.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.security.web.SecurityFilterChain;

import org.springframework.http.HttpMethod;

@Configuration
public class SecurityConfig {

    // Password hashing
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    // API security rules
    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http
    ) throws Exception {

        http
            .authorizeHttpRequests(auth -> auth

                // Obtain CSRF token before login
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/v1/auth/csrf"
                ).permitAll()

                // Spring Security processes login
                .requestMatchers(
                    "/api/v1/auth/login",
                    "/error"
                ).permitAll()

                // Logged-in users can see their identity
                .requestMatchers(
                    HttpMethod.GET,
                    "/api/v1/auth/me"
                ).authenticated()

                // Existing inventory APIs expose prices.
                // Keep these Manager-only for now.
                .requestMatchers(
                    "/api/v1/assets",
                    "/api/v1/assets/**",
                    "/api/v1/purchases",
                    "/api/v1/purchases/**"
                ).hasRole("MANAGER")

                // Block everything not explicitly permitted
                .anyRequest().denyAll()
            )

            // Session-based login
            .formLogin(form -> form

                .loginProcessingUrl("/api/v1/auth/login")

                .successHandler((request, response, authentication) -> {
                    response.setStatus(200);
                    response.setContentType("application/json");
                    response.getWriter().write(
                        "{\"message\":\"Login successful\"}"
                    );
                })

                .failureHandler((request, response, exception) -> {
                    response.setStatus(401);
                    response.setContentType("application/json");
                    response.getWriter().write(
                        "{\"error\":\"Invalid username or password\"}"
                    );
                })
            )

            // Log out and invalidate the session
            .logout(logout -> logout

                .logoutUrl("/api/v1/auth/logout")

                .invalidateHttpSession(true)

                .deleteCookies("JSESSIONID")

                .logoutSuccessHandler(
                    (request, response, authentication) ->
                        response.setStatus(204)
                )
            )

            // Don't use HTTP Basic authentication
            .httpBasic(AbstractHttpConfigurer::disable)

            // Don't store requests for redirecting after login
            .requestCache(cache -> cache.disable())

            // Return HTTP errors rather than redirects
            .exceptionHandling(errors -> errors

                .authenticationEntryPoint(
                    (request, response, exception) ->
                        response.sendError(401)
                )

                .accessDeniedHandler(
                    (request, response, exception) ->
                        response.sendError(403)
                )
            );

        return http.build();
    }
}