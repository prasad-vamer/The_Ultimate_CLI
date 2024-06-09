import inquirer from "inquirer";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import fs from "fs";
import path from "path";

// Parse command-line arguments
const argv = yargs(hideBin(process.argv)).options({
  choices: {
    type: "array",
    demandOption: true,
    alias: "c",
    description: "Choices for the list",
  },
  question: {
    type: "string",
    demandOption: true,
    alias: "q",
    description: "Question to ask",
    default: "Select an option:",
  },
}).argv;

// Function to handle the prompt after argv is parsed
async function runPrompt() {
  const parsedArgs = await argv;
  const choices = parsedArgs.choices;
  const question = parsedArgs.question;

  const questions = [
    {
      type: "list",
      name: "awsService",
      message: question,
      choices: choices,
    },
  ];

  inquirer.prompt(questions).then((answers) => {
    // console.log(answers.awsService);
    const dir = "/usr/src/app/cli_services/tmp";
    const filePath = path.join(dir, "node_inquirer_select.txt");

    // Create the directory if it doesn't exist
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    // Write the selected value to the file
    fs.writeFileSync(filePath, answers.awsService);
  });
}

// Run the prompt function
runPrompt();
