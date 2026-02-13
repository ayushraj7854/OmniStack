# 🚀 Automated Slurm HPC Cluster on AWS

[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20VPC-orange?logo=amazon-aws)](https://aws.amazon.com/)
[![Ansible](https://img.shields.io/badge/Ansible-Automated-red?logo=ansible)](https://www.ansible.com/)
[![Slurm](https://img.shields.io/badge/Slurm-HPC-blue)](https://slurm.schedmd.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **Fully automated deployment of a production-grade High Performance Computing (HPC) cluster on AWS using Ansible, complete with real-time monitoring via Prometheus and Grafana.**

This project provides a complete Infrastructure-as-Code (IaC) solution for deploying a Slurm-based HPC cluster following real-world cloud HPC architecture patterns. Perfect for learning, research, and production workloads.

---

## 📋 Table of Contents

- [Architecture](#-architecture-overview)
- [Features](#-key-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Usage](#-usage)
- [Monitoring](#-monitoring)
- [Project Structure](#-project-structure)
- [Cleanup](#-cleanup)
- [Tech Stack](#-tech-stack)
- [Use Cases](#-ideal-for)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

---

## 🏗 Architecture Overview

```
User
  │
  └─► Login Node (SSH Gateway)
        │
        └─► Slurm Controller (Scheduler + Prometheus)
              │
              ├─► Compute Node 1 (Worker + Node Exporter)
              ├─► Compute Node 2 (Worker + Node Exporter)
              └─► Compute Node N (Worker + Node Exporter)

Monitoring Flow:
Compute Nodes → Node Exporters → Prometheus → Grafana Dashboard
```

### Components

| Component | Role | Details |
|-----------|------|---------|
| **Login Node** | SSH gateway | Public-facing access point for users |
| **Slurm Controller** | Job scheduler | Manages job queue, resource allocation, and monitoring |
| **Compute Nodes** | Workers | Execute HPC workloads, scalable to N nodes |
| **Prometheus** | Metrics collection | Scrapes metrics from all nodes |
| **Grafana** | Visualization | Real-time dashboard for cluster monitoring |

---

## ✨ Key Features

- ✅ **One-Command Deployment** - Complete cluster setup in minutes
- ✅ **Production-Ready Architecture** - Multi-tier design with dedicated roles
- ✅ **Fully Automated** - Minimal manual configuration required
- ✅ **Real-Time Monitoring** - Prometheus + Grafana dashboard included
- ✅ **Secure by Design** - Proper VPC, security groups, and SSH key management
- ✅ **Scalable** - Easy to add/remove compute nodes
- ✅ **Cost-Effective** - Uses spot instances (configurable)
- ✅ **Clean Teardown** - One-command cleanup of all AWS resources

---

## 📦 Prerequisites

### ☁️ AWS Requirements

- **AWS Account** with active subscription
- **IAM User** with EC2 permissions
- **EC2 Key Pair** (`.pem` file)
- **Ubuntu AMI ID** for your region ([Find AMI](https://cloud-images.ubuntu.com/locator/ec2/))

### 💻 Local Machine Setup

#### Recommended OS
**Kali Linux** (or any Debian/Ubuntu-based distribution, WSL2, or macOS)

#### Required Software

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y ansible awscli python3-boto3 python3-botocore openssh-server

# Enable SSH (if not already running)
sudo apt install openssh-server -y
sudo systemctl start ssh
sudo systemctl enable ssh
```

---

## 🚀 Quick Start

### 1️⃣ AWS Setup

#### Create IAM Access Key

1. Go to **AWS Console** → **IAM** → **Users** → Select your user
2. Navigate to **Security credentials** tab
3. Click **Create access key**
4. Choose: **Command Line Interface (CLI)**
5. Save your credentials:
   ```
   Access Key ID:     AKIA****************
   Secret Access Key: ****************************************
   ```
   ⚠️ **Important**: Secret key is shown only once - save it securely!

#### Configure AWS CLI

```bash
aws configure
```

Enter your credentials:
```
AWS Access Key ID [None]: AKIA****************
AWS Secret Access Key [None]: ****************************************
Default region name [None]: ap-south-1
Default output format [None]: json
```

Common AWS regions:
- `us-east-1` (N. Virginia)
- `us-west-2` (Oregon)
- `ap-south-1` (Mumbai)
- `eu-west-1` (Ireland)

### 2️⃣ SSH Key Setup

#### Download PEM File from AWS

1. **AWS Console** → **EC2** → **Key Pairs**
2. Create new key pair or download existing one
3. Save as `mykey.pem`

#### Configure PEM File

```bash
# Move to SSH directory
mv ~/Downloads/mykey.pem ~/.ssh/

# Set correct permissions (CRITICAL)
chmod 400 ~/.ssh/mykey.pem

# Verify key works
ssh -i ~/.ssh/mykey.pem ubuntu@ec2-instance-ip
```

✅ If login succeeds, you're ready to proceed!

### 3️⃣ Clone Repository

```bash
git clone https://github.com/vishwagawai/aws-hpc-cluster.git
cd aws-hpc-cluster
```

---

## ⚙️ Installation

### Configure Deployment Variables

Edit **only these 3 values** in `group_vars/all.yml` or `aws.yml`:

```yaml
# AWS Configuration
ami_id: "ami-0dee22c13ea7a9a67"        # Your Ubuntu AMI ID
key_name: "mykey"                       # Your PEM key name (without .pem)
region: "ap-south-1"                    # Your AWS region
```

> 💡 **Tip**: Find your AMI ID at [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/locator/ec2/)

**That's it!** No other configuration needed.

---

## 🎯 Usage

### Deploy Complete HPC Cluster

```bash
bash deploy.sh
```

**This script automatically:**
1. ✔️ Creates VPC, subnets, and security groups
2. ✔️ Launches login node, controller, and compute nodes
3. ✔️ Installs and configures Slurm
4. ✔️ Sets up Munge authentication
5. ✔️ Configures cluster networking

**Expected time**: 5-10 minutes

### Fix Networking for Monitoring

```bash
ansible-playbook -i hosts.ini fix.yml
```

Ensures Prometheus can communicate with all cluster nodes.

### Deploy Monitoring Stack

```bash
bash deploy_monitoring.sh
```

**Installs:**
- ✔️ Prometheus on controller
- ✔️ Node Exporter on all nodes
- ✔️ Grafana dashboard

---

## 📊 Monitoring

### Access Dashboards

Create an SSH tunnel to access monitoring interfaces:

```bash
ssh -i ~/.ssh/mykey.pem \
    -L 3000:<controller-private-ip>:3000 \
    -L 9090:<controller-private-ip>:9090 \
    ubuntu@<login-node-public-ip>
```

**Replace:**
- `<controller-private-ip>`: Private IP of controller node (from AWS console)
- `<login-node-public-ip>`: Public IP of login node (from AWS console)

### Open Dashboards

| Service | URL | Credentials |
|---------|-----|-------------|
| **Grafana** | http://localhost:3000 | `admin` / `admin` |
| **Prometheus** | http://localhost:9090 | No authentication |

### Grafana Setup

1. First login will prompt password change
2. Navigate to **Dashboards** → **Browse**
3. Pre-configured dashboard shows:
   - CPU usage per node
   - Memory utilization
   - Network I/O
   - Job queue status
   - Node health

---

## 💼 Using the HPC Cluster

### Login to Cluster

```bash
ssh -i ~/.ssh/mykey.pem ubuntu@<login-node-public-ip>
```

### Submit a Job

Create a job script `test_job.sh`:

```bash
#!/bin/bash
#SBATCH --job-name=test_job
#SBATCH --output=result_%j.txt
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
#SBATCH --partition=compute

echo "Hello from HPC cluster!"
hostname
date
sleep 30
```

Submit the job:

```bash
sbatch test_job.sh
```

### Monitor Jobs

```bash
# View job queue
squeue

# View cluster status
sinfo

# View detailed job info
scontrol show job <job_id>

# Cancel a job
scancel <job_id>
```

### Check Job Output

```bash
cat result_<job_id>.txt
```

---

## 📁 Project Structure

```
RealFinal/
│
├── aws.yml                      # AWS infrastructure playbook
├── slurm_playbook.yml           # Slurm installation playbook
├── setup_monitoring.yml         # Monitoring setup playbook
├── fix.yml                      # Network fixes for monitoring
├── deploy.sh                    # Main deployment script
├── deploy_monitoring.sh         # Monitoring deployment script
├── cleanup.sh                   # AWS resource cleanup script
├── README.md                    # This file
│
├── group_vars/
│   └── all.yml                  # Global configuration variables
│
└── templates/
    ├── slurm.conf.j2            # Slurm configuration template
    └── slurmdbd.conf.j2         # Slurm database configuration template
```

---

## 🧹 Cleanup

### Remove All AWS Resources

When you're done with the cluster:

```bash
bash cleanup.sh
```

**This safely removes:**
- ✔️ All EC2 instances
- ✔️ Security groups
- ✔️ VPC and subnets
- ✔️ Internet gateways
- ✔️ Route tables

⚠️ **Warning**: This action is irreversible. Ensure you've backed up any important data.

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| **AWS EC2** | Virtual machine hosting |
| **AWS VPC** | Network isolation and security |
| **Ansible** | Infrastructure automation |
| **Slurm Workload Manager** | Job scheduling and resource management |
| **Prometheus** | Metrics collection and alerting |
| **Grafana** | Monitoring dashboards |
| **Ubuntu 22.04 LTS** | Operating system |
| **Munge** | Authentication service |

---

## 🎯 Ideal For

- 🎓 **Educational Labs** - Learn HPC concepts hands-on
- 🔬 **Research Computing** - Academic and scientific workloads
- 💼 **Portfolio Projects** - Demonstrate cloud/DevOps skills
- 🏢 **Prototyping** - Test HPC applications before production
- 📚 **Training** - CDAC/HPCSA certification practicals
- 🚀 **Development** - Build and test parallel computing applications

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: "Permission denied (publickey)"

**Solution:**
```bash
# Verify key permissions
ls -la ~/.ssh/mykey.pem
# Should show: -r-------- (400)

# Fix if needed
chmod 400 ~/.ssh/mykey.pem
```

#### Issue: "boto3 module not found"

**Solution:**
```bash
# Install system-wide (recommended for Kali/Debian)
sudo apt install -y python3-boto3 python3-botocore
```

#### Issue: "Invalid AMI ID"

**Solution:**
- Ensure AMI ID is for your selected region
- Find correct AMI: https://cloud-images.ubuntu.com/locator/ec2/
- Update `ami_id` in `group_vars/all.yml`

#### Issue: Nodes not appearing in Prometheus

**Solution:**
```bash
# Run the fix playbook
ansible-playbook -i hosts.ini fix.yml

# Verify connectivity from controller
ssh controller
curl http://<compute-node-ip>:9100/metrics
```

#### Issue: Cannot access Grafana

**Solution:**
```bash
# Verify SSH tunnel is active
ps aux | grep ssh

# Restart tunnel with correct IPs
ssh -i ~/.ssh/mykey.pem \
    -L 3000:<controller-private-ip>:3000 \
    -L 9090:<controller-private-ip>:9090 \
    ubuntu@<login-node-public-ip>
```

### Getting Help

If you encounter issues:

1. Check AWS Console for instance status
2. Review Ansible output for error messages
3. Verify security group rules allow required ports
4. Check `/var/log/slurm/` on controller for Slurm logs
5. Open an issue on GitHub with detailed error messages

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Areas for Contribution

- Additional monitoring dashboards
- Support for other cloud providers (Azure, GCP)
- Enhanced security configurations
- Cost optimization features
- Documentation improvements
- Bug fixes and testing

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Slurm Workload Manager](https://slurm.schedmd.com/) - HPC job scheduling
- [Ansible](https://www.ansible.com/) - Automation framework
- [Prometheus](https://prometheus.io/) - Monitoring system
- [Grafana](https://grafana.com/) - Visualization platform

---

## 📞 Support

- 📧 **Email**: vishwagawai37@gmail.com
- 🐛 **Issues**: [GitHub Issues](https://github.com/vishwagawai/aws-hpc-cluster/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/vishwagawai/aws-hpc-cluster/discussions)

---

## 🌟 Star History

If you find this project useful, please consider giving it a ⭐!

---

## 👤 Author

**Vishwa Gawai**
- Email: vishugawai37@gmail.com
- GitHub: [@vishwagawai](https://github.com/vishwagawai)

---

<div align="center">

**Made with ❤️ for the HPC Community**

[Report Bug](https://github.com/vishwagawai/aws-hpc-cluster/issues) · [Request Feature](https://github.com/vishwagawai/aws-hpc-cluster/issues) · [Documentation](https://github.com/vishwagawai/aws-hpc-cluster/wiki)

</div>
=======
# aws-hpc-cluster
Automated Slurm HPC Cluster Deployment on AWS with Monitoring
