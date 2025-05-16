package com.finstop.auth.service;

import com.finstop.auth.grpc.*;
import com.finstop.auth.model.User;
import com.finstop.auth.repository.UserRepository;
import com.finstop.auth.security.JwtTokenProvider;
import io.grpc.stub.StreamObserver;
import lombok.RequiredArgsConstructor;
import net.devh.boot.grpc.server.service.GrpcService;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientService;

@GrpcService
@RequiredArgsConstructor
public class AuthGrpcService extends AuthServiceGrpc.AuthServiceImplBase {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtTokenProvider jwtTokenProvider;
    private final OAuth2AuthorizedClientService authorizedClientService;

    @Override
    public void register(RegisterRequest request, StreamObserver<AuthResponse> responseObserver) {
        // Validate if username already exists
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new RuntimeException("Username already exists");
        }

        // Create new user
        User user = new User();
        user.setUsername(request.getUsername());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setAge(request.getAge());
        user.setProfession(request.getProfession());
        user.setEducation(request.getEducation());
        user.setProvider(User.AuthProvider.CUSTOM);

        user = userRepository.save(user);

        // Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = jwtTokenProvider.generateRefreshToken(user);

        // Build response
        AuthResponse response = buildAuthResponse(user, accessToken, refreshToken);
        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }

    @Override
    public void login(LoginRequest request, StreamObserver<AuthResponse> responseObserver) {
        Authentication authentication = authenticationManager.authenticate(
            new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
        );

        User user = userRepository.findByUsername(request.getUsername())
            .orElseThrow(() -> new RuntimeException("User not found"));

        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = jwtTokenProvider.generateRefreshToken(user);

        AuthResponse response = buildAuthResponse(user, accessToken, refreshToken);
        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }

    @Override
    public void googleLogin(GoogleLoginRequest request, StreamObserver<AuthResponse> responseObserver) {
        // Implementation for Google OAuth login will go here
        // This will involve exchanging the auth code for tokens and user info
        throw new RuntimeException("Method not implemented");
    }

    @Override
    public void validateToken(ValidateTokenRequest request, StreamObserver<ValidateTokenResponse> responseObserver) {
        boolean isValid = jwtTokenProvider.validateToken(request.getToken());
        
        ValidateTokenResponse.Builder responseBuilder = ValidateTokenResponse.newBuilder()
            .setIsValid(isValid);

        if (isValid) {
            String username = jwtTokenProvider.getUsernameFromToken(request.getToken());
            User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
            
            responseBuilder.setUserInfo(buildUserInfo(user));
        }

        responseObserver.onNext(responseBuilder.build());
        responseObserver.onCompleted();
    }

    private AuthResponse buildAuthResponse(User user, String accessToken, String refreshToken) {
        return AuthResponse.newBuilder()
            .setAccessToken(accessToken)
            .setRefreshToken(refreshToken)
            .setTokenType("Bearer")
            .setExpiresIn(jwtTokenProvider.getAccessTokenValidityInSeconds())
            .setUserInfo(buildUserInfo(user))
            .build();
    }

    private UserInfo buildUserInfo(User user) {
        return UserInfo.newBuilder()
            .setUserId(user.getId())
            .setUsername(user.getUsername())
            .setAge(user.getAge())
            .setProfession(user.getProfession())
            .setEducation(user.getEducation())
            .setAuthProvider(AuthProvider.valueOf(user.getProvider().name()))
            .build();
    }
} 