# 🚀 Java 17 with Gradle Project Template

This repository contains a ready-to-use template for building Java projects using Gradle. It’s designed for modern Java
development with version 17, providing a streamlined setup to get started quickly.

## 🛠️ Getting Started

### Prerequisites

- Ensure you have Docker installed and running.
- A code editor like Visual Studio Code (with the Remote - Containers extension) or IntelliJ IDEA is recommended for
  working with this project.

### Setup Instructions

1. **Open the Project in Your Editor:**

    - If using VS Code, it should automatically prompt you to reopen the project in the DevContainer.
    - For IntelliJ IDEA, configure it to use the Docker-based environment if needed.

2. **Build and Run the Project:**

   ```bash
   ./gradlew build
   ./gradlew run
   ```

The default Gradle tasks will compile and run your Java application.

## 🧩 Features

- **Java 17**: The template is configured for Java 17, taking advantage of the latest features and improvements.
- **Gradle Build System**: Gradle is used for dependency management and build automation.
- **Pre-configured DevContainer**: Ensures a consistent development environment across all platforms (Windows, macOS,
  Linux).

## 📝 Usage

This template can be used as a starting point for any Java project that requires a modern setup with Gradle. The
configuration is flexible and can be easily adapted to your specific needs.

### Customizing the Build

You can customize the `build.gradle` script to add additional dependencies, plugins, or tasks depending on your project
requirements.
