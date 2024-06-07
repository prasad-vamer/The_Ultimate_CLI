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