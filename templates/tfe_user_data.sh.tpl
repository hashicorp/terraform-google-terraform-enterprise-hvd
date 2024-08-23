#!/usr/bin/env bash

LOGFILE="/var/log/tfe-cloud-init.log"
TFE_CONFIG_DIR="/etc/terraform-enterprise"
TFE_LICENSE_PATH="$TFE_CONFIG_DIR/tfe-license.hclic"
TFE_TLS_CERTS_DIR="$TFE_CONFIG_DIR/tls"
TFE_SETTINGS_PATH="$TFE_CONFIG_DIR/docker-compose.yaml"
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
      log "ERROR" "'$OS_DISTRO_NAME' is not a supported Linux OS distro for TFE."
      exit_script 1
  esac

  echo "$OS_DISTRO_DETECTED"
}

install_gcloud_sdk () {
# https://cloud.google.com/sdk/docs/install-sdk#linux
  if [[ -n "$(command -v gcloud)" ]]; then
    echo "INFO: Detected gcloud SDK is already installed."
  else
    echo "INFO: Attempting to install gcloud SDK."
    if [[ -n "$(command -v python)" ]]; then
      curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-479.0.0-linux-x86_64.tar.gz -o google-cloud-sdk.tar.gz
      tar xzf google-cloud-sdk.tar.gz
      ./google-cloud-sdk/install.sh --quiet
    else
      echo "ERROR: gcloud SDK requires Python but it was not detected on system."
      exit_script 5
    fi
  fi
}

function install_docker {
  local OS_DISTRO="$1"
  local OS_MAJOR_VERSION=$(grep "^VERSION_ID=" /etc/os-release | cut -d"\"" -f2 | cut -d"." -f1)
  local DOCKER_VERSION
	local DOCKER_CLI_VERSION
  if command -v docker > /dev/null; then
    log "INFO" "Detected 'docker' is already installed. Skipping."
  else
    if [[ "$OS_DISTRO" == "ubuntu" ]]; then
      # https://docs.docker.com/engine/install/ubuntu/
      log "INFO" "Installing Docker for Ubuntu."
      # Add Docker's official GPG key:
      apt-get update
      apt-get install ca-certificates curl
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc

      # Add the repository to Apt sources:
      echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
      apt-get update
      DOCKER_VERSION=$(apt-cache madison docker-ce | awk '{ print $3 }' | grep ${docker_version})
      DOCKER_CLI_VERSION=$(apt-cache madison docker-ce-cli | awk '{ print $3 }' | grep ${docker_version})
      apt-get install -y docker-ce="$DOCKER_VERSION" docker-ce-cli=$DOCKER_CLI_VERSION containerd.io docker-compose-plugin
    elif [[ "$OS_DISTRO" == "rhel" || "$OS_DISTRO" == "centos" ]]; then
      # https://docs.docker.com/engine/install/rhel/ or https://docs.docker.com/engine/install/centos/
      log "Warning" "Docker is no longer supported on RHEL 8 and beyond. Installing Docker CE..."
      yum install -y yum-utils
      yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      DOCKER_VERSION=$(yum list docker-ce --showduplicates | sort -r| awk '{ print $2 }' | grep ${docker_version} )
      DOCKER_CLI_VERSION=$(yum list docker-ce-cli --showduplicates | sort -r| awk '{ print $2 }' | grep ${docker_version} )
      yum install -y docker-ce-$DOCKER_VERSION docker-ce-cli-$DOCKER_CLI_VERSION containerd.io docker-compose-plugin
    fi
    systemctl enable --now docker.service
  fi
}
retrieve_secret_from_gcpsm() {
  local SECRET_ID="$1"
  SECRET=$(gcloud secrets versions access latest --secret="$SECRET_ID")
  echo "$SECRET"
}

function retrieve_certs_from_gcpsm {
  local SECRET_ID="$1"
  local DESTINATION_PATH="$2"
  local SECRET_REGION=$REGION
  local CERT_DATA

  if [[ -z "$SECRET_ID" ]]; then
    log "ERROR" "Secret ID cannot be empty. Exiting."
    exit_script 5
  else
    log "INFO" "Retrieving value of secret '$SECRET_ID' from Secrets Manager."
    CERT_DATA=$(gcloud secrets versions access latest --secret=$SECRET_ID)
    echo "$CERT_DATA" | base64 -d > $DESTINATION_PATH
	fi
}

function configure_log_forwarding {
  cat > "$TFE_LOG_FORWARDING_CONFIG_PATH" << EOF
${fluent_bit_rendered_config}
EOF
}

# https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/configuration
function generate_tfe_docker_compose_config {
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
      TFE_RUN_PIPELINE_DRIVER: ${tfe_run_pipeline_driver}
      TFE_RUN_PIPELINE_IMAGE: ${tfe_run_pipeline_image}
      TFE_BACKUP_RESTORE_TOKEN: ${tfe_backup_restore_token}
      TFE_NODE_ID: ${tfe_node_id}
      TFE_HTTP_PORT: ${tfe_http_port}
      TFE_HTTPS_PORT: ${tfe_https_port}
%{ if tfe_operational_mode != "disk" ~}
      # Database settings
      TFE_DATABASE_HOST: ${tfe_database_host}
      TFE_DATABASE_NAME: ${tfe_database_name}
      TFE_DATABASE_USER: ${tfe_database_user}
      TFE_DATABASE_PASSWORD: ${tfe_database_password}
      TFE_DATABASE_PARAMETERS: ${tfe_database_parameters}
      # Object storage settings
      TFE_OBJECT_STORAGE_TYPE: ${tfe_object_storage_type}
      TFE_OBJECT_STORAGE_GOOGLE_BUCKET: ${tfe_object_storage_google_bucket}
      TFE_OBJECT_STORAGE_GOOGLE_CREDENTIALS: ${tfe_object_storage_google_credentials}
      TFE_OBJECT_STORAGE_GOOGLE_PROJECT: ${tfe_object_storage_google_project}
%{ if tfe_operational_mode == "active-active" ~}
      # Vault settings
      TFE_VAULT_CLUSTER_ADDRESS: https://$VM_PRIVATE_IP:8201
      # Redis settings.
      TFE_REDIS_HOST: ${tfe_redis_host}
      TFE_REDIS_USE_TLS: ${tfe_redis_use_tls}
      TFE_REDIS_USE_AUTH: ${tfe_redis_use_auth}
      TFE_REDIS_PASSWORD: ${tfe_redis_password}
%{ endif ~}
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
      TFE_DISK_CACHE_PATH: ${tfe_disk_cache_path}
      TFE_DISK_CACHE_VOLUME_NAME: ${tfe_disk_cache_volume_name}
      TFE_RUN_PIPELINE_DOCKER_NETWORK: ${tfe_run_pipeline_docker_network}
%{ if tfe_hairpin_addressing ~}
      # Prevent loopback with Layer 4 load balancer with hairpinning TFE agent traffic
      TFE_RUN_PIPELINE_DOCKER_EXTRA_HOSTS: ${tfe_hostname}:$VM_PRIVATE_IP
%{ endif ~}

      # Network settings
      TFE_IACT_SUBNETS: ${tfe_iact_subnets}
      TFE_IACT_TRUSTED_PROXIES: ${tfe_iact_trusted_proxies}
      TFE_IACT_TIME_LIMIT: ${tfe_iact_time_limit}

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
      - 80:80
      - 443:443
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
%{ if tfe_operational_mode == "disk" ~}
      - type: bind
        source: ${tfe_mounted_disk_path}
        target: /var/lib/terraform-enterprise
%{ endif ~}
      - type: volume
        source: terraform-enterprise-cache
        target: /var/cache/tfe-task-worker/terraform
volumes:
  terraform-enterprise-cache:
EOF
}

function exit_script {
  if [[ "$1" == 0 ]]; then
    log "INFO" "tfe_user_data script finished successfully!"
  else
    log "ERROR" "tfe_user_data script finished with error code $1."
  fi

  exit "$1"
}

function main() {
  log "INFO" "Beginning TFE user_data script."
  log "INFO" "Determining Linux operating system distro..."
  OS_DISTRO=$(detect_os_distro)
  log "INFO" "Detected Linux OS distro is '$OS_DISTRO'."

  log "INFO" "Scraping GCP instance metadata for private IP address..."

  VM_PRIVATE_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
  log "INFO" "Detected GCP instance private IP address is '$VM_PRIVATE_IP'."


  log "INFO" "Creating TFE directories..."
  mkdir -p $TFE_CONFIG_DIR $TFE_TLS_CERTS_DIR
%{ if tfe_operational_mode == "disk" ~}
  log "INFO" "Creating TFE directories ${tfe_mounted_disk_path}"
  mkdir -p ${tfe_mounted_disk_path}
%{ endif ~}
  log "INFO" "Installing software dependencies..."
  install_gcloud_sdk "$OS_DISTRO"
  install_docker "$OS_DISTRO"

  # check if still needed
  # if [[ "$OS_DISTRO" == "rhel" ]]; then
  #   log "INFO" "Resizing '/' and '/var' partitions for RHEL."
  #   lvresize -r -L +8G /dev/mapper/rootvg-rootlv
  #   lvresize -r -L +32G /dev/mapper/rootvg-varlv
  # fi

  log "INFO" "Retrieving TFE license file..."
  TFE_LICENSE=$(retrieve_secret_from_gcpsm "${tfe_license_secret_id}")

  log "INFO" "Retrieving TFE TLS certificate..."
  retrieve_certs_from_gcpsm "${tfe_tls_cert_secret_id}" "$TFE_TLS_CERTS_DIR/cert.pem"
  log "INFO" "Retrieving TFE TLS private key..."
  retrieve_certs_from_gcpsm "${tfe_tls_privkey_secret_id}" "$TFE_TLS_CERTS_DIR/key.pem"
  log "INFO" "Retrieving TFE TLS CA bundle..."
  retrieve_certs_from_gcpsm "${tfe_tls_ca_bundle_secret_id}" "$TFE_TLS_CERTS_DIR/bundle.pem"

  log "INFO" "Retrieving 'TFE_ENCRYPTION_PASSWORD' secret..."
  TFE_ENCRYPTION_PASSWORD=$(gcloud secrets versions access latest --secret=${tfe_encryption_password_secret_id})

  if [[ "${tfe_log_forwarding_enabled}" == "true" ]]; then
    log "INFO" "Generating '$TFE_LOG_FORWARDING_CONFIG_PATH' file for log forwarding."
    configure_log_forwarding
  fi

  log "INFO" "Generating '$TFE_SETTINGS_PATH' file."
  generate_tfe_docker_compose_config

  log "INFO" "Authenticating to '${tfe_image_repository_url}' container registry."
  docker login ${tfe_image_repository_url} --username terraform --password $TFE_LICENSE

  log "INFO" "Pulling TFE container image '${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}' down locally."
  docker pull ${tfe_image_repository_url}/${tfe_image_name}:${tfe_image_tag}

  log "INFO" "Starting TFE application via Docker Compose."
  if command -v docker-compose > /dev/null; then
    docker-compose --file $TFE_SETTINGS_PATH up --detach
  else
    docker compose --file $TFE_SETTINGS_PATH up --detach
  fi

  log "INFO" "Sleeping for a minute while TFE initializes."
  sleep 60

  log "INFO" "Polling TFE health check endpoint until the app becomes ready..."
  while ! curl -ksfS --connect-timeout 5 https://$VM_PRIVATE_IP/_health_check; do
    sleep 5
  done

  exit_script 0
}

main "$@"
