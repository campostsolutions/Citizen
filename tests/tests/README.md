# Testing System

## Introduction

The goal of this testing system is to ensure that the posts produce the same output with a given post-engine. In such a way it prevents regressions caused by either modification of the post or the post-engine.

## Mechanics

The testing system works as follows:

1. reads test cases from the `test_cases` directory;
2. runs test cases taking posts from the post library and input from the `cnc` directory;
3. puts the output files and logs into the `output` directory;
4. compares the actual output with the expected output from the `expected` directory.

Tests succeed if there are no post-processor failures and out files match their expected equivalents.

## Usage

This testing system is based on [Node.js](https://nodejs.org/en/) (>= 8.11). The core of the system is `run-tests.js`. It can be run independently. Run `node run-tests.js --help` to see all possible options. 

This script is also run on Jenkins with `jenkins/run_tests.bat`.

It can also be run manually through wrapping bat files. To run default tests run `run-all.bat`. 
To fit the expected output to the actual output for all test cases, run `recreate-expected-all.bat`. Note, you can pass a path to external post-engine as an argument to these bats. 

To run a single post use `run-single.bat` giving a post file name as an argument.
To fit the expected output to the actual output for a single post, run `recreate-expected-single.bat` giving a post file name as an argument.

To copy all actual output to the expected folder, run `copy-output-to-expected.bat`.

## Configuration

### Test case definition

Test cases are defined in JSON files. `run-tests.js` takes a list of paths and expands that list in a list of JSON files. If a path is a directory, it recursively takes all JSON files from there. The standard set of test cases for the post library is placed in `/tests/test_cases`. File names of test case definitions correspond to the posts. Develop a habit to add a new test case definition each time when you add a new post.

```
{
  "type": "testCases",                   // file type
  "version": 1,                          // schema version
  "posts": [
    {
      "name": "5axismaker",              // post file name (no extensions)
      "ignored": false,                  // if true the post is ignored (optional, default: false)
      "testCases": [
        {
          "description": "something",    // short description of the test case
          "capability": "milling",       // milling | turning | millturn | milljet | jet
          "suffix": "",                  // suffix of the output file
          "useDefaultProperties": true,  // use default properties, defined for all posts (optional, default: true)
          "properties": {},              // post-processor properties. All names are preserved, 
                                         //   see post-engine docs.
          "input": [ ... ],              // input file names (no extensions) for a given capability
          "ignored": false               // if true the test cases are ignored (optional, default: false)
        },
        ...
      ]
    }
    ...
  ]
}
```

### settings.json

This configuration file defines the following:

#### externalDiffTools

List of available configurations of external diff tools. Each entry is structured as follows:

Property| Description
-----|--------------------------
|tool| Path to the diff tool.
|args| Command line for the tool. The `{actual}` and `{expected}` placeholders are replaced with real paths before execution.
|async| Run asynchronously. Useful for some tools (meld) to prevent slipping on the diff tool invocation.
|default| Use this tool by default, if externalDiff command line key is not set.