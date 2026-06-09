# 🚀 DevOps Mastery Playground: End-to-End AWS & LocalStack Infrastructure

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![LocalStack](https://img.shields.io/badge/Local-LocalStack-4c2c92?style=for-the-badge&logo=localstack&logoColor=white)](https://localstack.cloud/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-web-services&logoColor=white)](https://aws.amazon.com/)

A professional, production-grade DevOps showcase demonstrating the deployment of a full-stack application (Spring Boot & Angular) on AWS using modern Infrastructure as Code (IaC), automated CI/CD pipelines, containerization, and advanced CDN routing. 

This repository implements a **Local-First development paradigm**, leveraging **LocalStack** to fully simulate AWS environments (VPC, EC2, S3, IAM, Route53, CloudFront) locally before pushing to production AWS Cloud.

---

## 🗺️ System Architecture

The following diagram illustrates the complete system architecture, demonstrating how frontend and backend services are securely routed, hosted, and deployed:

![EC2 System Architecture](assets/architecture.png)

<details>
<summary>📊 Click to view detailed logical architecture (Mermaid Diagram)</summary>

```mermaid
graph TD
    Route53["🗺️ Route 53<br>ec2-stage.shlomi.com"] --> CF["☁️ Cloudfront"]
    
    CF -->|"/api/*"| ARecord["🔗 A-record (ec2-raw)"]
    CF -->|"*"| S3["🪣 Static files S3 Bucket"]
    
    ARecord --> AppServer
    
    subgraph EC2["💻 EC2 - server"]
        MySQL["🗄️ mysql<br>(Port 3306)"]
        AppServer["☕ appserver<br>(Port 8080)"]
        
        AppServer -->|JDBC Connection| MySQL
    end
    
    %% Exposing ports outside the boundary
    MySQL -.->|Exposed| Port3306["Port 3306"]
    AppServer -.->|Exposed| Port8080["Port 8080"]
```
</details>

---

## 🧠 Key Architectural & Engineering Decisions

While this setup may seem straightforward at first glance, the architecture implements several production-grade design patterns that demonstrate industry-standard DevOps and cloud architecture principles:

### 1. Unified Single-Entry Point (CORS & Security Optimization)
* **Problem**: Decoupled full-stack apps (frontend on S3 and API on EC2) usually require configuring Cross-Origin Resource Sharing (CORS) on the backend, introducing additional HTTP `OPTIONS` preflight request latency.
* **Solution**: By routing both the S3 frontend origin (`*`) and backend EC2 API origin (`/api/*`) through a single **AWS CloudFront** distribution, they share the exact same domain name (`ec2-stage.shlomi.com`). This completely eliminates CORS preflight latency and improves security by keeping the actual EC2 instance endpoint hidden from public browsers.

### 2. Edge Caching & Decoupled Static Hosting
* **Strategy**: Serving frontend Angular builds directly from **Amazon S3 website hosting** instead of the EC2 virtual machine.
* **Benefit**: Offloads all static web asset delivery (HTML, JS, CSS, images) to AWS's global edge network (CloudFront). The EC2 instance CPU/Memory is entirely dedicated to processing dynamic database queries and API business logic on port `8080`, vastly improving system scalability and reducing compute costs.

### 3. Database Isolation & Security Group Hardening
* **Implementation**: The MySQL database container is isolated within the internal Docker Compose bridge network on port `3306`.
* **Benefit**: It communicates directly with the Spring Boot container via high-speed internal DNS, with no port forwarding or direct public access exposed to the internet. Access to the EC2 API on port `8080` is restricted through CloudFront origins, preventing direct brute-force attacks on the VM.

### 4. High-Fidelity Local Development (Cloud Parity)
* **Philosophy**: Emulating Route 53 routing, ACM certificates, S3 bucket endpoints, and EC2 provisioning locally using **LocalStack**.
* **Benefit**: Enables testing full cloud infrastructure deployments locally in seconds. This eliminates standard cloud cost overhead during development, supports offline testing, and ensures 100% parity between local test environments and live AWS environments.

---

## 🌟 Key DevOps Engineering Pillars Demonstrated

1. **Infrastructure as Code (IaC)**: Fully automated infrastructure provisioning using **Terraform**, managing VPC, Subnets, Internet Gateways, Security Groups, IAM roles, S3 buckets, Route53, EC2, and CloudFront.
2. **Cloud Parity & Emulation**: Utilizes **LocalStack** and `tflocal` to run, test, and debug the entire AWS infrastructure locally, reducing cloud spend and shortening feedback loops.
3. **Containerization & Orchestration**: High-performance multi-container setup running via **Docker Compose**, separating the Java backend API and MySQL database.
4. **Automated CI/CD (GitHub Actions)**:
   - **Backend Pipeline**: Automatic compilation (Maven), Docker image building, publishing to Docker Hub, and zero-downtime deployment to AWS EC2 via SSH.
   - **Frontend Pipeline**: Automated compilation (Angular), deployment to S3 static hosting, and asset invalidation.
5. **Advanced Content Delivery & CDN Routing**: A single-entry point architecture using **AWS CloudFront** mapping:
   - `/api/*` requests dynamically forwarded to the Spring Boot REST API on EC2.
   - All other static assets served instantly via **Amazon S3** edge locations.
   - Custom domains and SSL certificates via **Route 53**, ACM, and GoDaddy nameserver integrations.

---

## 🤖 Built-in Automation Scripts

To streamline local development, infrastructure management, and deployments, the project includes pre-configured automation bash scripts under the `scripts/` directory:

### 1. Infrastructure Management (`scripts/infra.sh`)
Handles the complete lifecycle of your LocalStack environment and Terraform state.
* **Spin up local AWS mock environment**:
  ```bash
  ./scripts/infra.sh start
  ```
* **Teardown local mock environment**:
  ```bash
  ./scripts/infra.sh stop
  ```
* **SSH connection to mock EC2 (as root or testuser)**:
  ```bash
  ./scripts/infra.sh ssh       # Connect as testuser
  ./scripts/infra.sh ssh-root  # Connect as root
  ```
* **Create an encrypted SSH tunnel to forward port 5555**:
  ```bash
  ./scripts/infra.sh tunnel
  ```

### 2. Backend Orchestration (`scripts/build-run.sh`)
Builds the Spring Boot Java API, generates the Docker container image, and spins up the database and backend services using Docker Compose with a single command **inside the EC2 instance**:
```bash
# Run inside the EC2 container/machine after cloning the repo:
./scripts/build-run.sh
```

### 3. Local S3 Frontend Deployment (`scripts/deploy-frontend-local.sh`)
Automates building the Angular frontend and syncing the build artifacts to the local mock S3 bucket inside LocalStack:
```bash
./scripts/deploy-frontend-local.sh
```

---

## 📂 Project Structure

```directory
├── .github/
│   └── workflows/
│       └── build.yml      # GitHub Actions CI/CD for Backend Deployment
├── scripts/
│   ├── infra.sh           # LocalStack and Terraform management automation
│   ├── build-run.sh       # Compiles, builds Docker image, starts compose
│   └── deploy-frontend-local.sh  # Deploys Angular frontend to S3 locally
├── src/                   # Spring Boot Application source code
├── Dockerfile             # Docker recipe for Java API compilation and execution
├── docker-compose.yml     # Compose file defining server & database services
├── ec2.tf                 # VPC, Security Groups, EC2 instance, testuser automation
├── s3.tf                  # Static S3 bucket configuration, public read policy
├── iam.tf                 # IAM User and policies for static deployment
├── cloudfront.tf          # Route53 zones/records, ACM, CloudFront distribution routing
├── pom.xml                # Maven project definition
└── README.md              # This README
```

---

## 💻 Local Emulation & Development (LocalStack)

This project is built to run 100% locally using LocalStack.

### 1. Prerequisites
Ensure you have the following installed and configured on your machine (WSL / Local PC):
* Docker & Docker Compose
* LocalStack CLI (`pip install localstack`)
* Python Virtual Environment with LocalStack helper wrappers (`tflocal` and `awslocal`):
  ```bash
  python3 -m venv ~/venv 
  source ~/venv/bin/activate
  python3 -m pip install terraform-local awscli-local
  ```
* **Verify Local wrappers installation**:
  ```bash
  tflocal --version
  awslocal --version
  ```
* **Host SSH Key (Required for mock EC2 GitHub cloning)**: A valid SSH key pair (preferably `~/.ssh/id_ed25519`) must exist on your host machine and be added to your GitHub account *before* provisioning.

### 2. Generate SSH Key on Host (WSL / Local PC)
Before launching the infrastructure, you must ensure you have an SSH key generated on your host machine so that Terraform can copy it to the container. If you do not have one, run:
```bash
# Generate the key pair on your host machine (WSL or Local PC)
ssh-keygen -t ed25519 -C "[EMAIL_ADDRESS]"

# View and copy the public key
cat ~/.ssh/id_ed25519.pub

# Add the public key to your GitHub account:
# Go to Settings -> SSH and GPG keys -> New SSH key, and paste the output.
```

### 3. Launch LocalStack
Start the local AWS cloud engine in the background:
```bash
localstack start -d
```

### 4. Provision Infrastructure Locally
Use `tflocal` to initialize and deploy the infrastructure to your local mock environment:
```bash
tflocal init
tflocal apply -auto-approve
```
> [!NOTE]
> Standard Terraform outputs the generated private SSH key (`ec2_key_pair.pem`) to the local directory with `0400` read-only permissions automatically.
> To destroy the local mock environment later, run:
> ```bash
> tflocal destroy -auto-approve
> ```

### 5. Connect to Local Mock EC2
To log into the simulated Ubuntu machine created inside LocalStack:
```bash
# Secure the key
sudo cp ec2_key_pair.pem ~
sudo chmod 400 ~/ec2_key_pair.pem

# SSH into the containerized machine
ssh -i ~/ec2_key_pair.pem testuser@localhost
# Or as root:
ssh -i ~/ec2_key_pair.pem root@localhost
```

### 6. Verify Tool Installations (Verification)
Run the following commands inside the EC2 instance to ensure all tools have been provisioned correctly:
```bash
docker --version
docker-compose --version
git --version
python3 --version
mvn -version
yq --version
```

### 7. GitHub Authentication & Project Setup (Inside EC2)
Once logged into the EC2 instance and verified, you need to clone your repository to build and deploy the application.

1. **Verify SSH Key and Connection**:
   * **For Local Emulation (LocalStack)**:
     Since the Terraform `copy_ssh_keys` resource automatically copied your host's existing key into the mock EC2 container during step 4, you can verify it and test your connection to GitHub directly:
     ```bash
     ls -la ~/.ssh/
     ssh -T git@github.com
     ```
   * **For Production AWS EC2 (Real Cloud)**:
     If you are deploying on a real AWS cloud instance without automated copy, generate the key pair inside the EC2 instance and register it with GitHub:
     ```bash
     ssh-keygen -t ed25519 -C "shlomi.sharbet@gmail.com"
     cat ~/.ssh/id_ed25519.pub
     # Add the output to GitHub Settings -> SSH and GPG keys.
     ```

2. **Clone and Configure**:
   Clone the repository and set up your git configurations:
   ```bash
   git clone git@github.com:shlomi-sharbet/dops-basic-spring-ec2-back.git
   cd dops-basic-spring-ec2-back
   git config --global user.email "shlomi.sharbet@gmail.com"
   ```

---

## 🐳 Application Containerization (Docker Setup)

This phase compiles the Java Backend and orchestrates the containers. You can either use the automated script or run the steps manually inside the EC2 instance.

### Option A: Automated Build & Run (Recommended)
Expose execute permissions and run the orchestration script inside the `dops-basic-spring-ec2-back` directory:
```bash
chmod +x ./scripts/build-run.sh
./scripts/build-run.sh
```

### Option B: Manual Steps
If you prefer running commands individually, follow these steps:

#### 1. Maven Compilation
Build the production Spring Boot JAR file:
```bash
mvn clean install
# Verifies that basic-0.0.1-SNAPSHOT.jar is generated under /target
```

### 2. Manual Docker Build & Publish
```bash
# Login to your registry
# create token: https://app.docker.com/accounts/shlomisharbat/settings/personal-access-tokens
docker login -u <DOCKERHUB_USERNAME>

# Build the API image
docker build . -t backend

# Tag and push
docker tag backend <DOCKERHUB_USERNAME>/backend:latest
docker push <DOCKERHUB_USERNAME>/backend:latest
```

### 3. Run Multi-Container Services
Run the Spring Boot Backend alongside a MySQL database inside the EC2 environment:
```bash
docker-compose up -d
```
* **Swagger API Documentation UI**: Accessible at `http://localhost:8080/swagger-ui.html`
* **MySQL Database**: Running on port `3306` inside the isolated network.

---

## 🐙 CI/CD Pipelines (GitHub Actions)

### 1. Backend CI/CD Workflow (`.github/workflows/build.yml`)
Triggers on every push to the `master` branch:
1. **Build**: Compiles and packages the Java code using Maven with JDK 11.
2. **Dockerize**: Builds the Docker image with a dynamic version tag: `v1.0.${{ github.run_number }}`.
3. **Registry Push**: Uploads the image to Docker Hub.
4. **AWS Deployment (CD)**: Connects securely via SSH to the AWS EC2 instance, updates the image tag in `docker-compose.yml`, pulls the latest build, and performs a graceful container restart (`docker-compose down && docker-compose up -d`).

### 2. Frontend CI/CD Workflow (Angular Deploy to S3)
Triggers on every push to the `main` branch of the frontend repository:
1. **Compilation**: Installs Node dependencies and builds the optimized Angular production bundle (`npm run build --prod`).
2. **S3 Synchronization**: Uses the AWS CLI to sync assets to S3 and purge deleted files:
   ```bash
   aws s3 sync ./dist/webapp s3://${{ env.S3_BUCKET_NAME }} --delete
   ```

### 3. Self-Hosted GitHub Actions Runner
To build and deploy both the backend and frontend applications, the workflows utilize a **Self-Hosted Runner** (`runs-on: self-hosted`). This ensures that the builds execute directly on the target host/runner environment (e.g., your local workspace or deployment server), allowing secure, local build execution and integration.

To start the registered self-hosted runner:
```bash
# Navigate to the runner installation directory and start the agent
cd ~/actions-runner   # (e.g., /home/shlomi/actions-runner)
./run.sh
```

### 4. Configuring Repository Secrets
To run these automated pipelines, configure the following secrets in GitHub under `Settings -> Secrets and variables -> Actions`:

| Secret Name | Description | Example / Mock Value |
| :--- | :--- | :--- |
| `DOCKERHUB_USERNAME` | Your Docker Hub account | `shlomisharbat` |
| `DOCKERHUB_TOKEN` | Personal Access Token from Docker Hub | `dckr_pat_...` |
| `EC2_INSTANCE_PUBLIC_IP` | Public IP of your EC2 Web Server | `13.50.xxx.xxx` (or `localhost` for local testing) |
| `SSH_KEY` | Content of `ec2_key_pair.pem` Private Key | `-----BEGIN RSA PRIVATE KEY----- ...` |
| `AWS_ACCESS_KEY_ID` | Access key of deployer IAM user | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | Secret key of deployer IAM user | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYzEXAMPLEKEY` |
| `AWS_REGION` | AWS target deployment region | `us-east-1` |
| `S3_BUCKET_NAME` | S3 static hosting bucket name | `shlomi.backend.students` |

---

## ⚡ Professional Tips & Techniques

### Pro-Tip: Secure Local Port Access via SSH Tunneling
When testing endpoints inside a remote EC2 server with closed ports, **do not open ports to the entire internet** in your Security Group! Instead, use **SSH Port Forwarding (Tunneling)**. 

Establish a secure encrypted tunnel that routes local port `5555` directly to port `5555` inside the EC2 instance over port 22:
```bash
ssh -i ~/ec2_key_pair.pem -L 5555:localhost:5555 root@localhost
```
Now, if you launch a test web server on the remote instance (e.g., `python3 -m http.server 5555`), you can access it securely from your local browser at `http://localhost:5555`!

---

## ⚙️ Advanced Production Configuration: Routing & Domain Setup (IaC)

This advanced routing and CDN setup is **fully automated as Infrastructure as Code (IaC)** inside [cloudfront.tf](cloudfront.tf). When you run `tflocal apply` or `terraform apply`, Terraform provisions and configures the following resources automatically:

1. **Route 53 Hosted Zone** (`aws_route53_zone`): Manages the DNS zone for `shlomi.com` and registers DNS records (e.g., pointing domain registrar nameservers to AWS Route 53).
2. **ACM Certificate** (`aws_acm_certificate`): Automates requesting a wildcard SSL/TLS Certificate (`*.shlomi.com`) to allow secure HTTPS communication.
3. **CloudFront CDN Distribution** (`aws_cloudfront_distribution`): Provisions a global CDN at `ec2-stage.shlomi.com` mapping:
   - **S3 Frontend Origin**: Points to the S3 bucket static website endpoint.
   - **EC2 Backend Origin**: Points to the API Backend CNAME (`ec2-raw.shlomi.com`) on port `8080`.
   - **Cache Behaviors**:
     - Path pattern `/api/*` routes requests dynamically to the EC2 backend.
     - Default path pattern `*` serves static web assets directly from the S3 bucket.
4. **DNS Records** (`aws_route53_record`): Maps `ec2-raw.shlomi.com` to the EC2 host and `ec2-stage.shlomi.com` directly to the CloudFront distribution domain.

