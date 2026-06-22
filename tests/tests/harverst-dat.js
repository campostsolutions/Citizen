
const fs = require('fs');

const process = require('process');

const path = require('path');

function getDatFiles(dir)
{
  let res = []; 
  fs.readdirSync(dir, {withFileTypes : true}).forEach(de => {
    const fullName = path.join(dir, de.name);
    if (de.isDirectory()) {
      res = res.concat(getDatFiles(fullName));
    }
    if (path.extname(fullName) == ".dat") {
      res.push(fullName);
    }
  })
  return res;
}

function readDirectory(dir)
{
  let res = {
    posts : []
  };

  const files = getDatFiles(dir);

  for (const f of files) {
    let oPost = parseDat(f);

    if (oPost == null) {
      console.error("FAILED: " + f);
    } else {
      console.log("SUCCEEDED: " + f);

      let existing = res.posts.find(p => p.name == oPost.name);

      if (existing == null) {
        res.posts.push(oPost);
      } else {
        existing.testCases = existing.testCases.concat(oPost.testCases);
      }
    }
  }
  
  return res;
}

function parseDat(name)
{
  try {
    const oPath = path.parse(name);

    const post = oPath.name;

    const capability = path.parse(oPath.dir).name;

    const content = fs.readFileSync(name, {encoding : "utf-8"});

    const reSection = /(REM,[^\r\n]+\r\n)?OPTIONS(.*)(\r\n[^\r\n]+)+/g;

    const matches = content.match(reSection);

    if (matches.length == 0) {
      throw new Error(`Dat-file cannot be parsed (${name})`);
    }

    return {
      name : post,
      testCases: matches.map(m => parseSection(capability, m))
    }
  } catch (e) {
    return null;
  }
}

function parseProperty(property)
{
  if (property == "true" || property == "false") {
    return property === "true";
  }
  if (property.includes(".")) {
    let f = Number.parseFloat(property);
    if (!Number.isNaN(f)) {
      return f;
    }
  } else {
    let i = Number.parseInt(property);
    if (!Number.isNaN(i)) {
      return i;
    }
  }
  
  // trim single quotes from string property
  if (property.startsWith("'") || property.endsWith("'")) {
    property = property.replace(/'/g, "");
  }

  return property;
}

function parseSection(capability, text)
{
  const reSection = /(?:REM,([^\r\n]+)\r\n)?OPTIONS(.*)((?:\r\n[^\r\n]+)*)\r\nCNC((?:\r\n[^\r\n]+)+)/;

  const match = text.match(reSection);

  if (match == null) {
    throw new Error("Section cannot be parsed");
  }

  let description = match[1];

  let properties = match[3].trim().split("\r\n").reduce(
    (acc, p) => { 
      if (!p) {
        return acc;
      }
      const a = p.split(",");
      let r = {...acc};
      r[a[0].trim()] = parseProperty(a[1].trim());
      return r;
    },
    {}
  );

  let { machine } = properties;

  delete properties.machine;

  let res = {
    description,
    capability,
    suffix : match[2].trim().slice(1),
    properties,
    input : match[4].trim().split("\r\n")
  }

  if (machine) {
    res.machine = machine;
  }

  return res;
}

let dataDir = process.argv[2];
if (!fs.existsSync(dataDir)) {
  console.error("Data directory not found");
  process.exit(1);
}

fs.writeFileSync(
  path.join(__dirname, "output.json"), 
  JSON.stringify(readDirectory(dataDir), null, 2)
);