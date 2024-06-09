# WALKME through the developer's POV

This file provides an in-depth explanation of the path followed, the issues encountered along the way, and the solutions implemented to overcome those challenges.

## Little Story
When I was a beginner with the AWS CLI, I found it challenging to set up the environment and manage the configurations. Installing the CLI on my local machine, configuring the profiles, and managing the access keys was time-consuming and prone to errors. I struggled to get it right on my first try, and as someone with zero knowledge about AWS CLI, setting up the environment was particularly daunting. Managing different profiles added to the complexity, and I often had to manually perform repetitive tasks, such as entering AWS ECS containers for different clusters across various profiles.

At the same time, I realized there should be a more efficient way to manage AWS resource costs, akin to having a main switch at home to cut down power.

With all these challenges in mind, I wanted to create a solution that would simplify the setup process and enhance the AWS journey by addressing these issues one at a time. That's how this project began, and "The_Ultimate_CLI" was born.

## The Ultimate CLI
I Was checking on the AWS CLI in docker hub and Found this Image.
https://hub.docker.com/r/amazon/aws-cli


Cloned like this
```
docker pull amazon/aws-cli
```
And tried to enter in to the bash.

```
docker run --rm -it amazon/aws-cli sh
```

# Issue 1: [Not being able to enter the shell](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/1)

sh and bash and zsh are tried not working
```
usage: aws [options] <command> <subcommand> [<subcommand> ...] [parameters]
To see help text, you can run:

  aws help
  aws <command> help
  aws <command> <subcommand> help

aws: error: argument command: Invalid choice, valid choices are:
```
## [🔗 Story here](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/1)

## In nutshell
Changed the command like this
```
docker run --rm -it --entrypoint sh amazon/aws-cli
```

## Decided to proceed with a docker file
At this point decided to proceed with a docker file.
Will be easy to manage the commands and the environment variables, and easy to expand the services.

coded like this.
```dockerfile
# Use the amazon/aws-cli base image
FROM amazon/aws-cli

# Set the default entrypoint to sh
ENTRYPOINT ["sh"]
```

```yml
services:
  app:
    build: .
    tty: true
    stdin_open: true
```

Here’s what each part does:

- services: Defines the services that make up your application. In this case, there is one service named app.

- `app`: The name of the service. This is an arbitrary name that you choose to represent the service.

- `build: .`: Specifies that the Docker image for this service should be built from the Dockerfile located in the current directory (.).

- `tty: true`: Allocates a pseudo-TTY (teletypewriter) for the container. This is often needed for interactive processes. In other words, it enables terminal-like input and output.

- `stdin_open: true`: Keeps the standard input (stdin) open, even if not attached. This is useful for interactive processes or for keeping a shell session open. It allows you to interact with the container after it starts, for example, to type commands.


# Issue 2: [`Attaching to app-1` never chnages to anything](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/2)
```shell
[+] Running 2/0
 ✔ Network the_ultimate_cli_default  Created
 ✔ Container the_ultimate_cli-app-1  Created
Attaching to app-1

```

## [🔗 Story here](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/2)

## NOT SOLVED YET 😓

## Work arrround
instead of directly running `docker compose up` I decided to run `docker compose run --rm app` to see if it works.

Here the though is that the app service itself is now pointing to the sh via entry point command and it worked.


# Journey continues
Since the dockerization is done, next step is to make the AWS account switching effortless.

## Effortless AWS Account Switching (Feature 2)
`credentials` is created to the root of the project ans it is mounted to the container's `/root/.aws` directory. AWS CLI s expecing its credentials to be in that location. we will follow the same. 

AWS profile management is done by the environment variable `AWS_PROFILE`. We can pass that value via `docker compose run` command. Along with it lets fix a defalt value to be used in the compose file. 
the changed code will look like below:

```yml
services:
  app:
    build: .
    tty: true
    stdin_open: true
    volumes:
      - "./credentials:/root/.aws"
    environment:
      - AWS_PROFILE=${AWS_PROFILE:-default}
```

the container can be run like this now.
```shell
AWS_PROFILE=my-profile docker compose run --rm app
```

or AWS profile can directtly changed inside the container like this.
```shell
export AWS_PROFILE=my-new-profile
```

these are the files in the credentials folder.
```shell
❯ ls credentials                                           
config      credentials
```

config file looks like this.
```shell
[default]
region = <Region>
output = json

[profile my-profile]
region = <Region>
output = json
```

credentials file looks like this.
```shell
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

## Adding ALIAS to the AWS CLI commands
The next step is to add aliases to the AWS CLI Accessing commands to make them easier to remember and use. This will help users to quickly access the CLI Environment without having to remember the full command syntax.

```shell
AWS_PROFILE=myprofile docker compose run --rm app
AWS_PROFILE=myAdmin docker compose run --rm app
AWS_PROFILE=ABCProject docker compose run --rm app
```

too much to remember right? Let's make it easy.

1. Open your shell configuration file:

For Bash: ~/.bashrc or ~/.bash_profile
For Zsh: ~/.zshrc

2. Add the function:

```sh
function CLI() {
  AWS_PROFILE=$1 docker compose run --rm app
}
```

3. Save the file and reload the shell configuration:

For Bash: source ~/.bashrc
For Zsh: source ~/.zshrc

### Usage
- You can now use the function and pass the AWS_PROFILE value as an argument:

```shell
CLI myprofile
CLI myAdmin
CLI ABCProject
```

- if nothing is passed it will take the empty value and docker compose willl assign the default value.

```shell
CLI
```

## Changing the Docker file.
AWS CLI image as a standalone image it works well till now. BUt i am not able  to install the latest node version in it as the dependency issue arises between amazon linux and the node latest versions groff package. So decided to change the docker file to use the node image as the base image.
And the AWS CLI will be installed on top of it. (Taking insperation from my senior's code)

```dockerfile
# Use the latest node image as of 2024/06/07
FROM node:22.2.0

# Set the working directory in the container
WORKDIR /usr/src/app

# Install dependencies
RUN apt-get update && \
  apt-get install -y \
  python3 \
  python3-pip \
  groff-base

# Install the AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && unzip awscliv2.zip
RUN ./aws/install

CMD ["bash"]
```

No changes to the compose file or and steps.
And we have the node and npm installed.

# Journey continues 
## Simplified ECS Cluster and Container Access (Feature 3)
Here the idea is to run a sript is run it shoud assist me to select the cluster and the container to enter in to.

Doing this manually is a bit of a pain. Like in my previous projects there will be a big readme where my colleges wrote a hardcoded commands and steps to be followed to enter in to a container.
As a rails developer I often need to enter into the Rails deployed containers.
So decided to automate this process.

All feature is devided in to two Steps.
1. Installing typescript and other required packages for the Interactive CLI UI.
2. Writing the shell script to select the cluster and access the containers.

Main Folder is created as `cli_services` and two sub folders created as below.
```shell
cli_Services
├── interactiveUI
└── services
```

### 1: Installing typescript and other required packages for the Interactive CLI UI.
Ui handles features will be handled inside the `interactiveUI` folder.
Run the container and `cd` `interactiveUI` folder

1. Initialize a new Node.js project:
Run the following command to initialize a new Node.js project and create a package.json file:
  
```shell
npm init -y
```

this will create a package.json file like this.
```json
{
  "name": "interactiveui",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "description": ""
}
```

2. Install TypeScript as a development dependency:
Run the following command to install TypeScript as a development dependency in your project:
```shell
npm install --save-dev typescript
```

3. Create a TypeScript configuration file:
Run the following command to generate a tsconfig.json file in your project directory:
```shell
npx tsc --init
```

4. Create a TypeScript file:
Create a new file with a .ts extension, for example, index.ts. You can use any text editor or IDE of your choice to write your TypeScript code.
```ts
function greet(name: string): void {
  console.log(`Hello, ${name}!`);
}

greet("World");
```

5. I want to directly execute the TypeScript code without explicitly compiling it and generating a separate JavaScript file. 
I can use a tool called ts-node. ts-node is a package that allows you to run TypeScript files directly, without the need for a separate compilation step.
Here's how you can use ts-node to execute your TypeScript code:
- Install ts-node as a development dependency in your project:
```shell
npm install --save-dev ts-node
```
- Run the following command to execute your TypeScript code using ts-node:
```shell
npx ts-node index.ts
```

6. Successfully executed the TypeScript code using ts-node. The output should be:
```shell
root@c6e01e948d80:/usr/src/app/cli_services/interactiveUI# npm install --save-dev ts-node

added 19 packages, and audited 21 packages in 9s

found 0 vulnerabilities
root@c6e01e948d80:/usr/src/app/cli_services/interactiveUI# npx ts-node index.ts
Hello, World!
root@c6e01e948d80:/usr/src/app/cli_services/interactiveUI# 
```

## Issue 4: [Not able to create a typescript code running environment](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/4)

### [🔗 Story here](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/4)


### Step 2. Writing the shell script to select the cluster and access the containers.
1. First step is to make a folder and file structure as below.
`services` folder will cater the scripts for the every services The_Ultimate_CLI offers.

made the folder like this and added the first script to `access_container.sh` it.
```shell
.
└── cli_services
    ├── interactiveUI
    │   ├── package-lock.json
    │   ├── package.json
    │   └── select.js
    ├── services
    │   └── ECS_services
    │       └── access_container.sh
    └── tmp
```

2. Updated the docker file to copy the services folder to the container.
```dockerfile
# Copy the services directory to the container
COPY ./cli_services ./cli_services

# Make all .sh files in the services directory and its subdirectories executable
RUN find ./cli_services/services -type f -name "*.sh" -exec chmod +x {} \;
```

3. Running a simple script like this.
````shell
#!/bin/bash

aws ecs list-clusters
````

## Issue 3: [Unable to redirect output to pager]()
```shell
root@bd63adb90437:/usr/src/app# bash services/access_ECS_Containers.sh/access_container.sh

Unable to redirect output to pager. Received the following error when opening pager:
[Errno 2] No such file or directory: 'less'

Learn more about configuring the output pager by running "aws help config-vars".
```

### [🔗 Story here](https://github.com/prasad-vamer/The_Ultimate_CLI/issues/3)

### In nutshell
Decided to install the `less` package in the docker file.

```dockerfile
# Install CLI pager
RUN apt-get install less
```

4. We continue to work on the script as the next step.
 made a simple shell script that print the clusters and ask us to select the cluster to enter in to.
 but here the UI seems very simple and not user friendly. So decided to use the `Inquirer` package to make the UI more user friendly.

5. Final script is located [here](./cli_services/services/ECS_services/access_container.sh).