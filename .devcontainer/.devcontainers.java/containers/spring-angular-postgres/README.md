# 🌐 Fullstack Template: Spring Boot (Java 17) + Angular 18 + PostgreSQL 14

> ⚠️ **Note:** work in progress !!!

This template is a fullstack setup combining a Spring Boot backend with an Angular frontend and a PostgreSQL database.
It’s designed for building scalable web applications with modern Java and Angular features.

## 🛠️ Getting Started

### Prerequisites

- Docker installed and running.
- An IDE like Visual Studio Code (with the Remote - Containers extension) or IntelliJ IDEA.

### Setup Instructions

1. **Open the Project in Your Editor:**

    - If using VS Code, it should automatically prompt you to reopen the project in the DevContainer.
    - For IntelliJ IDEA, ensure Docker is configured as the runtime environment.

2. **Run the Services:**

   Use Docker Compose to start all services (backend, frontend, and database):

   ```bash
   docker-compose up --build
   ```

This will start the backend on port 8080, the frontend on port 4200, and the PostgreSQL database on port 5432.

## 🧩 Features

- **Spring Boot Backend**: Modern Java 17 with Gradle 8.8 for dependency management.
- **Angular Frontend**: Angular 18 managed by Node.js 20, pre-configured for web development.
- **PostgreSQL 14 Integration**: Robust database management with a pre-configured schema.
- **Pre-configured DevContainer**: Ensures a consistent environment across platforms (Windows, macOS, Linux).

## 📝 Usage

This template is ideal for building fullstack web applications that require a robust backend, a dynamic frontend, and
reliable database management.

### Backend Configuration

The Spring Boot application is configured to connect to the PostgreSQL database using properties defined in the
`application.properties` file:

```properties
spring.application.name=backend
# Database
spring.datasource.url=jdbc:postgresql://database:5432/spring-postgres
spring.datasource.username=postgres
spring.datasource.password=postgres
spring.jpa.hibernate.ddl-auto=update
```

### Frontend Configuration

The Angular application is configured with a proxy to communicate with the Spring Boot backend, ensuring smooth
interaction between the frontend and backend.
