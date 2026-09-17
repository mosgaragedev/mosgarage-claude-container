# Install dependencies
apt-get update \
&& apt-get install -y \
    git \
    libicu-dev \
    libpq-dev \
    libzip-dev \
    unzip \
    wget \
    zip \
    curl \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Install Poetry
curl -sSL https://install.python-poetry.org | python3 -

# Set the PATH environment variable correctly
export PATH="/root/.local/bin:$PATH"

poetry --version
poetry install
