
# Hands-on Project: Implementation - Part 1

![image.png](attachment:20d0d913-c38b-4f05-baab-dfccacfd922d:image.png)

This architecture will be implemented in 03 parts as follows:

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

![image.png](attachment:0e5eff10-878b-4823-bb5c-1cb621c1b72c:image.png)

![image.png](attachment:cf520b67-9be2-4a9b-b5f4-ef09f3b91fdd:image.png)

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

![image.png](attachment:0e5eff10-878b-4823-bb5c-1cb621c1b72c:image.png)

![image.png](attachment:cf520b67-9be2-4a9b-b5f4-ef09f3b91fdd:image.png)

- **Repository Name**: **`humangov-nginx`**
    
    **Create**
    

## Step 06 - Configuring the Repository, Creating an Image and Making a Push

- Select the repository and click on: **`View push commands`**
- Execute the commands shown.

**Validate the upload of the Nginx Webserver image in ECR!**
