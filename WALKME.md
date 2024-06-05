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
