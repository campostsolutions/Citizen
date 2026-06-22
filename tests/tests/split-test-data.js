const path = require('path');

const fs = require('fs');

const process = require('process');

const testData = JSON.parse(fs.readFileSync(process.argv[2]));

for (const post of testData.posts) {
  let d = {
    "type": "testCases",
    "version" : 1
  }
  fs.writeFileSync(
    "./test_cases/" + post.name + ".json",
    JSON.stringify({...d, posts : [post] }, null, 2)
  );
}