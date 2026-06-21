# Install Docker on Ubuntu

This guide shows a concise, step-by-step installation of Docker on Ubuntu and a simple ERPNext setup using Docker Compose.

## Install Docker on Ubuntu

### 1 — Set up Docker's apt repository

First update apt and install dependencies:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
```

#### Add Docker's official GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### 2 — Add the repository to Apt sources

```bash
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

### 3 — Update package index

```bash
sudo apt update
```

### 4 — Install Docker packages

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 5 — Verify Docker is running

```bash
sudo systemctl status docker
sudo docker run --rm hello-world
```

If the `hello-world` container runs and prints a welcome message, Docker is installed correctly.

### 6 — Optional: run Docker without sudo

Add your user to the `docker` group (then log out and back in for the change to take effect):

```bash
sudo usermod -aG docker $USER
# then log out and back in, or run: newgrp docker
```

---

# ERPNext Setup (local, using Docker Compose)

These steps assume you have the workspace files `compose.local.yaml` and related env files in the current directory, and that you want a local testing setup.

> Replace `erp.localhost` with your production domain when deploying to a public server.

## 1 — Run the containers

```bash
docker compose -p local -f compose.local.yaml up -d
```

This starts the services defined in `compose.local.yaml` in detached mode.

## 2 — Create site and install apps

Create a new site (example uses `erp.localhost` and simple passwords for local testing):

```bash
docker compose -p local exec backend bench new-site erp.localhost \
  --mariadb-user-host-login-scope='%' \
  --db-root-password 123 \
  --admin-password admin \
  --install-app erpnext
```

Optionally add additional apps (example: HRMS):

```bash
docker compose -p local exec backend bench get-app hrms
docker compose -p local exec backend bench --site erp.localhost install-app hrms
```

## 3 — Open the site

- For local testing: open `http://erp.localhost:8080` (or the port your Compose config exposes).
- For production: use your actual domain (ensure DNS, TLS, and firewall are configured).

---

## Notes & troubleshooting

- If `docker compose` is not found, ensure the `docker-compose-plugin` is installed and try `docker compose version`.
- If you get permission errors after adding your user to the `docker` group, log out and log back in or run `newgrp docker`.
- For production, secure your MariaDB and Frappe/ERPNext credentials, and enable TLS (Let's Encrypt or other CA).

## References

- Official Docker install docs: https://docs.docker.com/engine/install/ubuntu/
- ERPNext / Frappe Docker setups: consult your project's Compose files and ERPNext docs for production hardening.
