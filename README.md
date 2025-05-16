# FinStop Auth Service (gRPC)

A secure authentication service built with Spring Boot and gRPC, providing user registration, login, and token validation functionalities.

## Features

- User registration with custom fields (username, password, age, profession, education)
- Secure login with JWT token generation
- Token validation
- Google OAuth integration (planned)
- gRPC API endpoints
- Integration tests with H2 database

## Tech Stack

- Java 11
- Spring Boot 2.7.9
- gRPC
- Spring Security
- JWT Authentication
- PostgreSQL (Production)
- H2 Database (Testing)
- Maven

## Prerequisites

- Java 11 or higher
- Maven 3.6 or higher
- PostgreSQL 12 or higher

## Configuration

### Environment Variables

The following environment variables need to be set:

```properties
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
JWT_SECRET=your_jwt_secret_key
SERVER_PORT=8080 (optional, defaults to 8080)
```

### Database Configuration

Production database configuration in `application.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/finstop_auth
    username: postgres
    password: postgres
```

## Building and Running

1. Clone the repository:
```bash
git clone https://github.com/yourusername/1finstop-auth-service-grpc.git
cd 1finstop-auth-service-grpc
```

2. Build the project:
```bash
./mvnw clean install
```

3. Run the application:
```bash
./mvnw spring-boot:run
```

The gRPC server will start on port 9090 (configurable in application.yml).

## Testing

Run the tests using:
```bash
./mvnw test
```

## API Documentation

### gRPC Services

1. Registration
```protobuf
rpc Register(RegisterRequest) returns (AuthResponse)
```

2. Login
```protobuf
rpc Login(LoginRequest) returns (AuthResponse)
```

3. Google Login (Planned)
```protobuf
rpc GoogleLogin(GoogleLoginRequest) returns (AuthResponse)
```

4. Token Validation
```protobuf
rpc ValidateToken(ValidateTokenRequest) returns (ValidateTokenResponse)
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 