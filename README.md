


<img width="1251" height="540" alt="Screenshot 2026-01-01 at 6 11 52 PM" src="https://github.com/user-attachments/assets/872e255f-7622-42e9-b048-5351272fbf7b" />

# Hands-on Project: Implementation - Part 1
This architecture will be implemented in 3 parts as follows:

### **Part 01 - Containerization and Image Delivery with Docker + ECR**

In this step, you will package the **HumanGov** application and the **Webserver** (Nginx) in a Docker image and push the images to the **Amazon Elastic Container Registry (ECR)**.

This includes

- Creating the Dockerfile with the application's dependencies;
- Building and testing the image locally;
- ECR authentication and secure image upload to the AWS repository.

***The aim is to ensure that the application is ready to be run in a containerized environment and stored securely in the cloud repository.***

---

### **Part 02 - Provisioning Resources with Terraform**

With the image already published in ECR, you will use **Terraform** to provision the AWS resources that make up the application's infrastructure:

- **S3 buckets** for data storage;
- **DynamoDB tables** for persisting records;
- And we'll also create an ECS Cluster!

***This step ensures the consistency of the infrastructure, with automated, versioned and replicable provisioning.***

---

### **Part 03 - Manual Deployment with ECS: Creating Task Definitions and Services**

In this last phase, you will manually create the **Task Definition** in ECS, pointing to the ECR image, and deploy the application via an **ECS service**.

This involves

- Configuring the task's network type and resource allocation;
- Associating the container image published on the ECR;
- Launching the ECS service and checking that the application is working per tenant.

***This step demonstrates the manual deployment flow, highlighting the complexity and importance of automation in future projects.***

---

# Prerequisites

- Cleaning up the environment:
    
    ```bash
    ls
    rm -rf hands-on-tasks-terraform
    rm -rf terraform-module-ec2
    rm -rf terraform-provisioners-example
    rm -rf terraform-remote-state-example
    rm -rf local-repo
    rm -rf local-repo2
    rm -rf ansible-tasks
    ```
    
    <aside>
    💡
    
    To delete **only the visible** (not hidden) **folders** and **keep only** **`human-gov-application`** and **`human-gov-infrastructure`**, use the following command:
    
    ```bash
    find . -maxdepth 1 -type d ! -name '.' ! -name 'human-gov-application' ! -name 'human-gov-infrastructure' ! -name '.*' -exec rm -rf {} +
    ```
    
    - `type d`: searches only directories.
    - `maxdepth 1`: restricts the search to the current directory (no subfolders).
    - `!-name '.*'`: **ignores hidden directories** (such as `.git`, `.vscode`, etc.).
    - `! -name 'human-gov-application' ! -name 'human-gov-infrastructure'`: **preserves** only these two folders.
    - `exec rm -rf {} +`: deletes the other directories found.
    
    ---
    
    ### Security tip:
    
    Before executing, preview what will be deleted with:
    
    ```bash
    find . -maxdepth 1 -type d ! -name '.' ! -name 'human-gov-application' ! -name 'human-gov-infrastructure' ! -name '.*' -exec echo {} +
    ```
    
    </aside>
    

- Create **IAM Role** for Tasks Execution:
    
    <aside>
    💡
    
    Just as we created **IAM Roles** to allow **EC2** instances to perform actions on **DynamoDB tables** and **S3 buckets**, we also need to define a **specific IAM Role for the ECS Cluster**. This role is essential so that ECS is allowed to **execute the** application's **tasks** with security and proper access control.
    
    </aside>
    
    **IAM | Roles**
    
    - **AWS service**
    - **Service or use case: `Elastic Container Service`**
    - **Chose a use case for the specific service | Use case: `Elastic Container Service Task`**
    - **Permissions:**
        - **`AmazonS3FullAccess`**
        - **`AmazonDynamoDBFullAccess`**
        - **`AmazonECSTaskExecutionRolePolicy`**
    - **Name: `HumanGovECSExecutionRole`**
        
        ***Create Role***
        

# Part 01 - Build & Push Image: Docker & ECR

## Step 01 - Create Application 'Dockerfile' File

```bash
cd human-gov-application/src && touch Dockerfile
```

📄 `Dockerfile`

```docker
# Use Python as the base image
FROM python:3.8-slim-buster

# Set the working directory
WORKDIR /app

# Copy requirements file and install dependencies
# `--no-cache-dir` prevents pip from saving temporary files, keeping the environment lightweight.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Flask application files
COPY . /app

# Start Gunicorn server
# Start Flask application using Gunicorn with 1 worker, binding to all network interfaces on port 8000
CMD ["gunicorn", "--workers", "1", "--bind", "0.0.0.0:8000", "humangov:app"]
```

<aside>
💡

**`humangov:app`**

Open the file [**`humangov.py`**](http://humangov.py) and check the name of the main function → # Flask "app = Flask (**name**)"

</aside>

## Step 02 - Creating the Application Repository in ECR

<img width="466" height="226" alt="Screenshot 2026-01-01 at 6 14 22 PM" src="https://github.com/user-attachments/assets/edb0e47d-0177-4162-b0a3-d9265aaa77bd" />


- **Repository Name**: **`humangov-app`**
    
    **Create**
    

## Step 03 - Configuring the Repository, Creating an Image and Making a Push

- Select the repository and click on: **`View push commands`**
- Execute the commands shown.

<aside>
💡

Error: **docker: command not found**

```bash
sudo yum install -y docker
docker ps
sudo systemctl status docker
sudo systemctl start docker
sudo systemctl status docker
'q' to 'quit'

docker ps
connect: permission denied

sudo usermod -aG docker $USER
newgrp docker
docker ps
```

</aside>

**Validate the upload of the HumanGov application image in ECR!**

## Step 04 - Creating the Webserver Files

```bash
cd ..
pwd # /home/ec2-user/human-gov-application

mkdir nginx && touch nginx.conf proxy_params Dockerfile
```

📄 `nginx.conf` 

```bash
server {
    listen 80;
    server_name humangov www.humangov;

    location / {
        include proxy_params;
        proxy_pass http://localhost:8000; 
    }
}
```

<aside>
💡

**"Remember we didn't use the 'default' Nginx configuration file?"**

This file configures the **NGINX server** to:

- Listen on port **80**;
- Respond to the `humangov` and `www.humangov` domains;
- Redirect requests to the Flask backend running on `localhost:8000` via **proxy**.
</aside>

📄 `proxy_params`

```bash
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

<aside>
💡

Defines **HTTP headers** that will be passed to the backend, such as:

- `Host`: keeps the original host name;
- `X-Real-IP`: passes the client's real IP;
- `X-Forwarded-For`: registers the chain of IPs in proxies.
</aside>

<aside>
💡

These files make NGINX work like a **reverse proxy**, passing on requests to the Flask application and keeping important client information.

</aside>

A **reverse proxy** receives requests from the client and **redirects** them **to an internal server**, such as a backend application. It hides the real server and can balance load, add security and cache.

📄 `Dockerfile`

```docker
# Use the NGINX Alpine image as the base
FROM nginx:alpine

# Remove the default NGINX configuration file
RUN rm /etc/nginx/conf.d/default.conf

# Copy the custom NGINX configuration file
COPY nginx.conf /etc/nginx/conf.d

# Copy the proxy parameters file
COPY proxy_params /etc/nginx/proxy_params

# Expose port 80
EXPOSE 80

# Start NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]
```

<aside>
💡

**CMD ["nginx", "-g", "daemon off;"]**

**Starts NGINX in the foreground**, without running as a daemon (background service). This is important in containers, because the main process needs to **be active** for the container not to terminate automatically.

</aside>

## Step 05 - Creating the Webserver Repository in ECR
<img width="466" height="226" alt="Screenshot 2026-01-01 at 6 14 22 PM" src="https://github.com/user-attachments/assets/cd295db3-c95d-46bd-83b7-77561a2f60d5" />



- **Repository Name**: **`humangov-nginx`**
    
    **Create**
    

## Step 06 - Configuring the Repository, Creating an Image and Making a Push

- Select the repository and click on: **`View push commands`**
- Execute the commands shown.

**Validate the upload of the Nginx Webserver image in ECR!**

Part 02 - Provisioning Resources with Terraform

In this phase, we use Terraform to provision the AWS resources that make up the HumanGov application infrastructure:

🪣 S3 Buckets – application data storage

🗄️ DynamoDB Tables – persistent records

☁️ ECS Cluster – container orchestration

This step ensures consistent, versioned, and repeatable infrastructure provisioning.




# **Part 02 - Provisioning with Terraform**

We're going to use **Terraform** to provision the AWS resources that make up the application's infrastructure:

- **S3 buckets** for data storage;
- **DynamoDB tables** for persisting records;
- And we'll also create an ECS Cluster!

***This step ensures the consistency of the infrastructure, with automated, versioned and replicable provisioning.***

# **Attention: we're going to create an ECS Cluster with AWS Fargate ($)**

💡 Note that AWS Fargate doesn't have a free tier at the moment, so this practical project will generate a small cost of a few cents. 
**We recommend that you only start the second part of this project when you have enough time to complete both part 2 and part 3, in order to avoid leaving the ECS cluster running for too long.** 

**Don't forget to delete the cluster as soon as you've finished the practical project!** 

And remember: **don't think of it as a cost to yourself, but as an investment in yourself and your career!** 

***It will pay off! 🚀***

---

## Step 01 - Checking Terraform Remote State`(terraform.tfstate`)

```bash
cd /home/ec2-user/human-gov-infrastructure/terraform

# This command can take a while, do not worry :)
**terraform** show    # The state file is empty. No resources are represented.
```

## Step 02 - Adjusting the Terraform Codes

<aside>
💡

We won't be deploying **EC2** instances, as the current premise of the **HumanGov** project is to use a **container-based** architecture **with AWS ECS and Fargate**.

However, we still need to **maintain the creation of the DynamoDB and S3 resources**, which are fundamental to the functioning of the application.

To do this, we need to **adjust the following files** in the Terraform project:

- `modules/aws_humangov_infrastructure/main.tf`
- `modules/aws_humangov_infrastructure/output.tf`
- `terraform/outputs.tf`

The following file is already commented out, indicating **which resources will no longer be created** in this Fargate scenario.

</aside>

📄 `modules/aws_humangov_infrastructure/main.tf`

```hcl
/*
resource "aws_security_group" "state_ec2_sg" {
    name = "humangov-${var.state_name}-ec2-sg"
    description = "Permitir tráfego nas portas 22 e 80"

      ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

      ingress {
        from_port   = 5000
        to_port     = 5000
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

      ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        security_groups = ["sg-027f57abd3fefda49"]
      }

      egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }

    tags = {
        Name = "humangov-${var.state_name}"
    }
}

resource "aws_instance" "state_ec2" {
    ami = "ami-007855ac798b5175e"
    instance_type = "t2.micro"
    key_name = "humangov-ec2-key"
    vpc_security_group_ids = [aws_security_group.state_ec2_sg.id]
    iam_instance_profile = aws_iam_instance_profile.s3_dynamodb_full_access_instance_profile.name

    provisioner "local-exec" {
  	  command = "sleep 30; ssh-keyscan ${self.private_ip} >> ~/.ssh/known_hosts"
  	}

  	provisioner "local-exec" {
  	  command = "echo ${var.state_name} id=${self.id} ansible_host=${self.private_ip} ansible_user=ubuntu us_state=${var.state_name} aws_region=${var.region} aws_s3_bucket=${aws_s3_bucket.state_s3.bucket} aws_dynamodb_table=${aws_dynamodb_table.state_dynamodb.name} >> /etc/ansible/hosts"
  	}

  	provisioner "local-exec" {
  	  command = "sed -i '/${self.id}/d' /etc/ansible/hosts"
  	  when = destroy
  	}

    tags = {
        Name = "humangov-${var.state_name}"
    }
}
*/

resource "aws_dynamodb_table" "state_dynamodb" {
    name = "humangov-${var.state_name}-dynamodb"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
        name = "id"
        type = "S"
    }

    tags = {
        Name = "humangov-${var.state_name}"
    }
}

resource "random_string" "bucket_suffix" {
    length = 4
    special = false
    upper = false
}

resource "aws_s3_bucket" "state_s3" {
    bucket = "humangov-${var.state_name}-s3-${random_string.bucket_suffix.result}"

    tags = {
        Name = "humangov-${var.state_name}"
    }
}

/*
resource "aws_iam_role" "s3_dynamodb_full_access_role" {
  name = "humangov-${var.state_name}-s3_dynamodb_full_access_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
        Name = "humangov-${var.state_name}"
  }

}

resource "aws_iam_role_policy_attachment" "s3_full_access_role_policy_attachment" {
  role       = aws_iam_role.s3_dynamodb_full_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"

}

resource "aws_iam_role_policy_attachment" "dynamodb_full_access_role_policy_attachment" {
  role       = aws_iam_role.s3_dynamodb_full_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"

}

resource "aws_iam_instance_profile" "s3_dynamodb_full_access_instance_profile" {
  name = "humangov-${var.state_name}-s3_dynamodb_full_access_instance_profile"
  role = aws_iam_role.s3_dynamodb_full_access_role.name

  tags = {
      Name = "humangov-${var.state_name}"
  }
}
*/

```

📄 `modules/aws_humangov_infrastructure/output.tf`

<aside>
💡

VS Code: select the lines and click "CTRL+;" to comment per line!

</aside>

```hcl
# output "state_ec2_public_dns" {
#    value = aws_instance.state_ec2.public_dns
# }

output "state_dynamodb_table" {
    value = aws_dynamodb_table.state_dynamodb.name
}

output "state_s3_bucket" {
    value = aws_s3_bucket.state_s3.bucket
}

```

📄 `terraform/output.tf`

```hcl
output "state_infrastructure_outputs" {
  value = {
    for state, infrastructure in module.aws_humangov_infrastructure :
    state => {
      # ec2_public_dns = infrastructure.state_ec2_public_dns
      dynamodb_table = infrastructure.state_dynamodb_table
      s3_bucket      = infrastructure.state_s3_bucket
    }
  }
}
```

Make sure that the `terraform/variables.tf` file has only one state listed

```hcl
variable "states" {
  description = "A lista de nomes de estados"
  default     = ["california"]
}

```

## Step 03 - Running Terraform

```bash
pwd # /home/ec2-user/human-gov-infrastructure/terraform

**terraform** plan      # 3 to add
**terraform** apply -auto-approve

```

Write down the names of your resources, we'll need them later:

```bash
US_STATE=california
AWS_REGION=us-east-1
AWS_DYNAMODB_TABLE=humangov-california-dynamodb
AWS_BUCKET=humangov-california-s3-a8tq

```

## Step 04 - Creating an ECS Cluster

Create a new ECS cluster called humangov-ecs-cluster using the UI Console with the following configuration:

- **ECS | Cluster | Create Cluster**
    - **Cluster name: `humangov-cluster`**
    - **Infrastructure: `Amazon EC2 instances`**
        - ***Create***
# **Part 03 - Creating Task Definitions & Services**

In this last phase, you will manually create the **Task Definition** in ECS, pointing to the ECR image, and deploy the application via an **ECS service**.

This involves

- Configuring the task's network type and resource allocation;
- Associating the container image published on the ECR;
- Launching the ECS service and checking that the application is working per tenant.

***This step demonstrates the manual deployment flow, highlighting the complexity and importance of automation in future projects.***

## Step 01 - **Creating 'Task Definition'**

- **Task definitions | Create new task definition**
    - **Task definition family: `humangov-fullstack`**
    - **Infrastructure requirements: `AWS Fargate`**
    - **Task size:**
        - CPU: **`1 vCPU`** | Memory: **`3 GB`**
    - **Task role: `HumanGovECSExecutionRole`**
    - **Task execution role: `HumanGovECSExecutionRole`**
    
    - **Container - 1:**
        - **Name: `app` (*Application Container*)**
        - **Image URI: `public.ecr.aws/xxxxxxxx/humangov-app`**  | **ECR: `humangov-app` repository**
        - **Essential container: `Yes`**
        - **Container port: `8000`**
        - **Port name: `app-8000-tcp`**
        
    - **Environment variables** (replace the values of the variables with your own values):
        - AWS_BUCKET = `YOUR-BUCKET-NAME`
        - AWS_DYNAMODB_TABLE = `humangov-california-dynamodb`
        - AWS_REGION = `us-east-1`
        - US_STATE = `california`
    
    **+ Add container**
    
    - **Container - 2:**
        - **Name**: **`nginx`***(WebServer container*)
        - **Image URI**: **`public.ecr.aws/xxxxxxxx/humangov-nginx`** | **ECR**: `humangov-nginx` repository
        - **Essential container: `No`**
        
        **Add by mapping**
        
        - **Container port: `80`**
        - **Port name: `nginx-80-tcp`**
        - **App protocol: `HTTP`**
        
        ***Create***
        

## Step 02 - **Creating 'Service'**

<aside>
💡

The service is responsible for deploying and exposing the service so that it can be accessed.

</aside>

- Or, once you are in a "Task Definition", click on "Deploy" | "Create service"
    
    
- **Service name: `humangov-svc`**
- **Existing cluster: `humangov-cluster`**
- **Compute options | Launch type: `FARGATE`**
- **Platform version: `LATEST`**
- **Service type: `Replica`**
- **Desired tasks: `2`**
- **Networking:**
    - **VPC: `Default`**
    - **Security Group: `Default`(make sure to allow traffic on Port 80)**
    
- **Load Balancing**
    - [ * ] **Use load balancing**
        - Application Load Balancer
    - **Load balancer name: `humangov-lb`**
        - Select the container that will receive the requests (Frontend | Proxy Webserver Nginx)
        
        <img width="371" height="109" alt="Screenshot 2026-01-01 at 7 16 31 PM" src="https://github.com/user-attachments/assets/54342876-9524-4228-8042-85792fc5f8bf" />

        
    - **Target group name: `humangov-tg`**

***Create***

***This process will take a while to complete the deployment of the solution!***

## Step 03 - Validating the ECS component

- **Cluster**
    - A running Cluster.
- **Tasks**
    - Tasks created to provide High Availability (HA)!
        - EC2 | Load Balancing | Target Groups
        - EC2 | No instance running (Fargate)!
- **Infrastructure**
    - Container instances created in different availability zones
- **Service**
    - **Configuration and Networking**
        - **Network configuration**
            - `DNS Name` (use to access the application)

## Step 04 - Testing the application

![image.png](attachment:9873671d-d6de-4c70-b664-2e186f6b3994:image.png)

- **First Name: `Caron`**
- **Last Name: `Elizabeth`**
- **Employee Role: `Trainee`**
- **Annual Salary (USD): `45000`**
- Scanned ID (PDF): attach any test pdf

## Step 06 - Destroy all resources

- **ECS | Select** Cluster
    - Start by deleting the **Service**
        - Force delete | delete
    - Then **Task Definition**
        - Select | Actions >> `Deregister`
        - Filter status: `Inactive`
        - Select | Actions >> `Delete`
    - and finally **Delete Cluster**

- **Delete the ECR Repositories.**
- **Remove the PDF manually from the S3 bucket.**
- **Destroy AWS S3 and DynamoDB using Terraform**

```bash
cd /home/ec2-user/human-gov-infrastructure/terraform
**terraform** destroy -auto-approve
```

🔒 ***Close Remote Connection***

**⛔ Stop Your IDE/EC2 Instance!**
