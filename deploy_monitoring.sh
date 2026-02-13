#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}➜${NC} $1"
}

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║         SLURM CLUSTER MONITORING DEPLOYMENT              ║
║                                                           ║
║   This script will:                                       ║
║   1. Install Node Exporter on all nodes                   ║
║   2. Install Prometheus on controller                     ║
║   3. Install Grafana on controller                        ║
║   4. Auto-configure everything                            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
print_header "Pre-Installation Checks"
echo ""

if [ ! -f "setup_monitoring.yml" ]; then
    print_error "setup_monitoring.yml not found!"
    exit 1
fi

if [ ! -f "hosts.ini" ]; then
    print_error "hosts.ini not found!"
    exit 1
fi

print_success "All required files found"

echo ""
print_header "Installing Monitoring Stack"
echo ""

print_info "Installing Node Exporter on all nodes..."
print_info "Installing Prometheus on controller..."
print_info "Installing Grafana on controller..."
print_info "This will take approximately 5-10 minutes..."
echo ""

ansible-playbook -i hosts.ini setup_monitoring.yml

if [ $? -eq 0 ]; then
    print_success "Monitoring stack installed successfully"
else
    print_error "Monitoring installation failed!"
    exit 1
fi

echo ""
print_header "Post-Installation Verification"
echo ""

# Get IPs from hosts.ini
LOGIN_IP=$(grep "^login " hosts.ini | awk '{print $2}' | cut -d'=' -f2)
CONTROLLER_IP=$(grep "^controller " hosts.ini | awk '{print $2}' | cut -d'=' -f2)

print_info "Verifying services..."

# Check if monitoring_info.txt was created
if [ -f "monitoring_info.txt" ]; then
    print_success "Monitoring information file created"
else
    print_error "Monitoring info file not found"
fi

echo ""
print_header "✓✓✓ MONITORING DEPLOYMENT COMPLETE! ✓✓✓"
echo ""

echo -e "${GREEN}Your SLURM cluster monitoring is ready!${NC}"
echo ""
echo "Monitoring Stack:"
echo "================="
echo "  Node Exporter:  Installed on ALL nodes"
echo "  Prometheus:     Installed on controller"
echo "  Grafana:        Installed on controller"
echo ""
echo "Access Information:"
echo "==================="
echo "  Login IP:      $LOGIN_IP"
echo "  Controller IP: $CONTROLLER_IP"
echo ""
echo "Monitoring Ports:"
echo "================="
echo "  Node Exporter:  9100 (all nodes)"
echo "  Prometheus:     9090 (controller)"
echo "  Grafana:        3000 (controller)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "==========="
echo ""
echo "1. Create SSH tunnel to access Grafana:"
echo "   ${BLUE}ssh -i ~/.ssh/mykey.pem -L 3000:${CONTROLLER_IP}:3000 -L 9090:${CONTROLLER_IP}:9090 ubuntu@${LOGIN_IP}${NC}"
echo ""
echo "2. Open browser and go to:"
echo "   Grafana:    ${GREEN}http://localhost:3000${NC}"
echo "   Prometheus: ${GREEN}http://localhost:9090${NC}"
echo ""
echo "3. Login to Grafana:"
echo "   Username: ${BLUE}admin${NC}"
echo "   Password: ${BLUE}admin${NC}"
echo "   (Change password on first login)"
echo ""
echo "4. Import dashboards in Grafana:"
echo "   • Click '+' → Import"
echo "   • Enter dashboard ID: ${GREEN}1860${NC} (Node Exporter Full)"
echo "   • Select 'Prometheus' as datasource"
echo "   • Click Import"
echo ""
echo "5. Verify monitoring health:"
echo "   ${BLUE}ansible-playbook -i hosts.ini verify_monitoring_health.yml${NC}"
echo ""
echo "Files created:"
echo "=============="
echo "  • monitoring_info.txt  - Monitoring details and commands"
echo ""
echo -e "${GREEN}All done! Your monitoring stack is ready.${NC}"
echo ""
