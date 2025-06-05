#!/bin/bash

# {{ project_name }} CI Deployment Script
# Deploy applications and packages to various targets

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly BUILD_DIR="${PROJECT_ROOT}/build"
readonly PACKAGE_DIR="${BUILD_DIR}/packages"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# CI Environment Detection
detect_ci_environment() {
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "github-actions"
    elif [[ -n "${GITLAB_CI:-}" ]]; then
        echo "gitlab-ci"
    elif [[ -n "${CI:-}" ]]; then
        echo "generic-ci"
    else
        echo "local"
    fi
}

readonly CI_ENVIRONMENT=$(detect_ci_environment)

# Disable colors in CI unless forced
if [[ "$CI_ENVIRONMENT" != "local" ]] && [[ "${FORCE_COLOR:-false}" != "true" ]]; then
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" BOLD="" NC=""
fi

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "${CYAN}${BOLD}=== $* ===${NC}"; }

# Deploy to staging server
deploy_to_staging() {
    if [[ "${DEPLOY_STAGING:-false}" != "true" ]]; then
        return 0
    fi
    
    log_section "Deploying to staging"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would deploy to staging server"
        return 0
    fi
    
    # Example staging deployment
    log_info "Deploying to staging server..."
    # Add actual staging deployment logic here
    
    log_success "Deployment to staging completed"
}

# Deploy to GitHub Releases
deploy_to_github_releases() {
    if [[ "${DEPLOY_GITHUB_RELEASES:-false}" != "true" ]] || [[ "$CI_ENVIRONMENT" != "github-actions" ]]; then
        return 0
    fi
    
    log_section "Deploying to GitHub Releases"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would create GitHub release"
        return 0
    fi
    
    # GitHub releases deployment would be handled by GitHub Actions
    log_info "GitHub release deployment configured in workflow"
    log_success "GitHub release deployment setup completed"
}

# Deploy documentation
deploy_documentation() {
    if [[ "${DEPLOY_DOCS:-false}" != "true" ]]; then
        return 0
    fi
    
    log_section "Deploying documentation"
    
    local docs_dir="$BUILD_DIR/docs"
    if [[ ! -d "$docs_dir" ]]; then
        log_warning "No documentation found to deploy"
        return 0
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would deploy documentation"
        return 0
    fi
    
    log_info "Deploying documentation..."
    # Add documentation deployment logic here
    
    log_success "Documentation deployment completed"
}

print_usage() {
    cat << EOF
${BOLD}{{ project_name }} CI Deployment Script${NC}

${BOLD}USAGE:${NC}
    $0 [OPTIONS]

${BOLD}DEPLOYMENT TARGETS:${NC}
    --deploy-staging            Deploy to staging environment
    --deploy-production         Deploy to production environment
    --deploy-github-releases    Create GitHub release
    --deploy-docs               Deploy documentation

${BOLD}OPTIONS:${NC}
    -n, --dry-run               Show what would be done
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EOF
}

# Default values
DEPLOY_STAGING="false"
DEPLOY_GITHUB_RELEASES="false"
DEPLOY_DOCS="false"
DRY_RUN="false"
VERBOSE="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --deploy-staging) DEPLOY_STAGING="true"; shift ;;
        --deploy-github-releases) DEPLOY_GITHUB_RELEASES="true"; shift ;;
        --deploy-docs) DEPLOY_DOCS="true"; shift ;;
        -n|--dry-run) DRY_RUN="true"; shift ;;
        -v|--verbose) VERBOSE="true"; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

main() {
    cd "$PROJECT_ROOT"
    
    log_info "Starting {{ project_name }} deployment..."
    
    deploy_to_staging
    deploy_to_github_releases
    deploy_documentation
    
    log_success "{{ project_name }} deployment completed!"
}

main "$@"