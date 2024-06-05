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

### 2. Effortless AWS Account Switching (TBD)
- **AWS Account Management**: Switch between different AWS accounts seamlessly. Simply provide the access and secret tokens as environment variables, and manage multiple AWS accounts swiftly and efficiently.

### 3. Simplified ECS Cluster and Container Management (TBD)
- **ECS Cluster Navigation**: Easily choose and access the desired ECS cluster without manually retrieving cluster IDs or ARN IDs. Our script automates the process, allowing you to focus on your tasks.
- **Container Access**: Directly access the containers within the selected ECS cluster with minimal effort.

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
3. Build the docker image
    ```sh
    docker compose build --no-cache
    ```
4. Run the docker image
    ```sh
    docker compose run --rm app
    ```
## Development

### Useful Commands

- **List AWS Configuration**: To see the current AWS configuration, run:
    ```sh
    aws configure list
    ```