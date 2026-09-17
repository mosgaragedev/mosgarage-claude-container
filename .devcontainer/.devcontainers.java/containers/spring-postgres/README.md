# 🌱 Spring Boot with Java 17, Gradle 8.8, and PostgreSQL 14 Template

This template is a ready-to-use Spring Boot project configured with Java 17, Gradle 8.8, and PostgreSQL 14. It provides
a solid foundation for developing backend applications using modern Java features and robust database management with
PostgreSQL.

## 🛠️ Getting Started

### Prerequisites

- Docker installed and running.
- An IDE like Visual Studio Code (with the Remote - Containers extension) or IntelliJ IDEA.

### Setup Instructions

1. **Open the Project in Your Editor:**

    - If using VS Code, it should automatically prompt you to reopen the project in the DevContainer.
    - For IntelliJ IDEA, you may need to configure Docker as the runtime environment.

2. **Run the Project:**

   ```bash
   ./gradlew bootRun
   ```

   The application will start with PostgreSQL as the database, with the necessary configurations already in place.

## 🧩 Features

- **Spring Boot with Java 17**: Modern Java with the latest Spring Boot features.
- **Gradle 8.8**: Efficient build automation and dependency management.
- **PostgreSQL 14 Integration**: Pre-configured PostgreSQL setup for easy database management.
- **Pre-configured DevContainer**: Ensures consistent environments across platforms (Windows, macOS, Linux).

## 📝 Usage

This template is ideal for backend applications that require modern Java, reliable database management with PostgreSQL,
and the flexibility of Gradle for builds and dependency management.

### Database Configuration

The project is pre-configured to use PostgreSQL as its database. The connection settings are managed via the
`application.properties` file under `src/main/resources`:

```properties
spring.application.name=spring-postgres
# Database
spring.datasource.url=jdbc:postgresql://database:5432/spring-postgres
spring.datasource.username=postgres
spring.datasource.password=postgres
spring.jpa.hibernate.ddl-auto=update
```

You can customize these settings according to your requirements.
