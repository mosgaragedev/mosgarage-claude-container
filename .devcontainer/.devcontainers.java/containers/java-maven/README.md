# ☕ Java 21 with Maven Project Template

This repository provides a template for building Java applications using Java 21 and Maven. It’s ideal for modern Java
projects that need a reliable and scalable setup with Maven for dependency management.

## 🛠️ Getting Started

### Prerequisites

- Docker installed and running.
- A code editor like Visual Studio Code (with the Remote - Containers extension) or IntelliJ IDEA.

### Setup Instructions

1. **Open the Project in Your Editor:**

    - If using VS Code, it should automatically prompt you to reopen the project in the DevContainer.
    - For IntelliJ IDEA, ensure Docker is configured as the runtime environment.

2. **Build and Run the Project:**

   ```bash
   mvn clean install
   mvn exec:java -Dexec.mainClass="org.example.Main
   ```

The project will compile and run based on the configurations defined in the `pom.xml`.

## 🧩 Features

- **Java 21**: The template is configured to use the latest features available in Java 21.
- **Maven Build System**: Maven is used for managing dependencies and automating the build process.
- **Pre-configured DevContainer**: Ensures a consistent development environment across all platforms (Windows, macOS,
  Linux).

## 📝 Usage

This template can be used as a starting point for any Java application that requires a modern setup with Maven. The
configuration is flexible and can be easily adapted to your specific needs.

### Customizing the Build

You can customize the `pom.xml` file to add additional dependencies, plugins, or build profiles depending on your
project requirements.
