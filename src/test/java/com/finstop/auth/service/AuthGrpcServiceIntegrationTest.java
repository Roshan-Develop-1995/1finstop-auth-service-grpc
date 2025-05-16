package com.finstop.auth.service;

import com.finstop.auth.grpc.*;
import com.finstop.auth.model.User;
import com.finstop.auth.repository.UserRepository;
import com.finstop.auth.security.JwtTokenProvider;
import io.grpc.internal.testing.StreamRecorder;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
public class AuthGrpcServiceIntegrationTest {

    @Autowired
    private AuthGrpcService authGrpcService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    @Autowired
    private AuthenticationManager authenticationManager;

    private static final String TEST_USERNAME = "testuser";
    private static final String TEST_PASSWORD = "Test@123";

    @BeforeEach
    void setUp() {
        // Clean up the test user if exists
        userRepository.deleteAll();
    }

    @Test
    void testSuccessfulRegistration() throws Exception {
        // Arrange
        RegisterRequest request = RegisterRequest.newBuilder()
                .setUsername("testuser")
                .setPassword("password123")
                .setAge(25)
                .setProfession("Software Engineer")
                .setEducation("Bachelor's")
                .build();

        StreamRecorder<AuthResponse> responseObserver = StreamRecorder.create();

        // Act
        authGrpcService.register(request, responseObserver);

        // Assert
        if (!responseObserver.awaitCompletion(5, TimeUnit.SECONDS)) {
            fail("The call did not terminate in time");
        }

        assertNull(responseObserver.getError());
        List<AuthResponse> results = responseObserver.getValues();
        assertEquals(1, results.size());
        
        AuthResponse response = results.get(0);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals("Bearer", response.getTokenType());
        assertTrue(response.getExpiresIn() > 0);
        
        UserInfo userInfo = response.getUserInfo();
        assertEquals("testuser", userInfo.getUsername());
        assertEquals(25, userInfo.getAge());
        assertEquals("Software Engineer", userInfo.getProfession());
        assertEquals("Bachelor's", userInfo.getEducation());
        assertEquals(AuthProvider.CUSTOM, userInfo.getAuthProvider());
    }

    @Test
    void testRegistrationWithExistingUsername() throws Exception {
        // Arrange - Create a user first
        User existingUser = new User();
        existingUser.setUsername("existinguser");
        existingUser.setPassword(passwordEncoder.encode("password123"));
        existingUser.setAge(30);
        existingUser.setProfession("Teacher");
        existingUser.setEducation("Master's");
        existingUser.setProvider(User.AuthProvider.CUSTOM);
        userRepository.save(existingUser);

        RegisterRequest request = RegisterRequest.newBuilder()
                .setUsername("existinguser")
                .setPassword("newpassword")
                .setAge(25)
                .setProfession("Developer")
                .setEducation("Bachelor's")
                .build();

        StreamRecorder<AuthResponse> responseObserver = StreamRecorder.create();

        // Act & Assert
        assertThrows(RuntimeException.class, () -> {
            authGrpcService.register(request, responseObserver);
        }, "Username already exists");
    }

    @Test
    void testSuccessfulLogin() throws Exception {
        // Arrange - Create a user first
        User user = new User();
        user.setUsername("loginuser");
        user.setPassword(passwordEncoder.encode("password123"));
        user.setAge(30);
        user.setProfession("Teacher");
        user.setEducation("Master's");
        user.setProvider(User.AuthProvider.CUSTOM);
        userRepository.save(user);

        LoginRequest request = LoginRequest.newBuilder()
                .setUsername("loginuser")
                .setPassword("password123")
                .build();

        StreamRecorder<AuthResponse> responseObserver = StreamRecorder.create();

        // Act
        authGrpcService.login(request, responseObserver);

        // Assert
        if (!responseObserver.awaitCompletion(5, TimeUnit.SECONDS)) {
            fail("The call did not terminate in time");
        }

        assertNull(responseObserver.getError());
        List<AuthResponse> results = responseObserver.getValues();
        assertEquals(1, results.size());
        
        AuthResponse response = results.get(0);
        assertNotNull(response.getAccessToken());
        assertNotNull(response.getRefreshToken());
        assertEquals("Bearer", response.getTokenType());
        assertTrue(response.getExpiresIn() > 0);

        UserInfo userInfo = response.getUserInfo();
        assertEquals("loginuser", userInfo.getUsername());
        assertEquals(30, userInfo.getAge());
        assertEquals("Teacher", userInfo.getProfession());
        assertEquals("Master's", userInfo.getEducation());
    }

    @Test
    void testLoginWithInvalidCredentials() throws Exception {
        // Arrange - Create a user first
        User user = new User();
        user.setUsername("invalidloginuser");
        user.setPassword(passwordEncoder.encode("password123"));
        user.setAge(30);
        user.setProfession("Teacher");
        user.setEducation("Master's");
        user.setProvider(User.AuthProvider.CUSTOM);
        userRepository.save(user);

        LoginRequest request = LoginRequest.newBuilder()
                .setUsername("invalidloginuser")
                .setPassword("wrongpassword")
                .build();

        StreamRecorder<AuthResponse> responseObserver = StreamRecorder.create();

        // Act & Assert
        assertThrows(BadCredentialsException.class, () -> {
            authGrpcService.login(request, responseObserver);
        });
    }

    @Test
    void testValidateValidToken() throws Exception {
        // Arrange - Create a user and generate a token
        User user = new User();
        user.setUsername("tokenuser");
        user.setPassword(passwordEncoder.encode("password123"));
        user.setAge(30);
        user.setProfession("Teacher");
        user.setEducation("Master's");
        user.setProvider(User.AuthProvider.CUSTOM);
        user = userRepository.save(user);

        String token = jwtTokenProvider.generateAccessToken(user);
        ValidateTokenRequest request = ValidateTokenRequest.newBuilder()
                .setToken(token)
                .build();

        StreamRecorder<ValidateTokenResponse> responseObserver = StreamRecorder.create();

        // Act
        authGrpcService.validateToken(request, responseObserver);

        // Assert
        if (!responseObserver.awaitCompletion(5, TimeUnit.SECONDS)) {
            fail("The call did not terminate in time");
        }

        assertNull(responseObserver.getError());
        List<ValidateTokenResponse> results = responseObserver.getValues();
        assertEquals(1, results.size());
        
        ValidateTokenResponse response = results.get(0);
        assertTrue(response.getIsValid());
        assertEquals("tokenuser", response.getUserInfo().getUsername());
    }

    @Test
    void testValidateInvalidToken() throws Exception {
        // Arrange
        ValidateTokenRequest request = ValidateTokenRequest.newBuilder()
                .setToken("invalid.token.here")
                .build();

        StreamRecorder<ValidateTokenResponse> responseObserver = StreamRecorder.create();

        // Act
        authGrpcService.validateToken(request, responseObserver);

        // Assert
        if (!responseObserver.awaitCompletion(5, TimeUnit.SECONDS)) {
            fail("The call did not terminate in time");
        }

        assertNull(responseObserver.getError());
        List<ValidateTokenResponse> results = responseObserver.getValues();
        assertEquals(1, results.size());
        
        ValidateTokenResponse response = results.get(0);
        assertFalse(response.getIsValid());
        assertEquals(UserInfo.getDefaultInstance(), response.getUserInfo());
    }

    @Test
    void testGoogleLoginNotImplemented() throws Exception {
        // Arrange
        GoogleLoginRequest request = GoogleLoginRequest.newBuilder()
                .setAuthCode("some-auth-code")
                .build();

        StreamRecorder<AuthResponse> responseObserver = StreamRecorder.create();

        // Act & Assert
        assertThrows(RuntimeException.class, () -> {
            authGrpcService.googleLogin(request, responseObserver);
        }, "Method not implemented");
    }
} 