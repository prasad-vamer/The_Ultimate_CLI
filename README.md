# The Ultimate CLI

Welcome to **The Ultimate CLI** repository! This project is designed to streamline and simplify your AWS management tasks using Docker and Docker Compose. Say goodbye to the hassle of installing and configuring CLI tools on your local machine. 

## Objectives and Benefits
1. Simplify Development Environment Setup:

    - Objective: Eliminate the need for developers to install and configure AWS CLI tools on their local machines.

    - Benefit: Reduces setup time and potential configuration issues, ensuring a consistent environment across all developers.

2. Enhance Portability and Consistency:

    - Objective: Use Docker to encapsulate the AWS CLI environment.

    - Benefit: Docker ensures that the same versions of tools and dependencies are used, regardless of the underlying OS or local environment, avoiding "it works on my machine" problems.

3. Streamline AWS Management:

    - Objective: Provide a ready-to-use CLI environment for managing AWS resources.
    
    - Benefit: Makes it easier and faster for developers to run AWS commands, manage resources, and automate tasks without worrying about the underlying setup.

## Features

### 1. Docker-Powered Environment
- **Docker & Docker Compose**: Manage the entire project using Docker and Docker Compose. No need to install the CLI on your machine. Everything runs in isolated containers, ensuring a consistent environment.

### 2. Effortless AWS Account Switching
- **AWS Account Management**: Switch between different AWS accounts seamlessly. Simply provide the access and secret tokens as environment variables, and manage multiple AWS accounts swiftly and efficiently.

### 3. Simplified ECS Cluster and Container Access
- **ECS Cluster Navigation**: Easily choose and access the desired ECS cluster without manually retrieving cluster IDs or ARN IDs. Our script automates the process, allowing you to focus on your tasks.
- **Container Access**: Directly access the containers within the selected ECS cluster with minimal effort.
- [🔗 Story here](./WALKME.md#simplified-ecs-cluster-and-container-access-feature-3)

### 4. Cost Optimization (New Feature)
- **EC2 Elastic IP Management**: As part of cost optimization, this feature focuses on managing Elastic IPs associated with EC2 instances to ensure efficient resource utilization and cost savings. Key functionalities include:
  - **Identifying Unallocated Elastic IPs**:
    - Fetches the list of AWS regions.
    - Checks for unallocated Elastic IPs in each region.
    - Displays them in a readable table format for easy review.
  - **Releasing Unallocated Elastic IPs**:
    - Allows users to release Elastic IPs based on their preferences:
      - Release all unallocated IPs across all regions.
      - Release all unallocated IPs within specific regions.
      - Release specific unallocated IPs in selected regions.
  - **Interactive and Flexible**:
    - Provides an interactive prompt to customize operations, ensuring that users have full control over which Elastic IPs to release.
  - **Cost Benefits**:
    - Helps reduce unnecessary AWS charges by identifying and releasing unused Elastic IPs tied to EC2 instances, contributing to better billing management and cost optimization.
### 5. Enhanced EC2 Instance Access (New Feature)

- **Interactive EC2 Instance Management**: This feature provides a seamless and interactive way for developers to connect to running EC2 instances in a specified AWS region using SSM (AWS Systems Manager) session manager. Key functionalities include:

  - **Region Selection**:
    - Automatically detects the default AWS region configured on the system.
    - Provides an option to either use the default region or select a region interactively from a list of all available AWS regions.
  
  - **Running EC2 Instances Retrieval**:
    - Fetches the list of running EC2 instances in the selected region.
    - Displays the instances along with their instance IDs, public IPs, and names in a readable format.

  - **Interactive Instance Selection**:
    - Allows users to interactively select an instance to connect to, using a user-friendly Node.js-based UI for selection.

  - **Secure Instance Access**:
    - Automatically establishes an SSM session with the selected EC2 instance without requiring direct SSH access, ensuring security and convenience.

#### Example Workflow:
1. **Default Region Detection**:
   - The script detects the configured default region and prompts the user:
     ```
     The current configured default region is: ap-northeast-1
     Do you want to use the default region? (y/yes||n/no): 
     ```

2. **Region Selection**:
   - If the user opts not to use the default region, the script retrieves all available AWS regions and provides an interactive menu for selection:
     ```
     Retrieving list of AWS regions...
     [Interactive menu displayed for region selection]
     ```

3. **Instance Selection**:
   - After fetching the running EC2 instances in the selected region, the script displays the list and prompts the user to select one:
     ```
     [
       {
         "Name": "web-server",
         "InstanceId": "i-0abcd1234efgh5678",
         "PublicIP": "203.0.113.25"
       },
       {
         "Name": "app-server",
         "InstanceId": "i-0abcd1234ijkl9012",
         "PublicIP": "203.0.113.26"
       }
     ]
     [Interactive menu displayed for instance selection]
     ```

4. **Session Establishment**:
   - Once an instance is selected, the script initiates an SSM session:
     ```
     Accessing EC2 instance: web-server (i-0abcd1234efgh5678)
     Starting session with SessionId: ...
     ```

#### Benefits:
- **Interactive Workflow**: Makes it easy for developers to connect to EC2 instances without memorizing instance IDs or regions.
- **Security First**: Uses AWS SSM for access, eliminating the need for open SSH ports or direct key-based logins.
- **Flexibility**: Provides options for region and instance selection, accommodating diverse workflows and setups.

This feature is ideal for simplifying EC2 instance management and access for developers, DevOps engineers, and cloud administrators.



## Upcoming Features

- **Billing Management**: Get fine-tuned information about your AWS billing to optimize costs without compromising resources.
- **Resource Optimization**: Additional tools and scripts to help you maximize resource utilization and reduce expenses.

## Getting Started

### Prerequisites
- Docker
- Docker Compose
### Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/prasad-vamer/The_Ultimate_CLI.git
    cd The_Ultimate_CLI
    ```
2. Chnage to the directory
    ```sh
    cd The_Ultimate_CLI
    ```
3. create the credentials files like this 

    ```sh
    ❯ tree 
    .
    ├── Dockerfile
    ├── README.md
    ├── WALKME.md
    ├── credentials
    │   ├── config
    │   └── credentials
    └── docker-compose.yml
    ```
4. Update the `credentials` directory with your AWS credentials and configuration files as below

- `config` file looks like this.

```sh
[default]
region = <Region>
output = json

[profile my-profile]
region = <Region>
output = yml
```

- `credentials` file looks like this.
```sh
[default]
# This is the default profile
aws_access_key_id = <AWS ACCESS KEY>
aws_secret_access_key = <AWS SECRET KEY>

[my-profile]
aws_access_key_id = <AWS ACCESS KEY>
aws_secret_access_key = <AWS SECRET KEY>
region = <Region>

[my-new-profile]
aws_access_key_id = <AWS ACCESS KEY>
aws_secret_access_key = <AWS SECRET KEY>
region = <Region>
```

#### [Add Alias for much easier CLI Account Switching !](./WALKME.md#adding-alias-to-the-aws-cli-commands)

5. Build the docker image
    ```sh
    docker compose build --no-cache
    ```

6. Run the docker image

- With default profile
    ```sh
    docker compose run --rm app
    ```
- With specific profile
    ```sh
    AWS_PROFILE=my-profile docker compose run --rm app
    ```
7. Now you are inside the container and you can run the aws commands like this.
    ```sh
    aws s3 ls
    ```
8. To exit from the container
    ```sh
    exit
    ```

## Development

### Useful Commands

- **List AWS Configuration**: To see the current AWS configuration, run:
    ```sh
    aws configure list
    ```

- **Change AWS Profile**: Set up AWS profile from inside the container
    ```sh
    export AWS_PROFILE=my-new-profile
    ```
- **Check the OS Release Information:**: To check the OS release information inside the container, run inside the container:
    ```sh
    cat /etc/os-release
    ```

## Project Walkthrough

For a detailed walkthrough of the steps involved in creating this project, please refer to the [WALKME.md](WALKME.md) file. 

This file provides an in-depth explanation of the path followed, the issues encountered along the way, and the solutions implemented to overcome those challenges.

The `WALKME.md` file serves as a comprehensive guide that documents the entire process of building this project from start to finish. It includes valuable insights, lessons learned, and troubleshooting tips that can be helpful for anyone looking to understand the project's development journey or seeking guidance on similar projects.

Whether you are a curious developer, a contributor, or someone interested in learning from the project's experiences, the `WALKME.md` file is an excellent resource to explore. It offers a behind-the-scenes look at the thought process, decision-making, and problem-solving approaches employed throughout the project's lifecycle.

Feel free to dive into the `WALKME.md` file to gain a deeper understanding of the project's creation and to learn from the challenges and successes encountered along the way.

---

Start using **The Ultimate CLI** today and make AWS management a breeze!
