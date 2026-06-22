// Testing system for posts
//
// It runs the test cases defined test-data.json in parallel branches

let stopOnErrorOnly = false; // enable to run all test cases without stopping on differences (only on errors). Can get overwritten with a command line key

const help=`
Usage: node run-tests.js [keys] <test-data...>

   test-data     One or more JSON files containing test cases and other testing options

Keys:

   --fit
                 replace expected files with actual ones
   --externalDiff[=index]
                 when actual and expected output files differ, immediately
                 run external diff tool defined in settings.json.
                 If index is given, use specific tool from the list,
                 otherwise use the first one.
   --color
                use console colors
   --parallel[=num]
                use num number of parallel branches for processing of
                test cases. Default is number of logical processors.
   --include=<[postPrefix][,inputPrefix]>
                include only test cases those post and/or input start
                with given prefixes
   --problemsOnly
                report only unsuccessful test cases
   --stopOnErrorOnly
                stops the script on errors only and does not run any diff tool
   --stopOnFailure
                stops the script as soon a failure / mismatch was detected
   --postEngine=<path>
                path to the post engine executable
   --postDir=<path>
                path to the post directory
   --dataDir=<path>
                path to the data directory.
                This directory should input files, machine files and
                expected output in sub-directories.
   --post=<path>
                path to a specific post. Mutually exclusive with
                postDir and include keys.
   --ignore=<files>
                JSON files containing ignore lists of posts. Test cases
                of these posts are marked as ignored.
   --coverage
                Run OpenCppCoverage to perform postprocessor coverage testing
   --initialUnit=<MM|IN>
                Run all test cases for the given unit before the other.
   --onlyChanged
                Only run tests for file that have been changed on the current branch.
   --dstBranch=<branch name>
                Destination (base) branch to compare commit ancestors with. Used only
                in conjuction with --onlyChanged.
`

const util = require('util');

const path = require('path');

const fs = require('fs');

const process = require('process');

const child_process = require('child_process');

const os = require('os');
const { defaultMaxListeners } = require('events');

const execFile = util.promisify(child_process.execFile);

const { execFileSync } = child_process;

const spawn = util.promisify(child_process.spawn);

const copyFile = util.promisify(fs.copyFile);

const readFile = util.promisify(fs.readFile);

const writeFile = util.promisify(fs.writeFile);

const mkdir = util.promisify(fs.mkdir);

if (
  process.argv.length == 2 ||
  process.argv.length == 3 && process.argv[2] == "--help"
)
{
  console.log(help);
  process.exit(1);
}

// extract command line keys (starting with '--')
const commandLineKeys = process.argv.filter(a => a.startsWith("--")).reduce(
  (acc, a) => {
    let kv = a.slice(2).split('=');
    let accNew = {...acc};
    let v = (kv.length == 1 ? true : kv[1].replace(/^"/, "").replace(/"$/, ""));
    accNew[kv[0]] = v;
    return accNew;
  },
  {}
);

// extract command line positional args
const commandLinePositionalArgs = process.argv.slice(2).
  filter(a => !a.startsWith("--") && !a.endsWith(".js"));

// Get test data
if (commandLinePositionalArgs.length == 0) {
  console.error("No data file");
  process.exit(1);
}

let settingsFile = path.resolve(__dirname, "./settings.json");

// read settings file from command line
if (commandLineKeys.settings) {
  settingsFile = commandLineKeys.settings;
}

stopOnErrorOnly = commandLineKeys.stopOnErrorOnly !== undefined ? commandLineKeys.stopOnErrorOnly : stopOnErrorOnly;

const settings = JSON.parse(fs.readFileSync(settingsFile));

const { externalDiffTools } = settings;

// find post engine executable
let postEngine = path.resolve("post.exe");

if (commandLineKeys.postEngine) {
  postEngine = path.resolve(commandLineKeys.postEngine);
}

let testType = "regression tests";
if (commandLineKeys.coverage) {
  testType = "regression coverage tests";
}

console.log(`Running post-processor ${testType} ...`);
console.log(`Post Engine: ${postEngine}`);

// check if post engine exists
if (!fs.existsSync(postEngine)) {
  console.error("Post engine not found");
  process.exit(1);
}

// print post engine version
const versionLine = execFileSync(postEngine, ["--version"] ,{encoding : "utf8"});
console.log(versionLine);

// data directory (contains inputs, machines, expected files)
const dataDir = commandLineKeys.dataDir;

// post directory (contains *.cps)
let postDir = commandLineKeys.postDir;

let { include } = commandLineKeys;

let includePost;
let includeInput;

if (include) {
  [includePost, includeInput] = include.split(",");
}

// ignore list
// list of posts that are marked as ignored
let { ignore } = commandLineKeys;

function getIgnoredPostsFromFiles(files)
{
  let list = files.reduce((acc, c, idx) => {
    const o = JSON.parse(fs.readFileSync(c));
    if (o.ignore) {
      return [...acc, ...o.ignore];
    }
  },
  []);
  return list;
}

let ignoreList = ignore ? getIgnoredPostsFromFiles(ignore.split(";")) : [];

// Test Detector ignores. Use this list to specify paths to ignore. Overrides runAllTestsFiles.
let ignoreChanges = [
  "examples",
  "graphics",
  "overlays",
  "tests/expected",
  "tests/Parts"
 ];

// Test Detector core files. Use this list to specify paths that should cause all tests to run.
let runAllTestsFiles = [
  "Jenkinsfile",
  "jenkins",
  "tests",
  "machines"
]

// only posts with these capabilities are taken
const supportedCapabilities = [
  "CAPABILITY_MILLING",
  "CAPABILITY_TURNING",
  "CAPABILITY_JET",
  "CAPABILITY_ADDITIVE",
  "CAPABILITY_INSPECTION",
  "CAPABILITY_SETUP_SHEET"
];

function checkCapabilities(post)
{
  const re = /capabilities\s*=\s*(\w+)(?:\s*\|\s*(\w+))*/;

  const text = fs.readFileSync(post, "utf8");

  // if the text starts with "ENCRYPTED AUTODESK CAM POST", then it is an encrypted
  // post, in which case we can't check capabilities, but we should still run it.
  if (text.startsWith(`ENCRYPTED AUTODESK CAM POST`)) {
    return true;
  }

  // if it's a packaged post, we cannot read capabilities
  if (post.endsWith(".cpsz")) {
    return true;
  }

  const capabilityAssignments = text.match(re);
  if (!capabilityAssignments) {
    console.error("Error: Post file does not define its 'capabilities'");
    return false;
  }

  const matches = capabilityAssignments.slice(1).filter(m => m);

  // all capabilities are included in the list of supported ones
  const res = matches.some(m => supportedCapabilities.includes(m));

  return res;
}

// explicitly set post
if (commandLineKeys.post) {
  const { post } = commandLineKeys;

  // exit without error if it doesn't have supported capabilities
  if (!checkCapabilities(post)) {
    console.log("Post capabilities not supported");
    process.exit(0);
  }
  postDir = path.dirname(post);
  includePost = path.basename(post);

  const extLength = path.extname(post).length;

  if (extLength) {
    includePost = includePost.slice(0, -extLength);
  }
}

// Turn array of arrays into one-dimentional array
Array.prototype.flat = function(a)
{
  let res = [];

  for (const i of this) {
    if (Array.isArray(i)) {
      Array.prototype.push.apply(res, i.flat());
    } else {
      res.push(i);
    }
  }

  return res;
}

// Workaround. The old versions of node don't have the recursive
// option for mkdir
// In modern versions use: fs.mkdirSync(dir, {recursive: true});
function mkdirRecursiveSync(dir)
{
  // The postprocessor dockerfile has a new version of node
  if (process.platform == "linux" || process.platform == "darwin") {
    fs.mkdirSync(dir, {recursive: true});
    return;
  }
  let paths = dir.split(path.sep);
  let fullPath = '';
  paths.forEach((p) => {
    if (fullPath === '') {
      fullPath = p;
    } else {
      fullPath = path.join(fullPath, p);
    }

    if (!fs.existsSync(fullPath)) {
      fs.mkdirSync(fullPath);
    }
  });
}

const fitExpectedOutput = !!commandLineKeys.fit;

let externalDiffTool;

if (commandLineKeys.externalDiff) {
  const index = +commandLineKeys.externalDiff - 1;
  if (index < externalDiffTools.length) {
    externalDiffTool = externalDiffTools[index];
  } else {
    console.error(`Error: external diff tool #${index+1} not defined`);
  }
} else {
  externalDiffTool = externalDiffTools.find(d => d.default);
  let diffTool = externalDiffTool.tool.replace(/"/g, "")
  if (!fs.existsSync(diffTool)) {
    console.log(`Warning: external diff tool ${externalDiffTool.tool} was not found on your system.`);
  }
}

// run external diff tool defined in settings.json
async function runExternalDiffTool(expected, actual)
{
  if (stopOnErrorOnly) { // don't run comparison tool if only stopping on failure
    return;
  }
  if (!externalDiffTool) {
    return;
  }

  let argsLine = externalDiffTool.args.
    replace("{expected}", `"${expected}"`).replace("{actual}", `"${actual}"`);

  let efPromise = spawn(externalDiffTool.tool, [argsLine], {shell : true, detached: true});

  if (!externalDiffTool.async) {
    await efPromise;
  }
}

// Create test job object
function createTestJob(testData, post, testCase, input)
{

  const useDefaultProperties = testCase.useDefaultProperties !== undefined ?
    testCase.useDefaultProperties : true;

  // consider default properties
  let properties = useDefaultProperties ? testData.defaultProperties : {};

  // take specific properties
  properties = testCase.properties ?
    {...properties, ...testCase.properties} : properties;

  // units[0] = in; units[1] = mm
  const units = ["IN", "MM"];
  const hasUnitDefined = properties.unit !== undefined;
  let testJobs = [];
  for (let i = 0; i < units.length; i++) {
    let suffix = testCase.suffix ? testCase.suffix : "";
    let propertiesWithUnits = Object.assign({}, properties);

    // change the suffix and unit in properties
    if (hasUnitDefined) {
      suffix += `_${units[properties.unit]}`;
    } else {
      suffix += `_${units[i]}`;
      propertiesWithUnits.unit = i;
    }

    testJobs.push({
      dataDir : post.dataDir ? post.dataDir : testData.dataDir,
      postDir : post.postDir,
      defaultFlags : testData.defaultFlags,
      additionalFlags : testCase.additionalFlags,
      input : input,
      post : post.name,
      properties : propertiesWithUnits,
      machine : testCase.machine,
      inputFolder : testCase.inputFolder ? testCase.inputFolder : "",
      outputFolder : testCase.outputFolder ? testCase.outputFolder : post.outputFolder ? post.outputFolder : "",
      ignored : testCase.ignored || post.ignored,
      suffix : suffix,
      command : testCase.command,
      password : testCase.password,
      checkError: testCase.checkError ? testCase.checkError : false,
      isPackagedPost: testCase.isPackagedPost ? testCase.isPackagedPost : false,
      checkLog: testCase.checkLog ? testCase.checkLog : false,
      checkLogExcludes: testCase.checkLogExcludes ? testCase.checkLogExcludes : false,
      checkSim: testCase.checkSim ? testCase.checkSim : false,
      checkSimErrors: testCase.checkSimErrors ? testCase.checkSimErrors : [],
      description : testCase.description,
      propertiesFile : testCase.propertiesFile
    });

    // Only run once if the unit was defined in the test case
    if (hasUnitDefined) {
      break;
    }
  }
  return testJobs;
}

function createTestJobs(testData, earlyExit = true) {
  if (testData.posts !== undefined) {
    return testData.posts.map(
      p => p.testCases.map(
        t => {
          // If there is no input the test case must test a non-postprocessing
          // function which has no input
          if (t.input === undefined) {
            return [createTestJob(testData, p, t, null)];
          }
          // Create test job per input
          return t.input.map(
            i => createTestJob(testData, p, t, i)
          );
        }
      )
    ).flat();

  // No jobs to do and need to exit early.
  } else if (earlyExit) {
    console.log("No posts to run regression tests. Terminating early.");
    process.exit(0);
  
  } else {
    console.log("No posts to run regression tests.");
    return;
  }
}

function compareTestJobs(jobA, jobB) {
  return jobA.post == jobB.post
  && jobA.input == jobB.input
  && jobA.suffix == jobB.suffix
  && jobA.description == jobB.description
}

// Extract the list of test jobs
function getTestJobs(testData, includePost, includeInput, ignoreList, changedFiles)
{
  let testJobs = createTestJobs(testData);

  if (includePost) {
    testJobs = testJobs.filter(c => new RegExp(`^${includePost}$`).test(c.post));
  }
  if (includeInput) {
    testJobs = testJobs.filter(c => new RegExp(`^${includeInput}$`).test(c.input));
  }
  if (changedFiles && !changedFiles.coreFileChanged && changedFiles.jobs) {
    testJobs = testJobs.filter(c => changedFiles.posts.includes(c.post)
    || changedFiles.data.includes(c.input)
    || changedFiles.jobs.some(changedJob => compareTestJobs(c, changedJob)));
  }

  if (ignoreList.length) {
    testJobs.forEach(j => {
      if (ignoreList.includes(j.post)) {
        j.ignored = true;
      }
    });
  }

  const platformSpecificIgnoreList = testData.ignored ? testData.ignored : [];
  platformSpecificIgnoreList.forEach(ignoreItem => {
    testJobs.forEach(job => {
      // Only ignore on the relevant platform
      if (!ignoreItem.platforms.includes(process.platform)) {
        return;
      }
      if (ignoreItem.post == job.post) {
        if (ignoreItem.input) {
          if ((ignoreItem.input === job.input) ||
              (Array.isArray(ignoreItem.input) && ignoreItem.input.includes(job.input))) {
            job.ignored = true;
          }
        } else {
          // otherwise ignore every test for this post
          job.ignored = true;
        }
      }
    });
  });


  if (testJobs.length == 0) {
    // ignored post does not have a test file
    if (includePost && ignoreList.length) {
      if (ignoreList.includes(includePost)) {
        reportResult({post:includePost, input:"", "suffix":"", description:""}, resultVariants.ignored);
        process.exit(0);
      }
    }
    console.log("Test cases are not defined");
    process.exit(1);
  }

  return testJobs;
}

let results = [];

let resultVariants = {
  success              : { name : "Success",                      color : "green", isSuccess: true },
  failure              : { name : "Failure",                      color : "red" },
  outputDiffers        : { name : "Output differs",               color : "red" },
  simFileMissing       : { name : "Sim stream missing",           color : "red" },
  simFileErrors        : { name : "Sim stream errors",            color : "red" },
  simOutputDiffers     : { name : "Sim stream differs",           color : "red" },
  logDiffers           : { name : "Log output differs",           color : "red" },
  simpleLogDiffers     : { name : "Simple log output differs",    color : "red" },
  unexpectedErrors     : { name : "Expected errors not found",    color : "red" },
  interrogationDiffers : { name : "Interrogation output differs", color : "red" },
  ignored              : { name : "Ignored",                      color : "yellow", isSuccess: true },
  missingInput         : { name : "Missing input",                color : "cyan" },
  missingPost          : { name : "Missing post",                 color : "cyan" },
  fitted               : { name : "Recreated",                    color : "magenta" },
  initialized          : { name : "Initialized",                  color : "magenta", isInitialized: true },
  simInitialized       : { name : "Initialized Sim",              color : "magenta", isInitialized: true },
  unsupported          : { name : "Unsupported",                  color : "yellow" },
}

const statusLength = 15;

function reportResult(job, result)
{
  results.push( {job, result} );

  const {post, input, suffix, description} = job;

  let detailsList;
  if (!input) {
    detailsList = [post, description]
  } else {
    detailsList = [post, input]
  }

  if (suffix) {
    detailsList.push(suffix)
  }

  const jobId = `[${detailsList.join(',')}]`;

  const resultStatus = result.name.toUpperCase();

  // don't report successful test case if problemsOnly is set
  if (commandLineKeys.problemsOnly && result === resultVariants.success) {
    return;
  }

  // immediate report to the console
  console.log(`${color(result.color)}${resultStatus.padEnd(statusLength)} : ${jobId}${color("reset")}`);


  // stop tests if mismatch was detected
  if (commandLineKeys.stopOnFailure && !isSuccessful()) {
    if (!stopOnErrorOnly || result.name.toUpperCase() == "FAILURE") {
      console.log("#### MISMATCH DETECTED, TESTS STOPPED ####")
      process.exit(1);
    }
    return;
  }
}

// use command line key
let useColors = !!commandLineKeys.color;

function color(key)
{
  if (!useColors || !key) {
    return "";
  }
  switch (key.toLowerCase()) {
    case "reset"      : return "\x1b[0m";
    case "bright"     : return "\x1b[1m";
    case "dim"        : return "\x1b[2m";
    case "underscore" : return "\x1b[4m";
    case "blink"      : return "\x1b[5m";
    case "reverse"    : return "\x1b[7m";
    case "hidden"     : return "\x1b[8m";
    case "black"   : return "\x1b[90m";
    case "red"     : return "\x1b[91m";
    case "green"   : return "\x1b[92m";
    case "yellow"  : return "\x1b[93m";
    case "blue"    : return "\x1b[94m";
    case "magenta" : return "\x1b[95m";
    case "cyan"    : return "\x1b[96m";
    case "white"   : return "\x1b[97m";
  }
  return "";
}

// Output summary information about test results
function reportSummary(dtStart, exitCode)
{
  console.log();
  const padding = 14;

  const iTotal = results.length;
  console.log(`${"Total results".padEnd(padding)} : ${iTotal}`);

  let success = (exitCode == 0);

  // enumerate all result variants
  for (const p in resultVariants) {
    const pr = resultVariants[p];
    const i = results.filter(r => r.result == pr).length;

    if (i > 0) {
      console.log(`${pr.name.padEnd(padding)} : ${i}`);
    }
  }

  console.log();

  let dtEnd = new Date();

  let sec = (dtEnd.valueOf() - dtStart.valueOf())/1000;
  let sDuration = `${Math.floor(sec / 60)}MIN ${Math.round(sec % 60)}SEC`;

  if (success) {
    console.log(`${color('green')}TESTS SUCCEED${color("reset")} , RUNTIME(${sDuration})`);
  } else {
    console.log(`${color('red')}TESTS FAIL${color("reset")} , RUNTIME(${sDuration})`);
  }
}

// test that the post exists and has the correct capabilities
async function checkPostFile(testJob, postFile)
{
  let postValid = true;
  if (!fs.existsSync(postFile)) {
    reportResult(testJob, resultVariants.missingPost);
    postValid = false;
  }
  if (!checkCapabilities(postFile)) {
    reportResult(testJob, resultVariants.unsupported);
    postValid = false;
  }

  return postValid;
}

// initialize/rewrite the expected output with the latest output
async function initializeExpectedFile(testJob, expectedOutputFile, actualOutputFile, initResult)
{
    let continueTest = true;

    // copy actual output to expected if it doesn't exist (new test cases)
    if (!fs.existsSync(expectedOutputFile)) {
      await copyFile(actualOutputFile, expectedOutputFile);

      // report as initialized
      reportResult(testJob, initResult ? initResult : resultVariants.initialized);
      continueTest = false;
    } else if (fitExpectedOutput) {
      // fit expected output to actual output
      await copyFile(actualOutputFile, expectedOutputFile);

      // report as fitted
      reportResult(testJob, resultVariants.fitted);
      continueTest = false;
    }

    return continueTest;
}

// Copies output file into folder specified by --copyFailed key
// dataDir is used as a base for calculating relative path to the file
async function copyDifferentFile(dataDir, outputFile)
{
  if (!commandLineKeys.copyFailed) {
    return;
  }

  artifactsFile = path.resolve(commandLineKeys.copyFailed, path.relative(dataDir, outputFile));
  artifactsLeafDir = path.dirname(artifactsFile);
  
  // Ensure artifacts directory exists
  if (!fs.existsSync(artifactsLeafDir)) {
    mkdirRecursiveSync(artifactsLeafDir);
  }

  await copyFile(outputFile, artifactsFile);
}

// check if output file contains each line in the expected file
// in the correct order
async function checkOutputContains(testJob, expectedOutputFile, actualOutputFile)
{
  if (!fs.existsSync(expectedOutputFile) || !fs.existsSync(actualOutputFile)) {
    // output file not found but it should exist, return failure
    reportResult(testJob, resultVariants.failure);
    return false;
  }

  let contains = await checkContains(actualOutputFile, expectedOutputFile);
  if (!contains) {
    await copyDifferentFile(testJob.dataDir, actualOutputFile);
  }

  return contains;
}

// compare output file with expected output file
async function compareOutput(
  testJob,
  expectedOutputFile,
  actualOutputFile,
  compareResult,
  compareSimInsteadOfOutput
)
{
  if (!fs.existsSync(expectedOutputFile) || !fs.existsSync(actualOutputFile)) {
    // output file not found but it should exist, return failure
    reportResult(testJob, resultVariants.failure);
    return false;
  }

  let similar = compareSimInsteadOfOutput ?
    await compareSimFiles(actualOutputFile, expectedOutputFile) :
    await compareFiles(actualOutputFile, expectedOutputFile);

  if (!similar) {
    await runExternalDiffTool(expectedOutputFile, actualOutputFile).catch(console.error);
    await copyDifferentFile(testJob.dataDir, actualOutputFile);
    reportResult(testJob, compareResult ? compareResult : resultVariants.outputDiffers);
  } else {
    reportResult(testJob, resultVariants.success);
  }
  return true;
}

// Check that output file doesn't contain any lines from the expected excludes file.
async function checkOutputExcludes(testJob, expectedExcludesFile, actualOutputFile)
{
  if (!fs.existsSync(expectedExcludesFile) || !fs.existsSync(actualOutputFile)) {
    // Files not found but they should exist, return failure.
    reportResult(testJob, resultVariants.failure);
    return false;
  }

  let excludes = await checkExcludes(actualOutputFile, expectedExcludesFile);
  if (!excludes) {
    await copyDifferentFile(testJob.dataDir, actualOutputFile);
  }

  return excludes;
}

/**
 * A function to read the errors from a SimStream and return them as an array.
 * @param {string} actualSimFile
 * @returns {Array<string>} An array of errors in the sim file, will return [] if there are none
 */
const simFileErrors = async (actualSimFile) => {
  const simFile = await readFile(actualSimFile, "utf8");
  // We want to find all of the error lines, then strip out the error number from them
  const errorLines = simFile.match(/Error: [0-9]* [0-9]*/g);
  const errors = [];
  if (errorLines) {
    for (const line of errorLines) {
      const error = line.match(/Error: [0-9]* ([0-9]*)/);
      errors.push(error[1]);
    }
  }

  return errors;
}

// run post executable with supplied args
async function runPostExecutable(testJob, postArgs, options, errorOutputFile="")
{
  if (commandLineKeys.coverage) {
    return runPostExecutableCoverageMode(testJob, postArgs, options, errorOutputFile);
  }
  let error;
  let success = true;
  let consoleOutput = "";
  try {
    const { stdout } = await execFile(`"${postEngine}"`, postArgs, options);
    consoleOutput = stdout;
  } catch(e) {
    error = e;
    if (testJob.checkError && errorOutputFile) {
      await writeFile(errorOutputFile, error.stderr);
    } else {
      console.log([postEngine, ...postArgs].join(" "));
      success = false;
    }
  }

  if (!error && testJob.checkError && errorOutputFile) {
    console.error("Error: Postprocessing was expected to fail, but didn't");
  }

  if (!success) {
    reportResult(testJob, resultVariants.failure);
    console.error(error.stderr);
  }
  return {success : success, consoleOutput : consoleOutput};
}

// run post executable using coverage testing tool
async function runPostExecutableCoverageMode(testJob, postArgs, options, errorOutputFile="")
{
  const coverageWorkspace = path.resolve(path.dirname(postEngine), "./../../");
  const { post, suffix, input } = testJob;

  let coverageArgs = [
    `--working_dir=${coverageWorkspace}`,
    "--continue_after_cpp_exception",
    "--sources=\\post\\",
    "--sources=\\compression\\",
    "--sources=\\machine\\machine\\PostMachineConfig\\",
    `--modules=${postEngine}`,
    `--export_type=binary:"${coverageWorkspace}\\coverageresults\\${post}_${input}${suffix}.cov"`,
    "--",
    `${postEngine}`
  ];
  coverageArgs = coverageArgs.concat(postArgs);

  let error;
  let success = true;
  let consoleOutput = "";
  try {
      const { stdout } = await execFile(`"C:\\Program Files\\OpenCppCoverage\\OpenCppCoverage.exe"`, coverageArgs, options);
      consoleOutput = stdout;
  } catch(e) {
    error = e;
    if (testJob.checkError && errorOutputFile) {
      await writeFile(errorOutputFile, error.stderr);
    } else {
      console.log([postEngine, ...postArgs].join(" "));
      success = false;
    }
  }

  if (!error && testJob.checkError && errorOutputFile) {
    console.error("Error: Postprocessing was expected to fail, but didn't");
  }

  if (!success) {
    reportResult(testJob, resultVariants.failure);
    console.error(error.stderr);
  }
  return {success : success, consoleOutput : consoleOutput};
}

// convert list of properties into string that can be passed to the post exe
function getPropertyFlags(properties)
{
  let propertyFlags = Object.keys(properties).reduce(
    (a, c, i) => {
      let p = properties[c];
      if (typeof(p) == 'string') {
        if (p.startsWith("'")) {
          p = p.slice(1);
        }
        if (p.endsWith("'")) {
          p = p.slice(0, p.length - 1);
        }
        p = `'${p}'`;
      }
      return a + ` --property ${c} "${p}"`
    },
    ""
  );

  return propertyFlags;
}

// Include folders argument to post engine, used for include feature / merge posts
function getIncludePath(postDir)
{
  // Make sure, that path is absolute
  let curDir = path.resolve(postDir);
  do {
    // Check, if "packages" directory exists in current directory
    packagesPath = path.join(curDir, "packages");
    if (fs.existsSync(packagesPath)) {
      return "--include " + packagesPath
    }
    // Go one level up
    var oldDir = curDir;
    curDir = path.dirname(curDir);
    // Until it is possible
  } while (curDir != oldDir);
}


// Run postprocessing test job
async function runPostprocessingTestJob(testJob, actualOutputDir, expectedOutputDir, postFile)
{
  const { dataDir, input, post, suffix, properties, propertiesFile } = testJob;
  const inputDir = path.resolve(dataDir, "./cnc/" + testJob.inputFolder);

  if (!fs.existsSync(inputDir)) {
    reportResult(testJob, resultVariants.missingInput);
    return;
  }

  const rootDir = path.resolve(dataDir, "../"); // root folder of post-library
  const outputFileName = `${post}_${input}${suffix}.output`;
  const cncFile =  path.resolve(inputDir, input + ".cnc");
  const machineFlag = testJob.machine ? `--machine "${path.resolve(rootDir, testJob.machine)}"` : "";
  const propertiesFilePath = path.resolve(dataDir, "./properties/" + testJob.inputFolder + "/" + propertiesFile);
  const propertiesFileFlag = propertiesFile ? `--properties ${propertiesFilePath}` : "";
  const propertyFlags = getPropertyFlags(properties);

  let actualOutputFile = path.resolve(actualOutputDir, outputFileName);
  let expectedOutputFile = path.resolve(expectedOutputDir, outputFileName);

  let actualLogFile = "";
  let expectedLogFile = "";
  let actualSimpleLogFile = "";
  let expectedSimpleLogFile = "";
  let logFlag = "";
  if (testJob.checkLog || testJob.checkLogExcludes) {
    const logFileName = `${post}_${input}${suffix}.testlog`;
    const simpleLogFileName = `${post}_${input}${suffix}.simpleLog`;
    actualLogFile = path.resolve(actualOutputDir, logFileName);
    expectedLogFile = path.resolve(expectedOutputDir, logFileName);
    actualSimpleLogFile = path.resolve(actualOutputDir, simpleLogFileName);
    expectedSimpleLogFile = path.resolve(expectedOutputDir, simpleLogFileName);
    logFlag = `--log "${actualLogFile}" --simpleLog "${actualSimpleLogFile}"`;
  }

  let actualSimFile = "";
  let expectedSimFile = "";
  let simFlag = "";
  if (testJob.checkSim) {
    const simFileName = `${post}_${input}${suffix}.sim`;
    actualSimFile = path.resolve(actualOutputDir, simFileName);
    expectedSimFile = path.resolve(expectedOutputDir, simFileName);
    simFlag = `--sim "${actualSimFile}"`;
  }

  // Configure the output path for the tests which are checking error messages.
  // Note that the expected file with the error messages we want to check
  // needs to be added manually.
  let errorFile;
  if (testJob.checkError) {
    errorOutputDir = path.join(actualOutputDir, "error_messages")
    if (!fs.existsSync(errorOutputDir)) {
      await mkdir(errorOutputDir, { recursive: true });
    }
    errorExpectedDir = path.join(expectedOutputDir, "error_messages")
    if (!fs.existsSync(errorExpectedDir)) {
      await mkdir(errorExpectedDir, { recursive: true });
    }
    actualOutputFile = path.join(errorOutputDir, outputFileName);
    expectedOutputFile = path.join(expectedOutputDir, "error_messages", outputFileName);
    errorFile = actualOutputFile;
  }
  // remove existing output
  if (fs.existsSync(actualOutputFile)) {
    fs.unlinkSync(actualOutputFile);
  }

  let includePath = getIncludePath(postDir);

  // list of arguments for post engine
  let postArgs = [
    testJob.defaultFlags,
    includePath,
    machineFlag,
    logFlag,
    simFlag,
    propertiesFileFlag,
    propertyFlags,
    testJob.additionalFlags,
    `"${postFile}"`,
    `"${cncFile}"`,
    `"${actualOutputFile}"`
  ];

  let options = {shell : true};
  let { success } = await runPostExecutable(testJob, postArgs, options, errorFile);
  if (!success) {
    return;
  }


  if (testJob.checkLog) {
    // Initialize expected log file, but continue regardless
    // so we can initialise other output files too.
    await initializeExpectedFile(testJob, expectedLogFile, actualLogFile);
    if (!await checkOutputContains(testJob, expectedLogFile, actualLogFile)) {
      reportResult(testJob, resultVariants.logDiffers);
      console.error([postEngine, ...postArgs].join(" "));
    }

    await initializeExpectedFile(testJob, expectedSimpleLogFile, actualSimpleLogFile);
    if (!await checkOutputContains(testJob, expectedSimpleLogFile, actualSimpleLogFile)) {
      reportResult(testJob, resultVariants.simpleLogDiffers);
      console.error([postEngine, ...postArgs].join(" "));
    }
  }

  if (testJob.checkLogExcludes) {
    // Initialize expected log file, but continue regardless
    // so we can initialise other output files too.
    let expectedLogFileExcludes = expectedLogFile + "Excludes";
    await initializeExpectedFile(testJob, expectedLogFileExcludes, actualLogFile);
    if (!await checkOutputExcludes(testJob, expectedLogFileExcludes, actualLogFile)) {
      reportResult(testJob, resultVariants.logDiffers);
      console.error([postEngine, ...postArgs].join(" "));
    }

    let expectedSimpleLogFileExcludes = expectedSimpleLogFile + "Excludes";
    await initializeExpectedFile(testJob, expectedSimpleLogFileExcludes, actualSimpleLogFile);
    if (!await checkOutputExcludes(testJob, expectedSimpleLogFileExcludes, actualSimpleLogFile)) {
      reportResult(testJob, resultVariants.simpleLogDiffers);
      console.error([postEngine, ...postArgs].join(" "));
    }
  }

  if (testJob.checkSim) {
    if (!fs.existsSync(actualSimFile)) {
      // Sim file not found but it should exist, return failure
      reportResult(testJob, resultVariants.simFileMissing);
      console.error([postEngine, ...postArgs].join(" "));
    } else {
      // Check the output sim file for errors
      const simErrors = await simFileErrors(actualSimFile);
      if (testJob.checkSimErrors.length > 0) {
        // If we have expected simulation errors, they should match the actual errors
        const errorsEqual = (actualErrors, expectedErrors) => {
          if (actualErrors.length !== expectedErrors.length) {
            return false;
          }
          const sortedActualErrors = actualErrors.sort();
          const sortedExpectedErrors = expectedErrors.sort();
          for (let i = 0; i < sortedActualErrors.length; ++i) {
            if (parseInt(sortedActualErrors[i]) !== parseInt(sortedExpectedErrors[i])) {
              return false;
            }
          }
          // If we get here, the arrays are equal
          return true;
        }
        if (!errorsEqual(simErrors, testJob.checkSimErrors)) {
          // The errors haven't matched up
          reportResult(testJob, resultVariants.simFileErrors);
        }
      } else {
        // We're not expecting errors here, if we have any it's a failing test
        if (simErrors.length > 0) {
          reportResult(testJob, resultVariants.simFileErrors);
          console.error([postEngine, ...postArgs].join(" "));
        } else {
          // Check sim file hasn't changed
          if (
            await initializeExpectedFile(
              testJob,
              expectedSimFile,
              actualSimFile,
              resultVariants.simInitialized
            )
          ){
            let compareSimInsteadOfOutput = true;
            if (
              !await compareOutput(
                testJob,
                expectedSimFile,
                actualSimFile,
                resultVariants.simOutputDiffers,
                compareSimInsteadOfOutput
              )
            ){
              console.error([postEngine, ...postArgs].join(" "));
            }
          }
        }
      }
    }
  }

  if (!await initializeExpectedFile(testJob, expectedOutputFile, actualOutputFile)) {
    return;
  }
  if (testJob.checkError) {
    if (!await checkOutputContains(testJob, expectedOutputFile, actualOutputFile)) {
      reportResult(testJob, resultVariants.unexpectedErrors);
      console.error([postEngine, ...postArgs].join(" "));
    } else {
      reportResult(testJob, resultVariants.success);
    }
  } else {
    if (!await compareOutput(testJob, expectedOutputFile, actualOutputFile, false)) {
      console.error([postEngine, ...postArgs].join(" "));
    }
  }
}

// Run encryption test job
async function runEncryptionTestJob(testJob, actualOutputDir, postFile)
{
  const { dataDir, post, } = testJob;
  const outputFileName = `${post}.protected.unprotected.cps`;
  const actualOutputFile = path.resolve(actualOutputDir, outputFileName);

  // remove existing output
  if (fs.existsSync(actualOutputFile)) {
    fs.unlinkSync(actualOutputFile);
  }

  // for encryption tests we encrypt and the decrypt the post
  // so the expected output is the input file
  const expectedOutputFile = postFile;

  // copy the input post to the data/output directory
  // because encryption outputs to the same directory as the input
  let postDestination = path.resolve(actualOutputDir, testJob.post + ".cps");
  await copyFile(postFile, postDestination);

  // list of arguments for post engine
  let postArgs = [
    testJob.defaultFlags,
    testJob.additionalFlags,
    `--${testJob.command} ${testJob.password}`,
    `"${postDestination}"`
  ];

  let options = {shell : true, cwd : path.resolve(dataDir, "./output/")};
  let encryptionReturn = await runPostExecutable(testJob, postArgs, options);
  if (!encryptionReturn.success) {
    return;
  }

  // We cannot compare encrypted posts because their contents will always be
  // different because encryption depends on current time, so decrypt the post
  // and compare it to the original
  const decryptPostArgs = [
    testJob.defaultFlags,
    "--decrypt "+testJob.password,
    `"${path.resolve(actualOutputDir + "/" + post + ".protected.cps")}"`
  ];
  let decryptionReturn = await runPostExecutable(testJob, decryptPostArgs, options);
  if (!decryptionReturn.success) {
    return;
  }
  if (!await compareOutput(testJob, expectedOutputFile, actualOutputFile, false)) {
    console.error([postEngine, ...postArgs].join(" "));
  }
}

// Run decryption test job
async function runDecryptionTestJob(testJob, actualOutputDir, expectedOutputDir, postFile)
{
  const { dataDir, post } = testJob;
  const outputFileName = `${post}.unprotected.cps`;
  const expectedOutputFile = path.resolve(expectedOutputDir, outputFileName);
  const actualOutputFile = path.resolve(actualOutputDir, outputFileName);
  // remove existing output
  if (fs.existsSync(actualOutputFile)) {
    fs.unlinkSync(actualOutputFile);
  }

  // copy the input post to the data/output directory
  // because decryption outputs to the same directory as the input
  let postDestination = path.resolve(actualOutputDir, testJob.post + ".cps");
  await copyFile(postFile, postDestination);

  // list of arguments for post engine
  let postArgs = [
    testJob.defaultFlags,
    testJob.additionalFlags,
    `--${testJob.command} ${testJob.password}`,
    `"${postDestination}"`
  ];

  let options = {shell : true, cwd : path.resolve(dataDir, "./output/")};
  let {success} = await runPostExecutable(testJob, postArgs, options);
  if (!success) {
    return;
  }
  if (!await initializeExpectedFile(testJob, expectedOutputFile, actualOutputFile)) {
    return;
  }
  if (!await compareOutput(testJob, expectedOutputFile, actualOutputFile, false)) {
    console.error([postEngine, ...postArgs].join(" "));
  }
}

// Run interrogate test job
async function runInterrogateTestJob(testJob, actualOutputDir, expectedOutputDir, postFile)
{
  const { post, suffix, properties } = testJob;
  const outputFileName = `${post}${suffix}.txt`;
  const expectedOutputFile = path.resolve(expectedOutputDir, outputFileName);
  const actualOutputFile = path.resolve(actualOutputDir, outputFileName);
  const propertyFlags = getPropertyFlags(properties);
  // remove existing output
  if (fs.existsSync(actualOutputFile)) {
    fs.unlinkSync(actualOutputFile);
  }

  // list of arguments for post engine
  let postArgs = [
    testJob.defaultFlags,
    testJob.additionalFlags,
    "--interrogate",
	propertyFlags,
    `"${postFile}"`
  ];

  let options = {shell : true};
  let {success, consoleOutput} = await runPostExecutable(testJob, postArgs, options);
  if (!success) {
    return;
  }

  let interrogatedJson = JSON.parse(consoleOutput);
  let interrogatedJsonString = JSON.stringify(interrogatedJson, null, 2);
  await writeFile(actualOutputFile, interrogatedJsonString);

  if (!await initializeExpectedFile(testJob, expectedOutputFile, actualOutputFile)) {
    return;
  }
  if (!await checkOutputContains(testJob, expectedOutputFile, actualOutputFile)) {
    reportResult(testJob, resultVariants.interrogationDiffers);
    console.error([postEngine, ...postArgs].join(" "));
  }
}

// Run single test job
async function runTestJob(testJob)
{
  try {
    const {postDir, dataDir, post, inputFolder, outputFolder, ignored, command, isPackagedPost} = testJob;

    if (ignored) {
      reportResult(testJob, resultVariants.ignored);
      return;
    }

    const postExtension = isPackagedPost ? ".cpsz" : ".cps";
    const outputDir = outputFolder !== "" ? outputFolder : inputFolder;
    const postFile = path.resolve(postDir, post + postExtension);
    const actualOutputDir = path.resolve(dataDir, "./output/" + outputDir + "/" + post);
    const expectedOutputDir = path.resolve(dataDir, "./expected/" + outputDir + "/" + post);

    // ensure output directory exists
    if (!fs.existsSync(actualOutputDir)) {
      mkdirRecursiveSync(actualOutputDir);
    }
    // ensure the expected directory exists
    if (!fs.existsSync(expectedOutputDir)) {
      mkdirRecursiveSync(expectedOutputDir);
    }
    // verify the post file
    if (!checkPostFile(testJob, postFile)) {
      return;
    }

    switch (command) {
      case "encrypt":
        await runEncryptionTestJob(testJob, actualOutputDir, postFile);
        break;
      case "decrypt":
        await runDecryptionTestJob(testJob, actualOutputDir, expectedOutputDir, postFile);
        break;
      case "interrogate":
        await runInterrogateTestJob(testJob, actualOutputDir, expectedOutputDir, postFile);
        break;
      default:
        await runPostprocessingTestJob(testJob, actualOutputDir, expectedOutputDir, postFile);
        break;
    }
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

// Check that every line of fileB also appears in fileA with almost
// the same values and that the lines appear in the same order.
async function compareSimFiles(fileA, fileB)
{
  const files = await Promise.all([readFile(fileA, "utf8"), readFile(fileB, "utf8")])

  fileALines = files[0].match(/[^\r\n]+/g);
  fileBLines = files[1].match(/[^\r\n]+/g);

  // Fail the test if either file is missing or empty.  Strictly
  // speaking, an empty "expected" file should always pass the test.
  // However, it is easy to mistype the name of a file so an empty
  // "expected" file is probably a mistake.
  if (!fileALines || !fileBLines) {
    return false;
  }

  numLinesA = fileALines.length;
  numLinesB = fileBLines.length;

  // For each line in fileB, check that the rest of fileA contains a
  // line that almost matches.
  let i = -1;
  for (let j = 0; j < numLinesB; j++) {

    // Split the line from the "expected" file into "words".  We can't just
    // split on whitespace.  Simstream files contain double-quoted strings
    // which can contain spaces.  They can also contain escaped double
    // quotes and escaped backslashes.  We need to use this complicated
    // regular expression.
    //
    //    [^"\s]+      One or more characters that aren't a quote or whitespace.
    //                 This captures unquoted words, like numeric words or the
    //                 record identifier tags.
    //    |
    //    "            The opening quote of a double-quoted string.
    //    (?:          A non-capturing subgroup surrounding an alternation.
    //       [^\\"]+   One or more characters that are not a quote or backslash.
    //       |
    //       \\.       An escaped character, including escaped quotes and backslashes.
    //    )*
    //    "            The closing quote of a double-quoted string.
    let wordsB = fileBLines[j].match(/[^"\s]+|"(?:[^\\"]+|\\.)*"/g);

    // Read forward through the "output" file looking for a line that
    // almost "matches" the "expected" line.
    while (true) {
      ++i;
      if (i >= numLinesA) {
        // We have reached the end of the "output" file without
        // finding a match.
        return false;
      }

      // Split the line from the "output" file into "words".
      let wordsA = fileALines[i].match(/[^"\s]+|"(?:[^\\"]+|\\.)*"/g);

      // The lines must contain the same number of words.
      if (wordsB.length != wordsA.length) {
        continue;
      }

      // Loop through the words in the record.
      let isMatch = true;
      for (let k = 0; k < wordsB.length; ++k) {
        let ch = wordsB[k].charAt(0);
        if (ch >= '0' && ch <= '9' || ch == '-') {
          // This word is numeric.  Do a tolerance check.
          if (Math.abs(parseFloat(wordsB[k]) - parseFloat(wordsA[k])) > 1e-7) {
            isMatch = false;
            break;
          }
        } else {
          // This word is a string.  It must match exactly.
          if (wordsB[k] !== wordsA[k]) {
            isMatch = false;
            break;
          }
        }
      }

      if (isMatch) {
        break;
      }
    }
  }

  return true;
}

// Check if file A contains each line of file B, in the same order.
async function checkContains(fileA, fileB)
{
  const files = await Promise.all([readFile(fileA, "utf8"), readFile(fileB, "utf8")])

  fileALines = files[0].match(/[^\r\n]+/g);
  fileBLines = files[1].match(/[^\r\n]+/g);
  numLinesA = fileALines.length;
  numLinesB = fileBLines.length;

  let i = 0;
  // For each line in file B check that the rest of file A contains it.
  for (let j = 0; j < numLinesB; j++) {
    while (!fileALines[i].includes(fileBLines[j])) {
      i++;
      if (i >= numLinesA) {
        return false;
      }
    }
  }

  return true;
}

// Check that file A doesn't contains any of the lines of file B.
async function checkExcludes(fileA, fileB)
{
  const files = await Promise.all([readFile(fileA, "utf8"), readFile(fileB, "utf8")])

  fileALines = files[0].match(/[^\r\n]+/g);

  // If the file is empty, it must exclude any lines from file B.
  numLinesA = fileALines ? fileALines.length : 0;
  if (numLinesA == 0) {
    return true;
  }

  // For each line in file B check that file A doesn't contain it.
  fileBLines = files[1].match(/[^\r\n]+/g);
  numLinesB = fileBLines ? fileBLines.length : 0;
  for (let i = 0; i < numLinesB; i++) {
    if (fileALines.includes(fileBLines[i])) {
        return false;
    }
  }

  return true;
}

async function compareFiles(file1, file2)
{
  if (fs.statSync(file1).size != fs.statSync(file2).size) {
    return false;
  }

  const texts = await Promise.all([readFile(file1, "utf8"), readFile(file2, "utf8")])

  return texts[0] == texts[1];
}

// Run multiple jobs one by one
async function runMultipleJobs(jobs)
{
  for (const job of jobs) {
    await runTestJob(job);
  }
}

// Creates up to batchCount batches from the source array.
// Returns array of batches (arrays).
function createBatches(source, batchCount)
{
  let batches = [];

  const totalJobs = source.length;

  const jobsInBatch = Math.ceil(source.length / batchCount);

  for (let i = 0; i < batchCount && i*jobsInBatch < totalJobs ; i++) {
    batches.push(source.slice(i*jobsInBatch, (i+1)*jobsInBatch));
  }

  return batches;
}

// Runs job batches in parallel branches
async function runBatches(jobs, count)
{
  await Promise.all(
    createBatches(jobs, count).map(batch => runMultipleJobs(batch))
  );
}

// check --parallel=? (number of parallel branches)
// Tests cases are run in parallel branches in order to speed up the testing
// If a number if not specified, we will use one batch for each logical processor.
let batchCount = commandLineKeys.parallel ? Number(commandLineKeys.parallel) : os.cpus().length;

function getDataFilesFromDir(dir)
{
  let res = [];
  fs.readdirSync(dir).forEach(de => {
    const fullName = path.join(dir, de);

    // call recursively for directories
    if (fs.lstatSync(fullName).isDirectory()) {
      res = res.concat(getDataFilesFromDir(fullName));
    }
    if (path.extname(fullName) == ".json") {
      res.push(fullName);
    }
  })
  return res;
}

async function loadTestDataFromFiles(postDirectory, dataDirectory, dataFiles)
{
  let testData = dataFiles.map(
    f => {
      const dataDir = dataDirectory ? dataDirectory :
        path.resolve(path.dirname(path.dirname(f)));

      const postDir = postDirectory ? postDirectory :
        path.resolve(path.dirname(f), "../..");
      try {
        return {postDir, dataDir, ...JSON.parse(fs.readFileSync(f)) };
      } catch (err) {
        console.log("Failed to read the following file: " + f)
        throw err;
      }      
    }
  ).reduce(
    (acc, c, i) => {
      let postsPrev = acc.posts ? acc.posts : [];
      let postsNew = c.posts ?
        c.posts.map(p => ({...p, dataDir: c.dataDir, postDir: c.postDir})) : [];

      // merge list of posts
      let posts = [...postsPrev, ...postsNew];

      // merge objects and add merged list of posts
      return {...acc, ...c, posts};
    },
    {}
  );

  return testData;
}

async function getChangedFiles(dataFiles, ignoreChanges, runAllTestsFiles) {
  console.log("Gathering tests for changed files");
  // Force update remote refs to handle newly created jenkins clones
  console.log("Fetching remote origin");
  child_process.execSync("git fetch");
  // Make sure branches are up to date
  console.log("Fetching destination branch: " + commandLineKeys.dstBranch);
  child_process.execSync("git fetch origin " + commandLineKeys.dstBranch);

  // Get common ancestor commit for current branch and HEAD
  console.log("Fetching common origin from HEAD of origin/" + commandLineKeys.dstBranch);
  let mergeBase = child_process.execSync("git merge-base origin/" + commandLineKeys.dstBranch + " HEAD", { encoding: "utf8" });

  let changedFiles = {coreFileChanged:false, all:[], posts:[], data:[], jobs:[]};

  console.log("Git diffing from common origin");
  changedFiles.all = child_process.execSync("git diff --name-only " + mergeBase + " HEAD", {encoding : "utf8"})
    .split("\n")
    .filter(file => file.length > 0);
  console.log("Changed files: " + changedFiles.all);

  // Filter out ignored files
  let filteredFiles = changedFiles.all.filter(file => !ignoreChanges.some(f => file.startsWith(f)));

  if (filteredFiles.some(file => runAllTestsFiles.some(f => file.startsWith(f)))){
    console.log("Core file(s) changed. Running all test cases.");
    changedFiles.coreFileChanged = true;
  } else {
    console.log("Core files not changed. Running against changed files only.");
    changedFiles.posts = filteredFiles.filter(file => file.endsWith(".cps")).map(file => path.basename(file, ".cps"));
    console.log("Changed posts: " + changedFiles.posts);
    changedFiles.data = filteredFiles.filter(file => file.endsWith(".cnc")).map(file => path.basename(file, ".cnc"));
    console.log("Changed data files: " + changedFiles.data);

    let changedTestFiles = dataFiles.filter(file => changedFiles.all.some(f => path.normalize(f).endsWith(path.normalize(file))));
    console.log("Changed test files: " + changedTestFiles);

    changedFiles.jobs = createTestJobs(await loadTestDataFromFiles(postDir, dataDir, changedTestFiles), false);
    console.log("Test jobs for changed files: " + changedFiles.jobs);
  }

  return changedFiles
}

let dtStart = new Date();

function isSuccessful()
{
  return !results.some(
    r => !r.result.isSuccess
  );
}

async function runAll(dataFilePaths)
{
  const testDataFiles = getListOfDataFiles(dataFilePaths)

  const testData = await loadTestDataFromFiles(
    postDir,
    dataDir,
    testDataFiles
  );

  let testJobs;
  if (commandLineKeys.onlyChanged) {
    let changedFiles = await getChangedFiles(testDataFiles, ignoreChanges, runAllTestsFiles);
    console.log("Changed files: " + changedFiles.all);
    testJobs = getTestJobs(testData, includePost, includeInput, ignoreList, changedFiles); 
  } else {
    testJobs = getTestJobs(testData, includePost, includeInput, ignoreList);
  }

  if (commandLineKeys.initialUnit !== undefined) {
    const initialUnit = commandLineKeys.initialUnit === "MM" ? 1 : 0;
    const testJobsFirstUnit = testJobs.filter(job => initialUnit == job.properties.unit);
    const testJobsSecondUnit = testJobs.filter(job => initialUnit != job.properties.unit);

    await runBatches(
      testJobsFirstUnit,
      batchCount
    );
    // if new test files are initialized, run the test in both units and do not exit after the first unit
    if (!isSuccessful() && !results.some(r => r.result.isInitialized)) {
      process.exit(1);
    }
    await runBatches(
      testJobsSecondUnit,
      batchCount
    );
  } else {
    await runBatches(
      testJobs,
      batchCount
    );
  }
  if (!isSuccessful()) {
    process.exit(1);
  }
}

function getListOfDataFiles(dataFilePaths)
{
  // use map to replace + for spaces so that we can test files that include spaces in their name
  return dataFilePaths.map((element) => element.replace(/\+/g, " ")).reduce(
    (acc, c, i) => {
      if (fs.lstatSync(c).isDirectory()) {
        return [...acc, ...getDataFilesFromDir(c)];
      }

      return [...acc, c];
    },
    []
  );
}

// error handling. Force error code for exceptions
process.on("unhandledRejection", (reason, promise) => {
  console.error(reason.stack);
  process.exitCode = 1;
});

process.on("uncaughtException", (e) => {
  console.error(e.stack);
  process.exitCode = 1;
});

process.on("exit", (code) => {
  reportSummary(dtStart, code);
});

// run for all positional arguments. They mean test data paths.
runAll(commandLinePositionalArgs);
