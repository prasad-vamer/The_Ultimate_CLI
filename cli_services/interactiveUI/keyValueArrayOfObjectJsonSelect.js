// node keyValueArrayOfObjectJsonSelect.js -k Name -v InstanceId -f arrayOfObject.json -o object.json

import inquirer from "inquirer";
import fs from "fs";
import yargs from "yargs/yargs";
import { hideBin } from "yargs/helpers";
import path from "path";

const tmpDriectory = "/usr/src/app/cli_services/tmp/";

// Parse command-line arguments using yargs
const argv = yargs(hideBin(process.argv))
  .option("fileName", {
    alias: "f",
    type: "string",
    describe: "path of the file to read from",
    demandOption: true,
  })
  .option("ouputFile", {
    alias: "o",
    type: "string",
    describe: "path of the file to write to",
    demandOption: true,
  })
  .option("key", {
    alias: "k",
    type: "string",
    describe: "key for the option",
    demandOption: true,
  })
  .option("value", {
    alias: "v",
    type: "string",
    describe: "value for the option",
    demandOption: true,
  }).argv;

// Function to handle the prompt after argv is parsed
async function runPrompt() {
  // Get the key and value from the arguments passed
  const parsedArgs = await argv;
  const fileName = parsedArgs.fileName;
  const ouputFile = parsedArgs.ouputFile;
  const optionKey = parsedArgs.key;
  const optionValue = parsedArgs.value;

  // Read JSON file
  const data = JSON.parse(fs.readFileSync(tmpDriectory + fileName, "utf8"));

  if (!Array.isArray(data) || data.length === 0) {
    console.error("Invalid JSON format.");
    process.exit(1);
  }

  const choices = data.map((object, index) => {
    return {
      name: `${index + 1}) ${object[optionKey]} => ${object[optionValue]}`,
      value: object[optionValue],
    };
  });

  const questions = [
    {
      type: "list",
      name: "choice",
      message: "Select an instance:",
      choices: choices,
    },
  ];

  inquirer.prompt(questions).then((answers) => {
    const selectedChoice = data.find(
      (options) => options[optionValue] === answers.choice
    );

    // Create the directory if it doesn't exist
    const filePath = path.join(tmpDriectory, ouputFile);
    if (!fs.existsSync(tmpDriectory)) {
      fs.mkdirSync(tmpDriectory, { recursive: true });
    }

    fs.writeFileSync(filePath, JSON.stringify(selectedChoice, null, 2));
  });
}

// Run the prompt function
runPrompt();
