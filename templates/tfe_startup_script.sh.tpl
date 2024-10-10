#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/var/log/tfe-cloud-init.log"
TFE_CONFIG_DIR="/etc/tfe"
TFE_LICENSE_PATH="$TFE_CONFIG_DIR/tfe-license.hclic"
TFE_TLS_CERTS_DIR="$TFE_CONFIG_DIR/tls"
TFE_LOG_FORWARDING_CONFIG_PATH="$TFE_CONFIG_DIR/fluent-bit.conf"

function log {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local log_entry="$timestamp [$level] - $message"

  echo "$log_entry" | tee -a "$LOGFILE"
}

function detect_os_distro {
  local OS_DISTRO_NAME=$(grep "^NAME=" /etc/os-release | cut -d"\"" -f2)
  local OS_DISTRO_DETECTED

  case "$OS_DISTRO_NAME" in
    "Ubuntu"*)
      OS_DISTRO_DETECTED="ubuntu"
      ;;
    "CentOS Stream"*)
      OS_DISTRO_DETECTED="centos"
      ;;
    "Red Hat"*)
      OS_DISTRO_DETECTED="rhel"
      ;;
    *)
      log "ERROR" "'$OS_DISTRO_NAME' is not a supported Linux OS distro for this TFE module."
      exit_script 1
  esac

  echo "$OS_DISTRO_DETECTED"
}

function install_gcloud_cli {
  # https://cloud.google.com/sdk/docs/install-sdk#linux
  if command -v gcloud > /dev/null; then
    log "INFO" "Detected 'gcloud' CLI is already installed. Skipping gcloud CLI install."
  else
    log "INFO" "Installing gcloud CLI."
    if command -v python > /dev/null; then
      curl -Lo google-cloud-cli-linux-x86_64.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
      tar xzf google-cloud-cli-linux-x86_64.tar.gz
      ./google-cloud-sdk/install.sh --quiet --usage-reporting false
    else
      log "ERROR" "gcloud CLI install requires Python but it was not detected on system."
      exit_script 2
    fi
  fi
}

function install_docker {
  local OS_DISTRO="$1"
  local OS_MAJOR_VERSION="$2"
  local DOCKER_VERSION_STRING
	local DOCKER_CLI_VERSION_STRING

  if command -v docker > /dev/null; then
    log "INFO" "Detected 'docker' is already installed. Skipping Docker install."
  else
    if [[ "$OS_DISTRO" == "ubuntu" ]]; then
      # https://docs.docker.com/engine/install/ubuntu/
      log "INFO" "Installing Docker for Ubuntu."
      # Add Docker's official GPG key:
      apt-get update
      apt-get install -y ca-certificates curl
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc
      # Add the repository to Apt sources:
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      # Install the Docker packages:
      DOCKER_VERSION_STRING=$(apt-cache madison docker-ce | awk '{ print $3 }' | grep ${docker_version})
      DOCKER_CLI_VERSION_STRING=$(apt-cache madison docker-ce-cli | awk '{ print $3 }' | grep ${docker_version})
      apt-get install -y docker-ce=$DOCKER_VERSION_STRING docker-ce-cli=$DOCKER_CLI_VERSION_STRING containerd.io docker-compose-plugin > /dev/null 2>&1
    elif [[ "$OS_DISTRO" == "rhel" || "$OS_DISTRO" == "centos" ]]; then
      # https://docs.docker.com/engine/install/rhel/ or https://docs.docker.com/engine/install/centos/
      log "WARNING" "Docker is no longer supported on RHEL 8 and newer. Installing Docker Community Edition (CE) from CentOS repository."
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      DOCKER_VERSION=$(yum list docker-ce --showduplicates | sort -r| awk '{ print $2 }' | grep ${docker_version} )
      DOCKER_CLI_VERSION=$(yum list docker-ce-cli --showduplicates | sort -r| awk '{ print $2 }' | grep ${docker_version} )
      yum install -y docker-ce-$DOCKER_VERSION docker-ce-cli-$DOCKER_CLI_VERSION containerd.io docker-compose-plugin
    else
      log "ERROR" "Docker installation is currently not supported on $OS_DISTRO $OS_MAJOR_VERSION."
      exit_script 2
    fi
    systemctl enable --now docker.service
    log "INFO" "Docker has been installed and enabled on $OS_DISTRO $OS_MAJOR_VERSION successfully."
  fi
}

function install_podman {
  local OS_DISTRO="$1"
  local OS_MAJOR_VERSION="$2"

  if command -v podman > /dev/null; then
    log "INFO" "Detected 'podman' is already installed. Skipping Podman install."
  else
    if [[ "$OS_DISTRO" == "rhel" || "$OS_DISTRO" == "centos" ]]; then
      log "INFO" "Installing Podman for RHEL $OS_MAJOR_VERSION."
      dnf update -y
      if [[ "$OS_MAJOR_VERSION" == "9" ]]; then
        dnf install -y container-tools
      elif [[ "$OS_MAJOR_VERSION" == "8" ]]; then
        dnf module install -y container-tools
        dnf install -y podman-docker
      else
        log "ERROR" "Podman install for $OS_DISTRO $OS_MAJOR_VERSION is currently not supported by this module."
        exit_script 3
      fi
    else
      log "ERROR" "Podman install for $OS_DISTRO $OS_MAJOR_VERSION is currently not supported by this module."
      exit_script 3
    fi
    systemctl enable --now podman.socket
    log "INFO" "Podman has been installed and enabled on $OS_DISTRO $OS_MAJOR_VERSION successfully."
  fi
}

function retrieve_secret_from_gcp_sm {
  local SECRET_NAME="$1"
  local SECRET_VALUE
  
  if [[ -z "$SECRET_NAME" ]]; then
    log "ERROR" "Secret name cannot be empty. Exiting."
    exit_script 5
  else
    log "INFO" "Retrieving value of secret '$SECRET_NAME' from Google Secret Manager." >&2
    SECRET_VALUE=$(gcloud secrets versions access latest --secret="$SECRET_NAME")
    log "INFO" "Value of secret '$SECRET_NAME' has been retrieved successfully." >&2
    echo "$SECRET_VALUE"
  fi
}

function retrieve_cert_from_gcp_sm {
  local SECRET_NAME="$1"
  local DESTINATION_PATH="$2"
  local CERT_DATA

  if [[ -z "$SECRET_NAME" ]]; then
    log "ERROR" "Secret name cannot be empty. Exiting."
    exit_script 5
  else
    log "INFO" "Retrieving value of secret '$SECRET_NAME' from Google Secret Manager."
    CERT_DATA=$(gcloud secrets versions access latest --secret=$SECRET_NAME)
    echo "$CERT_DATA" | base64 -d > $DESTINATION_PATH
    log "INFO" "Value of '$SECRET_NAME' has been written to '$DESTINATION_PATH' successfully."
	fi
}

function configure_log_forwarding {
  cat > "$TFE_LOG_FORWARDING_CONFIG_PATH" << EOF
${fluent_bit_rendered_config}
EOF
}

# https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration
function generate_tfe_docker_compose_file {
  local TFE_SETTINGS_PATH="$1"

  cat > $TFE_SETTINGS_PATH << EOF
---
name: tfe
services:
  tfe:
    container_name: terraform-enterprise
    image: ${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}
    restart: unless-stopped
    environment:
      # Application settings
      TFE_HOSTNAME: ${tfe_hostname}
      TFE_LICENSE: $TFE_LICENSE
      TFE_LICENSE_PATH: ""
      TFE_OPERATIONAL_MODE: ${tfe_operational_mode}
      TFE_ENCRYPTION_PASSWORD: $TFE_ENCRYPTION_PASSWORD
      TFE_CAPACITY_CONCURRENCY: ${tfe_capacity_concurrency}
      TFE_CAPACITY_CPU: ${tfe_capacity_cpu}
      TFE_CAPACITY_MEMORY: ${tfe_capacity_memory}
      TFE_LICENSE_REPORTING_OPT_OUT: ${tfe_license_reporting_opt_out}
      TFE_USAGE_REPORTING_OPT_OUT: ${tfe_usage_reporting_opt_out}
      TFE_RUN_PIPELINE_DRIVER: ${tfe_run_pipeline_driver}
      TFE_RUN_PIPELINE_IMAGE: ${tfe_run_pipeline_image}
      TFE_BACKUP_RESTORE_TOKEN: ${tfe_backup_restore_token}
      TFE_NODE_ID: ${tfe_node_id}
      TFE_HTTP_PORT: ${tfe_http_port}
      TFE_HTTPS_PORT: ${tfe_https_port}

      # Database settings
      TFE_DATABASE_HOST: ${tfe_database_host}
      TFE_DATABASE_NAME: ${tfe_database_name}
      TFE_DATABASE_USER: ${tfe_database_user}
      TFE_DATABASE_PASSWORD: ${tfe_database_password}
      TFE_DATABASE_PARAMETERS: ${tfe_database_parameters}
      TFE_DATABASE_RECONNECT_ENABLED: ${tfe_database_reconnect_enabled}
      
      # Object storage settings
      TFE_OBJECT_STORAGE_TYPE: ${tfe_object_storage_type}
      TFE_OBJECT_STORAGE_GOOGLE_BUCKET: ${tfe_object_storage_google_bucket}
      TFE_OBJECT_STORAGE_GOOGLE_CREDENTIALS: ${tfe_object_storage_google_credentials}
      TFE_OBJECT_STORAGE_GOOGLE_PROJECT: ${tfe_object_storage_google_project}

%{ if tfe_operational_mode == "active-active" ~}
      # Redis settings
      TFE_REDIS_HOST: ${tfe_redis_host}
      TFE_REDIS_USE_AUTH: ${tfe_redis_use_auth}
      TFE_REDIS_PASSWORD: ${tfe_redis_password}
      TFE_REDIS_USE_TLS: ${tfe_redis_use_tls}
%{ endif ~}

      # TLS settings
      TFE_TLS_CERT_FILE: ${tfe_tls_cert_file}
      TFE_TLS_KEY_FILE: ${tfe_tls_key_file}
      TFE_TLS_CA_BUNDLE_FILE: ${tfe_tls_ca_bundle_file}
      TFE_TLS_CIPHERS: ${tfe_tls_ciphers}
      TFE_TLS_ENFORCE: ${tfe_tls_enforce}
      TFE_TLS_VERSION: ${tfe_tls_version}

      # Observability settings
      TFE_LOG_FORWARDING_ENABLED: ${tfe_log_forwarding_enabled}
      TFE_LOG_FORWARDING_CONFIG_PATH: $TFE_LOG_FORWARDING_CONFIG_PATH
      TFE_METRICS_ENABLE: ${tfe_metrics_enable}
      TFE_METRICS_HTTP_PORT: ${tfe_metrics_http_port}
      TFE_METRICS_HTTPS_PORT: ${tfe_metrics_https_port}

      # Docker driver settings
      TFE_DISK_CACHE_PATH: /var/cache/tfe-task-worker
      TFE_DISK_CACHE_VOLUME_NAME: terraform-enterprise-cache
      TFE_RUN_PIPELINE_DOCKER_NETWORK: ${tfe_run_pipeline_docker_network}
%{ if tfe_hairpin_addressing ~}
      # Prevent loopback with layer 4 load balancer with hairpinning TFE agent traffic
      TFE_RUN_PIPELINE_DOCKER_EXTRA_HOSTS: ${tfe_hostname}:$VM_PRIVATE_IP
%{ endif ~}

      # Network settings
      TFE_IACT_SUBNETS: ${tfe_iact_subnets}
      TFE_IACT_TRUSTED_PROXIES: ${tfe_iact_trusted_proxies}
      TFE_IACT_TIME_LIMIT: ${tfe_iact_time_limit}

      # Vault settings
      TFE_VAULT_DISABLE_MLOCK: ${tfe_vault_disable_mlock}
      TFE_VAULT_USE_EXTERNAL: ${tfe_vault_use_external}
%{ if tfe_operational_mode == "active-active" ~}
      TFE_VAULT_CLUSTER_ADDRESS: https://$VM_PRIVATE_IP:8201
%{ endif ~}

%{ if tfe_hairpin_addressing ~}
    extra_hosts:
      - ${tfe_hostname}:$VM_PRIVATE_IP
%{ endif ~}
    cap_add:
      - IPC_LOCK
    read_only: true
    tmpfs:
      - /tmp:mode=01777
      - /var/run
      - /var/log/terraform-enterprise
    ports:
      - 80:${tfe_http_port}
      - 443:${tfe_https_port}
%{ if tfe_operational_mode == "active-active" ~}
      - 8201:8201
%{ endif ~}
%{ if tfe_metrics_enable ~}
      - ${tfe_metrics_http_port}:${tfe_metrics_http_port}
      - ${tfe_metrics_https_port}:${tfe_metrics_https_port}
%{ endif ~}

    volumes:
      - type: bind
        source: /var/run/docker.sock
        target: /var/run/docker.sock
%{ if tfe_log_forwarding_enabled ~}
      - type: bind
        source: $TFE_LOG_FORWARDING_CONFIG_PATH
        target: $TFE_LOG_FORWARDING_CONFIG_PATH
%{ endif ~}
      - type: bind
        source: $TFE_TLS_CERTS_DIR
        target: /etc/ssl/private/terraform-enterprise
      - type: volume
        source: terraform-enterprise-cache
        target: /var/cache/tfe-task-worker/terraform
volumes:
  terraform-enterprise-cache:
    name: terraform-enterprise-cache
EOF
}

function generate_tfe_podman_manifest {
  local TFE_SETTINGS_PATH="$1"
  
  cat > $TFE_SETTINGS_PATH << EOF
---
apiVersion: "v1"
kind: "Pod"
metadata:
  labels:
    app: "tfe"
  name: "tfe"
spec:
%{ if tfe_hairpin_addressing ~}
  hostAliases:
    - ip: $VM_PRIVATE_IP
      hostnames:
        - "${tfe_hostname}"
%{ endif ~}
  containers:
  - env:
    # Application settings
    - name: "TFE_HOSTNAME"
      value: ${tfe_hostname}
    - name: "TFE_LICENSE"
      value: $TFE_LICENSE
    - name: "TFE_LICENSE_PATH"
      value: ""
    - name: "TFE_OPERATIONAL_MODE"
      value: ${tfe_operational_mode}
    - name: "TFE_ENCRYPTION_PASSWORD"
      value: $TFE_ENCRYPTION_PASSWORD
    - name: "TFE_CAPACITY_CONCURRENCY"
      value: ${tfe_capacity_concurrency}
    - name: "TFE_CAPACITY_CPU"
      value: ${tfe_capacity_cpu}
    - name: "TFE_CAPACITY_MEMORY"
      value: ${tfe_capacity_memory}
    - name: "TFE_LICENSE_REPORTING_OPT_OUT"
      value: ${tfe_license_reporting_opt_out}
    - name: "TFE_USAGE_REPORTING_OPT_OUT"
      value: ${tfe_usage_reporting_opt_out}
    - name: "TFE_RUN_PIPELINE_DRIVER"
      value: ${tfe_run_pipeline_driver}
    - name: "TFE_RUN_PIPELINE_IMAGE"
      value: ${tfe_run_pipeline_image}
    - name: "TFE_BACKUP_RESTORE_TOKEN"
      value: ${tfe_backup_restore_token}
    - name: "TFE_NODE_ID"
      value: ${tfe_node_id}
    - name: "TFE_HTTP_PORT"
      value: ${tfe_http_port}
    - name: "TFE_HTTPS_PORT"
      value: ${tfe_https_port}

    # Database settings
    - name: "TFE_DATABASE_HOST"
      value: ${tfe_database_host}
    - name: "TFE_DATABASE_NAME"
      value: ${tfe_database_name}
    - name: "TFE_DATABASE_USER"
      value: ${tfe_database_user}
    - name: "TFE_DATABASE_PASSWORD"
      value: ${tfe_database_password}
    - name: "TFE_DATABASE_PARAMETERS"
      value: ${tfe_database_parameters}
    - name: "TFE_DATABASE_RECONNECT_ENABLED"
      value: ${tfe_database_reconnect_enabled}

    # Object storage settings
    - name: "TFE_OBJECT_STORAGE_TYPE"
      value: ${tfe_object_storage_type}
    - name: "TFE_OBJECT_STORAGE_GOOGLE_BUCKET"
      value: ${tfe_object_storage_google_bucket}
    - name: "TFE_OBJECT_STORAGE_GOOGLE_CREDENTIALS"
      value: ${tfe_object_storage_google_credentials}
    - name: "TFE_OBJECT_STORAGE_GOOGLE_PROJECT"
      value: ${tfe_object_storage_google_project}

%{ if tfe_operational_mode == "active-active" ~}
    # Redis settings
    - name: "TFE_REDIS_HOST"
      value: ${tfe_redis_host}
    - name: "TFE_REDIS_USE_AUTH"
      value: ${tfe_redis_use_auth}
    - name: "TFE_REDIS_PASSWORD"
      value: ${tfe_redis_password}
    - name: "TFE_REDIS_USE_TLS"
      value: ${tfe_redis_use_tls}
%{ endif ~}

    # TLS settings
    - name: "TFE_TLS_CERT_FILE"
      value: ${tfe_tls_cert_file}
    - name: "TFE_TLS_KEY_FILE"
      value: ${tfe_tls_key_file}
    - name: "TFE_TLS_CA_BUNDLE_FILE"
      value: ${tfe_tls_ca_bundle_file}
    - name: "TFE_TLS_CIPHERS"
      value: ${tfe_tls_ciphers}
    - name: "TFE_TLS_ENFORCE"
      value: ${tfe_tls_enforce}
    - name: "TFE_TLS_VERSION"
      value: ${tfe_tls_version}

    # Observability settings
    - name: "TFE_LOG_FORWARDING_ENABLED"
      value: ${tfe_log_forwarding_enabled}
    - name: "TFE_LOG_FORWARDING_CONFIG_PATH"
      value: $TFE_LOG_FORWARDING_CONFIG_PATH
    - name: "TFE_METRICS_ENABLE"
      value: ${tfe_metrics_enable}
    - name: "TFE_METRICS_HTTP_PORT"
      value: ${tfe_metrics_http_port}
    - name: "TFE_METRICS_HTTPS_PORT"
      value: ${tfe_metrics_https_port}

    # Docker driver settings
    - name: "TFE_DISK_CACHE_PATH"
      value: /var/cache/tfe-task-worker
    - name: "TFE_DISK_CACHE_VOLUME_NAME"
      value: terraform-enterprise-cache
    - name: "TFE_RUN_PIPELINE_DOCKER_NETWORK"
      value: ${tfe_run_pipeline_docker_network}
%{ if tfe_hairpin_addressing ~}
      # Prevent loopback with layer 4 load balancer with hairpinning TFE agent traffic
    - name: "TFE_RUN_PIPELINE_DOCKER_EXTRA_HOSTS"
      value: ${tfe_hostname}:$VM_PRIVATE_IP
%{ endif ~}

    # Network settings
    - name: "TFE_IACT_SUBNETS"
      value: ${tfe_iact_subnets}
    - name: "TFE_IACT_TRUSTED_PROXIES"
      value: ${tfe_iact_trusted_proxies}
    - name: "TFE_IACT_TIME_LIMIT"
      value: ${tfe_iact_time_limit}

    # Vault settings
    - name: "TFE_VAULT_DISABLE_MLOCK"
      value: ${tfe_vault_disable_mlock}
    - name: "TFE_VAULT_USE_EXTERNAL"
      value: ${tfe_vault_use_external}
%{ if tfe_operational_mode == "active-active" ~}
    - name: "TFE_VAULT_CLUSTER_ADDRESS"
      value: https://$VM_PRIVATE_IP:8201
%{ endif ~}

    image: ${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}
    name: "terraform-enterprise"
    ports:
    - containerPort: ${tfe_http_port}
      hostPort: 80
    - containerPort: ${tfe_https_port}
      hostPort: 443
    - containerPort: 8201
      hostPort: 8201
    securityContext:
      capabilities:
        add:
        - "CAP_IPC_LOCK"
        - "CAP_AUDIT_WRITE"
      readOnlyRootFilesystem: true
      seLinuxOptions:
        type: "spc_t"
    volumeMounts:
%{ if tfe_log_forwarding_enabled ~}
    - mountPath: "$TFE_LOG_FORWARDING_CONFIG_PATH"
      name: "fluent-bit"
%{ endif ~}
    - mountPath: "/etc/ssl/private/terraform-enterprise"
      name: "certs"
    - mountPath: "/var/log/terraform-enterprise"
      name: "log"
    - mountPath: "/run"
      name: "run"
    - mountPath: "/tmp"
      name: "tmp"
    - mountPath: "/run/docker.sock"
      name: "docker-sock"
    - mountPath: "/var/cache/tfe-task-worker/terraform"
      name: "terraform-enterprise-cache"
  restartPolicy: "Never"
  volumes:
%{ if tfe_log_forwarding_enabled ~}
  - hostpath:
      path: "$TFE_LOG_FORWARDING_CONFIG_PATH"
      type: "File"
    name: "fluent-bit"
%{ endif ~}
  - hostPath:
      path: "$TFE_TLS_CERTS_DIR"
      type: "Directory"
    name: "certs"
  - emptyDir:
      medium: "Memory"
    name: "log"
  - emptyDir:
      medium: "Memory"
    name: "run"
  - emptyDir:
      medium: "Memory"
    name: "tmp"
  - hostPath:
      path: "/var/run/docker.sock"
      type: "File"
    name: "docker-sock"
  - name: "terraform-enterprise-cache"
    persistentVolumeClaim:
      claimName: "terraform-enterprise-cache"
EOF
}

function generate_tfe_podman_quadlet {
  cat > $TFE_CONFIG_DIR/tfe.kube << EOF
[Unit]
Description=TFE Podman pod

[Install]
WantedBy=default.target

[Service]
Restart=always

[Kube]
Yaml=tfe-pod.yaml
EOF
}

function pull_tfe_image {
  local TFE_CONTAINER_RUNTIME="$1"
  
  log "INFO" "Authenticating to '${tfe_image_repository_url}' container registry."
  log "INFO" "Detected TFE image repository username is '${tfe_image_repository_username}'."
  if [[ "${tfe_image_repository_url}" == "images.releases.hashicorp.com" ]]; then
    log "INFO" "Detected default TFE registry in use. Setting TFE_IMAGE_REPOSITORY_PASSWORD to value of TFE license."
    TFE_IMAGE_REPOSITORY_PASSWORD=$TFE_LICENSE
  else
    log "INFO" "Setting TFE_IMAGE_REPOSITORY_PASSWORD to value of 'tfe_image_repository_password' module input."
    TFE_IMAGE_REPOSITORY_PASSWORD=${tfe_image_repository_password}
  fi
  if [[ "$TFE_CONTAINER_RUNTIME" == "podman" ]]; then
    podman login --username ${tfe_image_repository_username} ${tfe_image_repository_url} --password $TFE_IMAGE_REPOSITORY_PASSWORD
    log "INFO" "Pulling TFE container image '${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}' down locally."
    podman pull ${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}
  else
    echo $TFE_IMAGE_REPOSITORY_PASSWORD | docker login ${tfe_image_repository_url} --username ${tfe_image_repository_username} --password-stdin
    log "INFO" "Pulling TFE container image '${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}' down locally."
    docker pull ${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}
  fi
}

function exit_script {
  if [[ "$1" == 0 ]]; then
    log "INFO" "tfe_startup_script finished successfully!"
  else
    log "ERROR" "tfe_startup_script finished with error code $1."
  fi

  exit "$1"
}

function main {
  log "INFO" "Beginning TFE metadata_startup_script."
  log "INFO" "Determining Linux operating system distro..."
  OS_DISTRO=$(detect_os_distro)
  log "INFO" "Detected Linux OS distro is '$OS_DISTRO'."
  OS_MAJOR_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d"\"" -f2 | cut -d"." -f1)
  log "INFO" "Detected OS major version is '$OS_MAJOR_VERSION'."

  log "INFO" "Scraping GCE instance metadata for private IP address..."
  VM_PRIVATE_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
  log "INFO" "Detected GCE instance private IP address is '$VM_PRIVATE_IP'."

  log "INFO" "Creating TFE directories."
  mkdir -p $TFE_CONFIG_DIR $TFE_TLS_CERTS_DIR
  
  log "INFO" "Installing software dependencies..."
  install_gcloud_cli
  if [[ "${container_runtime}" == "podman" ]]; then
    install_podman "$OS_DISTRO" "$OS_MAJOR_VERSION"
  else
    install_docker "$OS_DISTRO" "$OS_MAJOR_VERSION"
  fi

  log "INFO" "Retrieving TFE_LICENSE..."
  TFE_LICENSE=$(retrieve_secret_from_gcp_sm "${tfe_license_secret_id}")
  log "INFO" "Retrieving TFE_ENCRYPTION_PASSWORD..."
  TFE_ENCRYPTION_PASSWORD=$(retrieve_secret_from_gcp_sm "${tfe_encryption_password_secret_id}")

  log "INFO" "Retrieving TFE_TLS_CERT_FILE..."
  retrieve_cert_from_gcp_sm "${tfe_tls_cert_secret_id}" "$TFE_TLS_CERTS_DIR/cert.pem"
  log "INFO" "Retrieving TFE_TLS_KEY_FILE..."
  retrieve_cert_from_gcp_sm "${tfe_tls_privkey_secret_id}" "$TFE_TLS_CERTS_DIR/key.pem"
  log "INFO" "Retrieving TFE_TLS_CA_BUNDLE_FILE..."
  retrieve_cert_from_gcp_sm "${tfe_tls_ca_bundle_secret_id}" "$TFE_TLS_CERTS_DIR/bundle.pem"

  if [[ "${tfe_log_forwarding_enabled}" == "true" ]]; then
    log "INFO" "Generating '$TFE_LOG_FORWARDING_CONFIG_PATH' file for log forwarding."
    configure_log_forwarding
  fi

  if [[ "${container_runtime}" == "podman" ]]; then
    TFE_SETTINGS_PATH="$TFE_CONFIG_DIR/tfe-pod.yaml"
    log "INFO" "Generating '$TFE_SETTINGS_PATH' Kubernetes pod manifest for TFE on Podman."
    generate_tfe_podman_manifest "$TFE_SETTINGS_PATH"
    log "INFO" "Preparing to download TFE container image..."
    pull_tfe_image "${container_runtime}"
    log "INFO" "Configuring systemd service using Quadlet to manage TFE Podman containers."
    generate_tfe_podman_quadlet
    cp "$TFE_SETTINGS_PATH" "/etc/containers/systemd"
    cp "$TFE_CONFIG_DIR/tfe.kube" "/etc/containers/systemd"
    log "INFO" "Starting 'tfe' service (Podman containers)."
    systemctl daemon-reload
    systemctl start tfe.service
  else
    TFE_SETTINGS_PATH="$TFE_CONFIG_DIR/docker-compose.yaml"
    log "INFO" "Generating '$TFE_SETTINGS_PATH' file for TFE on Docker."
    generate_tfe_docker_compose_file "$TFE_SETTINGS_PATH"
    log "INFO" "Preparing to download TFE container image..."
    pull_tfe_image "${container_runtime}"
    log "INFO" "Starting TFE application using Docker Compose."
    if command -v docker-compose > /dev/null; then
      docker-compose --file $TFE_SETTINGS_PATH up --detach
    else
      docker compose --file $TFE_SETTINGS_PATH up --detach
    fi
  fi

  log "INFO" "Sleeping for a minute while TFE initializes."
  sleep 60

  log "INFO" "Polling TFE health check endpoint until the app becomes ready..."
  while ! curl -ksfS --connect-timeout 5 https://$VM_PRIVATE_IP/_health_check; do
    sleep 5
  done

  exit_script 0
}

main
