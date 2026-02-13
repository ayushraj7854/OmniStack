#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KEY_NAME="mykey"
REGION="ap-south-1"
KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"

# Function to print colored output
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

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1 completed successfully"
    else
        print_error "$1 failed"
        exit 1
    fi
}

# ASCII Banner
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           SLURM HPC CLUSTER DEPLOYMENT TOOL              ║
║                                                           ║
║              Production-Ready Architecture                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ==========================================
# USER INPUT: Number of Compute Nodes
# ==========================================
echo ""
print_header "Cluster Configuration"
echo ""
echo "How many compute nodes do you want to deploy?"
echo ""
echo "Recommendations:"
echo "  • Small cluster (testing):        1-2 nodes"
echo "  • Medium cluster (development):   3-5 nodes"
echo "  • Large cluster (production):     6-10 nodes"
echo ""
read -p "Enter number of compute nodes (1-20): " NUM_COMPUTE

# Validate input
if ! [[ "$NUM_COMPUTE" =~ ^[0-9]+$ ]] || [ "$NUM_COMPUTE" -lt 1 ] || [ "$NUM_COMPUTE" -gt 20 ]; then
    print_error "Invalid input. Please enter a number between 1 and 20"
    exit 1
fi

print_success "You selected: $NUM_COMPUTE compute node(s)"
echo ""
sleep 2

# ==========================================
# STEP 0: Validate Prerequisites
# ==========================================
print_header "Step 0: Validating Prerequisites"
echo ""

print_info "Checking for required commands..."
for cmd in aws ansible-playbook; do
    if ! command -v $cmd &> /dev/null; then
        print_error "$cmd is not installed"
        exit 1
    fi
    print_success "$cmd found"
done

# ==========================================
# STEP 1: Setup SSH Key
# ==========================================
echo ""
print_header "Step 1: Setting up SSH Key"
echo ""

mkdir -p ~/.ssh

if [ -f "$KEY_FILE" ]; then
    print_success "SSH key file already exists at $KEY_FILE"
    chmod 600 "$KEY_FILE"
else
    print_info "SSH key file not found locally. Checking AWS..."
    
    if aws ec2 describe-key-pairs --region $REGION --key-names $KEY_NAME &>/dev/null; then
        print_info "Key '$KEY_NAME' exists in AWS but not locally."
        print_info "Deleting old key and creating new one..."
        aws ec2 delete-key-pair --region $REGION --key-name $KEY_NAME
        print_success "Old key deleted from AWS"
        sleep 2
    fi
    
    print_info "Creating new SSH key pair in AWS..."
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --region $REGION \
        --query 'KeyMaterial' \
        --output text > "$KEY_FILE"
    
    chmod 600 "$KEY_FILE"
    print_success "SSH key created successfully"
fi

check_success "SSH key setup"

# ==========================================
# STEP 2: Deploy AWS Infrastructure
# ==========================================
echo ""
print_header "Step 2: Deploying AWS Infrastructure"
echo ""
print_info "Creating VPC, Subnets, NAT Gateway..."
print_info "Launching 1 Login Node + 1 Controller + $NUM_COMPUTE Compute Node(s)..."
echo ""

ansible-playbook aws.yml -e "num_compute_nodes=$NUM_COMPUTE"
check_success "AWS infrastructure deployment"

echo ""
print_info "Waiting 60 seconds for instances to fully boot..."
sleep 60

# ==========================================
# STEP 3: Get Instance IPs
# ==========================================
echo ""
print_header "Step 3: Fetching Instance IPs"
echo ""

LOGIN_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:Name,Values=login" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

CONTROLLER_IP=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:Name,Values=controller" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

# Get all compute node IPs
COMPUTE_IPS=()
for i in $(seq 1 $NUM_COMPUTE); do
    IP=$(aws ec2 describe-instances \
        --region $REGION \
        --filters "Name=tag:Name,Values=compute$i" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
    COMPUTE_IPS+=("$IP")
done

if [ "$LOGIN_IP" == "None" ] || [ -z "$LOGIN_IP" ]; then
    print_error "Could not find login node IP"
    exit 1
fi

if [ "$CONTROLLER_IP" == "None" ] || [ -z "$CONTROLLER_IP" ]; then
    print_error "Could not find controller node IP"
    exit 1
fi

print_success "Instance IPs retrieved:"
echo "  Login (Public):       $LOGIN_IP"
echo "  Controller (Private): $CONTROLLER_IP"
for i in "${!COMPUTE_IPS[@]}"; do
    echo "  Compute$((i+1)) (Private):    ${COMPUTE_IPS[$i]}"
done

# ==========================================
# STEP 4: Setup SSH Access
# ==========================================
echo ""
print_header "Step 4: Setting up SSH Access"
echo ""

# Wait for SSH to be available
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$LOGIN_IP "echo 'SSH ready'" 2>/dev/null; then
        print_success "Login node SSH is ready"
        break
    fi
    print_info "Attempt $attempt/$max_attempts - waiting for SSH..."
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    print_error "SSH to login node timed out"
    exit 1
fi

# Copy key to login node
print_info "Copying SSH key to login node..."
scp -i $KEY_FILE -o StrictHostKeyChecking=no $KEY_FILE ubuntu@$LOGIN_IP:~/.ssh/ 2>/dev/null
check_success "SSH key copy"

# Set permissions
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ubuntu@$LOGIN_IP "chmod 600 ~/.ssh/${KEY_NAME}.pem"

# ==========================================
# STEP 5: Test Connectivity
# ==========================================
echo ""
print_header "Step 5: Testing Connectivity"
echo ""

ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@$LOGIN_IP -i $KEY_FILE" ubuntu@$CONTROLLER_IP "echo 'Controller reachable'" 2>/dev/null
check_success "Controller connectivity"

for i in "${!COMPUTE_IPS[@]}"; do
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@$LOGIN_IP -i $KEY_FILE" ubuntu@${COMPUTE_IPS[$i]} "echo 'Compute$((i+1)) reachable'" 2>/dev/null
    check_success "Compute$((i+1)) connectivity"
done

# ==========================================
# STEP 6: Create Ansible Inventory
# ==========================================
echo ""
print_header "Step 6: Creating Ansible Inventory"
echo ""

cat > hosts.ini << EOF
[slurm_login]
login ansible_host=$LOGIN_IP ansible_user=ubuntu

[slurm_controller]
controller ansible_host=$CONTROLLER_IP ansible_user=ubuntu

[slurm_compute]
EOF

for i in "${!COMPUTE_IPS[@]}"; do
    echo "compute$((i+1)) ansible_host=${COMPUTE_IPS[$i]} ansible_user=ubuntu" >> hosts.ini
done

cat >> hosts.ini << EOF

[all:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=$KEY_FILE
num_compute_nodes=$NUM_COMPUTE
EOF

# Add SSH proxy config for private nodes
cat >> hosts.ini << EOF

[slurm_controller:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@$LOGIN_IP -i $KEY_FILE"'

[slurm_compute:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -W %h:%p -q -o StrictHostKeyChecking=no ubuntu@$LOGIN_IP -i $KEY_FILE"'

[slurm_login:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF

print_success "Inventory file created"

# ==========================================
# STEP 7: Test Ansible Connectivity
# ==========================================
echo ""
print_header "Step 7: Testing Ansible Connectivity"
echo ""

ansible -i hosts.ini all -m ping
check_success "Ansible connectivity test"

# ==========================================
# STEP 8: Deploy Slurm
# ==========================================
echo ""
print_header "Step 8: Deploying Slurm Cluster"
echo ""
print_info "This will take 20-30 minutes..."
print_info "Progress:"
print_info "  1. Download packages"
print_info "  2. Install dependencies"
print_info "  3. Build Slurm from source"
print_info "  4. Configure services"
print_info "  5. Setup Login Node as Slurm client"
echo ""

ansible-playbook -i hosts.ini slurm_playbook.yml
check_success "Slurm deployment"

# ==========================================
# DEPLOYMENT COMPLETE
# ==========================================
echo ""
print_header "✓✓✓ DEPLOYMENT COMPLETE! ✓✓✓"
echo ""
echo -e "${GREEN}Your SLURM HPC Cluster is ready!${NC}"
echo ""
echo "Cluster Configuration:"
echo "======================"
echo "  • Login Node:    1"
echo "  • Controller:    1"
echo "  • Compute Nodes: $NUM_COMPUTE"
echo ""
echo "Access Information:"
echo "==================="
echo "  Login IP:    $LOGIN_IP"
echo "  SSH Key:     $KEY_FILE"
echo ""
echo "Connection:"
echo "==========="
echo "  ssh -i $KEY_FILE ubuntu@$LOGIN_IP"
echo ""
echo "Once logged in, test Slurm:"
echo "==========================="
echo "  sinfo              # View cluster status"
echo "  squeue             # View job queue"
echo "  srun hostname      # Run test job"
echo "  sbatch myscript.sh # Submit batch job"
echo ""

# Save connection info
cat > connection_info.txt << EOF
SLURM Cluster Connection Information
=====================================
Deployment Date: $(date)

Cluster Size:
-------------
Login Nodes:    1
Controller:     1
Compute Nodes:  $NUM_COMPUTE

IPs:
----
Login (Public):       $LOGIN_IP
Controller (Private): $CONTROLLER_IP
EOF

for i in "${!COMPUTE_IPS[@]}"; do
    echo "Compute$((i+1)) (Private):    ${COMPUTE_IPS[$i]}" >> connection_info.txt
done

cat >> connection_info.txt << EOF

SSH Key: $KEY_FILE

Connection Commands:
--------------------
# Access login node (as regular user)
ssh -i $KEY_FILE ubuntu@$LOGIN_IP

# Run Slurm commands
sinfo
squeue
srun -N1 hostname
sbatch job.sh

Cleanup:
--------
To destroy all resources:
./cleanup.sh
EOF

print_success "Connection info saved to connection_info.txt"
echo ""
