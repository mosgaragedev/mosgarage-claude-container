# 🐍 Python Project Template with Poetry

This repository provides a template for Python projects using Poetry for dependency management and packaging. It’s
designed to offer a clean and modern setup for Python development.

## 🛠️ Getting Started

### Prerequisites

- Docker installed and running.
- A code editor like Visual Studio Code (with the Remote - Containers extension) or PyCharm.

### Setup Instructions

1. **Open the Project in Your Editor:**

    - If using VS Code, it should automatically prompt you to reopen the project in the DevContainer.
    - For PyCharm, ensure Docker is configured as the runtime environment.

2. **Install Dependencies with Poetry:**

   Inside the container, install the dependencies using Poetry:

   ```bash
   poetry install
   ```

This command will create a virtual environment and install the dependencies specified in the `pyproject.toml` file.

## 🧩 Features

- **Poetry for Dependency Management**: Poetry simplifies dependency management and packaging in Python projects.
- **Pre-configured DevContainer**: Ensures a consistent environment across all platforms (Windows, macOS, Linux).

## 📝 Usage

This template can be used as a starting point for any Python project that benefits from using Poetry for dependency
management. The configuration is modular and easy to extend.

### Customizing Dependencies

You can manage your dependencies directly in the `pyproject.toml` file. To add a new dependency, use:

```bash
poetry add <package-name>
```

For development dependencies:

```bash
poetry add --dev <package-name>
```

## 🧪 Running Tests

To run unit tests, use:

```bash
poetry run pytest
```

Test results will be displayed in the terminal, and detailed reports can be generated if needed.
